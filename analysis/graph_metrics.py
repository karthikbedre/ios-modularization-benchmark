#!/usr/bin/env python3
"""Graph metrics for each generated app, and how well they explain the measured build times (RQ3).

Reads the dependency graph from each generated Tuist manifest (approach-*/Project.swift), so the
metrics describe exactly the projects that were built. N=16 lives at the repository root and larger
sizes in build/scale/<N>, which civitas-gen regenerates deterministically:

  swift run --package-path generator civitas-gen --domains <N> --output build/scale/<N>

Usage
  analysis/graph_metrics.py results/2026-11-macmini
  analysis/graph_metrics.py results/2026-11-macmini --out analysis/out/2026-11-macmini

Reports, per size and topology: targets, dependency edges, Swift source files, depth (longest
dependency chain), width (most targets on one level), and the critical path weighted by source
files. For each hub it predicts the targets a change should recompile (the changed module plus
everything that depends on it, directly or transitively) and compares that with the targets the
build logs show were recompiled. Finally it correlates clean build time with each metric.
Standard library only.
"""

import argparse
import csv
import math
import re
import statistics as st
import sys
from collections import defaultdict
from functools import lru_cache
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TOPOLOGIES = ("tree", "api-impl")
HUBS = ("Identity", "Notifications", "ReportIssue")
APP = "Civitas"
MODULE = re.compile(r'targets \+= module\("([^"]+)", dependencies: \[([^\]]*)\]')
APP_DEPS = re.compile(r'name: "' + APP + r'",.*?dependencies: \[([^\]]*)\]', re.S)


def root_for(n):
    return REPO if n == 16 else REPO / "build" / "scale" / str(n)


def names(text):
    return re.findall(r'"([^"]+)"', text)


def load_graph(project_dir):
    """Returns {target: [dependencies]} for the app and every module, without test targets."""
    text = (project_dir / "Project.swift").read_text()
    deps = {APP: names(APP_DEPS.search(text).group(1))}
    for name, dep_list in MODULE.findall(text):
        deps[name] = names(dep_list)
    return deps


def source_files(project_dir, target):
    folder = project_dir / ("App/Sources" if target == APP else f"Modules/{target}/Sources")
    return sum(1 for _ in folder.rglob("*.swift")) if folder.is_dir() else 0


def metrics(deps, files):
    dependents = defaultdict(set)
    for target, ds in deps.items():
        for d in ds:
            dependents[d].add(target)

    @lru_cache(maxsize=None)
    def level(t):  # longest chain of dependencies below t, counted in targets
        return 1 + max((level(d) for d in deps.get(t, [])), default=0)

    @lru_cache(maxsize=None)
    def weighted(t):  # source files on the heaviest dependency chain ending at t
        return files[t] + max((weighted(d) for d in deps.get(t, [])), default=0)

    def affected(start):  # the changed target plus everything that depends on it
        seen, stack = {start}, [start]
        while stack:
            for parent in dependents[stack.pop()]:
                if parent not in seen:
                    seen.add(parent)
                    stack.append(parent)
        return seen

    per_level = defaultdict(int)
    for t in deps:
        per_level[level(t)] += 1
    return {
        "targets": len(deps),
        "edges": sum(len(v) for v in deps.values()),
        "files": sum(files.values()),
        "depth": level(APP),
        "width": max(per_level.values()),
        "critical_path_files": weighted(APP),
        "affected": affected,
    }


def changed_module(topology, scenario, hub):
    """The module a change scenario edits (see bench/run.py probe_file)."""
    if scenario == "api-change" and topology == "api-impl":
        return f"{hub}API"
    return hub


def pearson(x, y):
    if len(x) < 3:
        return float("nan")
    mx, my = st.mean(x), st.mean(y)
    sxy = sum((a - mx) * (b - my) for a, b in zip(x, y))
    sxx, syy = sum((a - mx) ** 2 for a in x), sum((b - my) ** 2 for b in y)
    return sxy / math.sqrt(sxx * syy) if sxx and syy else float("nan")


