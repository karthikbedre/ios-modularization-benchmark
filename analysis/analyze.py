#!/usr/bin/env python3
"""Summarize a benchmark run: medians, topology ratios, effect sizes, blast radius and scaling.

Reads the timing CSVs at the top level of a results folder (subfolders such as excluded-* are
ignored). If the folder has .done markers, as it does on the machine that ran the matrix, only
finished configurations are read. A fresh clone has no markers, so every committed CSV is read.
Rows with a nonzero exit code, timed on battery, or timed after a cold restore of derived data
(state "after-cold-restore", see COLD_MARKER in bench/run.py) are dropped and counted.

Usage
  analysis/analyze.py results/2026-11-macmini
  analysis/analyze.py results/2026-11-macmini --out analysis/out/2026-11-macmini

Prints a Markdown report. With --out it also writes summary.csv, ratios.csv, blast_radius.csv
and scaling.csv. Uses only the Python standard library, and the bootstrap is seeded, so the
output is the same on every run.
"""

import argparse
import csv
import math
import random
import re
import statistics as st
import sys
from collections import defaultdict
from pathlib import Path

TOPOLOGIES = ("tree", "api-impl")
SCENARIOS = ("clean", "noop", "private-body", "private-decl", "public-impl", "api-change", "add-file")
INCREMENTAL_CHANGES = ("private-body", "private-decl", "public-impl", "api-change", "add-file")
CONFIG = re.compile(r"^(static|dynamic)-(\d+)-([a-z-]+)$")
BOOTSTRAP = 2000
SEED = 20261116


def load(folder):
    """Returns {(linking, n, scenario, hub, topology): [row, ...]} and counts of dropped rows."""
    markers = {p.stem for p in folder.glob("*.done")}
    cells, dropped = defaultdict(list), {"failed": 0, "battery": 0, "cold_restore": 0, "unfinished_configs": 0}
    for path in sorted(folder.glob("*.csv")):
        match = CONFIG.match(path.stem)
        if not match:
            continue
        if markers and path.stem not in markers:
            dropped["unfinished_configs"] += 1
            continue
        linking, n = match.group(1), int(match.group(2))
        for row in csv.DictReader(open(path, newline="")):
            if row["exit_code"] != "0":
                dropped["failed"] += 1
                continue
            if row.get("power", "ac") != "ac":
                dropped["battery"] += 1
                continue
            if row.get("state") == "after-cold-restore":
                dropped["cold_restore"] += 1
                continue
            row["seconds"] = float(row["seconds"])
            row["compiled_targets"] = int(row["compiled_targets"])
            row["compiled_files"] = int(row["compiled_files"])
            cells[(linking, n, row["scenario"], row["hub"], row["topology"])].append(row)
    return cells, dropped


def bootstrap_ratio(a, b, rng):
    """95% percentile interval for median(a) / median(b)."""
    ratios = sorted(st.median(rng.choices(a, k=len(a))) / st.median(rng.choices(b, k=len(b))) for _ in range(BOOTSTRAP))
    return ratios[int(0.025 * BOOTSTRAP)], ratios[int(0.975 * BOOTSTRAP) - 1]


def bootstrap_median(a, rng):
    medians = sorted(st.median(rng.choices(a, k=len(a))) for _ in range(BOOTSTRAP))
    return medians[int(0.025 * BOOTSTRAP)], medians[int(0.975 * BOOTSTRAP) - 1]


def mann_whitney(a, b):
    """Two-sided Mann-Whitney U test with the normal approximation and tie correction. Returns (U, p)."""
    values = sorted([(v, 0) for v in a] + [(v, 1) for v in b])
    ranks, i, ties = [0.0] * len(values), 0, 0.0
    while i < len(values):
        j = i
        while j + 1 < len(values) and values[j + 1][0] == values[i][0]:
            j += 1
        for k in range(i, j + 1):
            ranks[k] = (i + j) / 2 + 1
        t = j - i + 1
        ties += t ** 3 - t
        i = j + 1
    n1, n2 = len(a), len(b)
    r1 = sum(r for r, (_, group) in zip(ranks, values) if group == 0)
    u = r1 - n1 * (n1 + 1) / 2
    n = n1 + n2
    variance = n1 * n2 / 12 * ((n + 1) - ties / (n * (n - 1)))
    if variance <= 0:
        return u, 1.0
    z = (abs(u - n1 * n2 / 2) - 0.5) / math.sqrt(variance)
    return u, math.erfc(max(z, 0) / math.sqrt(2))


def cliffs_delta(a, b):
    """P(a > b) - P(a < b). Negative means a tends to be smaller (here: api-impl faster)."""
    greater = sum(1 for x in a for y in b if x > y)
    less = sum(1 for x in a for y in b if x < y)
    return (greater - less) / (len(a) * len(b))


def pearson(x, y):
    if len(x) < 3:
        return float("nan")
    mx, my = st.mean(x), st.mean(y)
    sxy = sum((a - mx) * (b - my) for a, b in zip(x, y))
    sxx, syy = sum((a - mx) ** 2 for a in x), sum((b - my) ** 2 for b in y)
    return sxy / math.sqrt(sxx * syy) if sxx and syy else float("nan")


def log_log_slope(points):
    """Least-squares slope of log(time) on log(N): time grows roughly as N to this power."""
    xs, ys = [math.log(n) for n, _ in points], [math.log(t) for _, t in points]
    mx, my = st.mean(xs), st.mean(ys)
    sxx = sum((x - mx) ** 2 for x in xs)
    return sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / sxx if sxx else float("nan")


def scenario_order(key):
    linking, n, scenario, hub = key
    return (linking != "static", n, SCENARIOS.index(scenario) if scenario in SCENARIOS else 99, hub)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("results", type=Path, help="results folder, such as results/2026-11-macmini")
    parser.add_argument("--out", type=Path, help="folder for the CSV tables")
    args = parser.parse_args()

    cells, dropped = load(args.results)
    if not cells:
        sys.exit(f"no finished configurations in {args.results}")
    rng = random.Random(SEED)

    summary = []
    for key in sorted(cells, key=lambda k: (scenario_order(k[:4]), k[4])):
        rows = cells[key]
        seconds = [r["seconds"] for r in rows]
        lo, hi = bootstrap_median(seconds, rng)
        summary.append({
            "linking": key[0], "n": key[1], "scenario": key[2], "hub": key[3], "topology": key[4], "runs": len(rows),
            "median_s": round(st.median(seconds), 3), "ci_low": round(lo, 3), "ci_high": round(hi, 3),
            "mean_s": round(st.mean(seconds), 3),
            "cv_pct": round(100 * st.stdev(seconds) / st.mean(seconds), 2) if len(seconds) > 1 else 0.0,
            "targets": st.median(r["compiled_targets"] for r in rows),
            "files": st.median(r["compiled_files"] for r in rows),
        })

    ratios = []
    for key in sorted({k[:4] for k in cells}, key=scenario_order):
        tree, api = cells.get(key + ("tree",)), cells.get(key + ("api-impl",))
        if not tree or not api:
            continue
        t, a = [r["seconds"] for r in tree], [r["seconds"] for r in api]
        lo, hi = bootstrap_ratio(a, t, rng)
        u, p = mann_whitney(a, t)
        ratios.append({
            "linking": key[0], "n": key[1], "scenario": key[2], "hub": key[3],
            "tree_median_s": round(st.median(t), 3), "api_impl_median_s": round(st.median(a), 3),
            "ratio_api_over_tree": round(st.median(a) / st.median(t), 3), "ci_low": round(lo, 3), "ci_high": round(hi, 3),
            "mann_whitney_u": u, "p_value": p, "cliffs_delta": round(cliffs_delta(a, t), 3),
            "tree_targets": st.median(r["compiled_targets"] for r in tree),
            "api_impl_targets": st.median(r["compiled_targets"] for r in api),
            "tree_files": st.median(r["compiled_files"] for r in tree),
            "api_impl_files": st.median(r["compiled_files"] for r in api),
        })

    # Blast radius: across incremental change cells of one size, how well do recompiled targets
    # and files track build time? Each (scenario, hub, topology) cell contributes its medians.
    blast = []
    for linking, n in sorted({(k[0], k[1]) for k in cells}):
        points = [(st.median(r["compiled_targets"] for r in rows), st.median(r["compiled_files"] for r in rows),
                   st.median(r["seconds"] for r in rows))
                  for k, rows in cells.items() if k[0] == linking and k[1] == n and k[2] in INCREMENTAL_CHANGES]
        if points:
            targets, files, seconds = zip(*points)
            blast.append({"linking": linking, "n": n, "cells": len(points),
                          "r_time_targets": round(pearson(targets, seconds), 3),
                          "r_time_files": round(pearson(files, seconds), 3)})

    scaling = []
    for linking in sorted({k[0] for k in cells}):
        for scenario, hub in sorted({(k[2], k[3]) for k in cells if k[0] == linking}, key=lambda s: scenario_order((linking, 0) + s)):
            for topology in TOPOLOGIES:
                points = sorted((k[1], st.median(r["seconds"] for r in rows)) for k, rows in cells.items()
                                if k[0] == linking and k[2] == scenario and k[3] == hub and k[4] == topology)
                if len(points) >= 2:
                    scaling.append({"linking": linking, "scenario": scenario, "hub": hub, "topology": topology,
                                    "sizes": " ".join(str(n) for n, _ in points),
                                    "exponent": round(log_log_slope(points), 3)})

    if args.out:
        args.out.mkdir(parents=True, exist_ok=True)
        for name, table in (("summary", summary), ("ratios", ratios), ("blast_radius", blast), ("scaling", scaling)):
            with open(args.out / f"{name}.csv", "w", newline="") as handle:
                writer = csv.DictWriter(handle, fieldnames=list(table[0]))
                writer.writeheader()
                writer.writerows(table)

    print(f"# Benchmark summary: {args.results}\n")
    print(f"Configurations read: {len({k[:3] for k in cells})}. Timed builds: {sum(len(v) for v in cells.values())}. "
          f"Dropped: {dropped['failed']} failed, {dropped['battery']} on battery, "
          f"{dropped['cold_restore']} after a cold restore, "
          f"{dropped['unfinished_configs']} unfinished configurations.")
    hangs = args.results / "hangs.csv"
    if hangs.exists():
        print(f"Stalled builds killed and retried (hangs.csv): {sum(1 for _ in csv.DictReader(open(hangs)))}.")
    print("\n## api-impl against tree\n")
    print("Ratio is the api-impl median over the tree median, so below 1 means api-impl is faster. "
          "CI is a 95% bootstrap interval. Delta is Cliff's delta (negative: api-impl faster).\n")
    print("| linking | N | scenario | hub | tree s | api-impl s | ratio | 95% CI | delta | p | targets tree/api | files tree/api |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for r in ratios:
        print(f"| {r['linking']} | {r['n']} | {r['scenario']} | {r['hub']} | {r['tree_median_s']:.2f} | {r['api_impl_median_s']:.2f} "
              f"| {r['ratio_api_over_tree']:.2f} | {r['ci_low']:.2f} to {r['ci_high']:.2f} | {r['cliffs_delta']:+.2f} "
              f"| {r['p_value']:.1e} | {r['tree_targets']:.0f}/{r['api_impl_targets']:.0f} | {r['tree_files']:.0f}/{r['api_impl_files']:.0f} |")
    print("\n## Blast radius\n")
    print("Pearson correlation of median build time with median recompiled targets and files, over the incremental change cells of one size.\n")
    print("| linking | N | cells | r(time, targets) | r(time, files) |")
    print("|---|---|---|---|---|")
    for b in blast:
        print(f"| {b['linking']} | {b['n']} | {b['cells']} | {b['r_time_targets']:.2f} | {b['r_time_files']:.2f} |")
    print("\n## Scaling\n")
    print("Exponent k in time ~ N^k, a least-squares fit of log median time on log N.\n")
    print("| linking | scenario | hub | topology | sizes | k |")
    print("|---|---|---|---|---|---|")
    for s in scaling:
        print(f"| {s['linking']} | {s['scenario']} | {s['hub']} | {s['topology']} | {s['sizes']} | {s['exponent']:.2f} |")


if __name__ == "__main__":
    main()