def measured(results):
    """Median seconds and recompiled targets per (linking, n, scenario, hub, topology) from finished CSVs."""
    markers = {p.stem for p in results.glob("*.done")}
    out = {}
    cells = defaultdict(list)
    for path in sorted(results.glob("*.csv")):
        m = re.match(r"^(static|dynamic)-(\d+)-([a-z-]+)$", path.stem)
        if not m or (markers and path.stem not in markers):
            continue
        for row in csv.DictReader(open(path, newline="")):
            if row["exit_code"] == "0" and row.get("power", "ac") == "ac":
                cells[(m.group(1), int(m.group(2)), row["scenario"], row["hub"], row["topology"])].append(row)
    for key, rows in cells.items():
        out[key] = (st.median(float(r["seconds"]) for r in rows), st.median(int(r["compiled_targets"]) for r in rows))
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("results", type=Path)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()

    data = measured(args.results)
    sizes = sorted({k[1] for k in data})
    graphs = {}
    for n in sizes:
        for topology in TOPOLOGIES:
            project = root_for(n) / f"approach-{topology}"
            if not (project / "Project.swift").exists():
                sys.exit(f"missing {project}/Project.swift, run civitas-gen --domains {n} --output build/scale/{n} first")
            deps = load_graph(project)
            files = {t: source_files(project, t) for t in deps}
            graphs[(n, topology)] = metrics(deps, files)

    rows = []
    for (n, topology), g in sorted(graphs.items()):
        rows.append({"n": n, "topology": topology, **{k: g[k] for k in ("targets", "edges", "files", "depth", "width", "critical_path_files")}})

    blast = []
    for (linking, n, scenario, hub, topology), (seconds, compiled) in sorted(data.items()):
        if scenario not in ("private-decl", "public-impl", "api-change"):
            continue
        predicted = len(graphs[(n, topology)]["affected"](changed_module(topology, scenario, hub)))
        blast.append({"linking": linking, "n": n, "scenario": scenario, "hub": hub, "topology": topology,
                      "predicted_targets": predicted, "measured_targets": compiled, "median_s": round(seconds, 2)})

    fits = []
    for linking in sorted({k[0] for k in data}):
        points = [(graphs[(n, t)], data[(linking, n, "clean", "-", t)][0]) for (l, n, s, h, t) in data
                  if l == linking and s == "clean" and (n, t) in graphs]
        if len(points) >= 3:
            seconds = [p[1] for p in points]
            fits.append({"linking": linking, "points": len(points),
                         **{f"r_{m}": round(pearson([p[0][m] for p in points], seconds), 3)
                            for m in ("targets", "edges", "files", "depth", "width", "critical_path_files")}})

    if args.out:
        args.out.mkdir(parents=True, exist_ok=True)
        for name, table in (("graph_metrics", rows), ("blast_radius_prediction", blast), ("clean_build_fits", fits)):
            if table:
                with open(args.out / f"{name}.csv", "w", newline="") as handle:
                    writer = csv.DictWriter(handle, fieldnames=list(table[0]))
                    writer.writeheader()
                    writer.writerows(table)

    print("# Graph metrics\n")
    print("| N | topology | targets | edges | files | depth | width | critical path files |")
    print("|---|---|---|---|---|---|---|---|")
    for r in rows:
        print(f"| {r['n']} | {r['topology']} | {r['targets']} | {r['edges']} | {r['files']} | {r['depth']} | {r['width']} | {r['critical_path_files']} |")
    exact = sum(1 for b in blast if b["predicted_targets"] == b["measured_targets"])
    print(f"\n## Predicted against measured recompiled targets\n\n{exact} of {len(blast)} change cells match exactly. "
          "Predicted = the changed module plus all its direct and transitive dependents, including the app.\n")
    print("| linking | N | scenario | hub | topology | predicted | measured | median s |")
    print("|---|---|---|---|---|---|---|---|")
    for b in blast:
        if b["predicted_targets"] != b["measured_targets"] or b["hub"] == "Notifications":
            print(f"| {b['linking']} | {b['n']} | {b['scenario']} | {b['hub']} | {b['topology']} | {b['predicted_targets']} | {b['measured_targets']} | {b['median_s']} |")
    print("\nRows shown: every mismatch, plus the Notifications hub for reference.\n")
    print("## Clean build time against graph metrics\n")
    print("Pearson correlation of median clean build time with each metric, across sizes and both topologies.\n")
    print("| linking | points | targets | edges | files | depth | width | critical path files |")
    print("|---|---|---|---|---|---|---|---|")
    for f in fits:
        print(f"| {f['linking']} | {f['points']} | {f['r_targets']:.2f} | {f['r_edges']:.2f} | {f['r_files']:.2f} | {f['r_depth']:.2f} | {f['r_width']:.2f} | {f['r_critical_path_files']:.2f} |")


if __name__ == "__main__":
    main()
