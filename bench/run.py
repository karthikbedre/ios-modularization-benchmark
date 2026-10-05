#!/usr/bin/env python3
"""Build-time benchmark harness for the Civitas topologies.

Runs each scenario for every topology, interleaving topologies run by run so drift
(thermal state, background work) spreads evenly across them. Appends one CSV row per
timed build and writes the environment next to the CSV.

Scenarios
  clean          delete derived data, then build
  noop           build again with nothing changed
  private-body   change the body of a private function in the hub's implementation
  public-impl    change a public declaration in the hub's implementation sources
  api-change     change a public declaration in the hub's API sources
  add-file       add a new source file to the hub's implementation, regenerate, then build

In tree the hub's API and implementation are one module, so public-impl and api-change
both change that module's interface. In api-impl only api-change touches the API module.

Change scenarios run once per hub. The default hubs are the two largest (Identity,
Notifications) and a leaf (ReportIssue, used only by Home), so results do not rest on
the best case for either topology.

Change scenarios edit the generated copy of a source file between probe markers, using a
new value for every run, so every timed build sees a real change. Probes and added files
are removed and the project rebuilt when a scenario finishes.

Usage
  bench/run.py --scenarios clean,noop --out results/static.csv
  bench/run.py --scenarios public-impl --hubs Notifications --runs 5 --out /tmp/try.csv
"""

import argparse
import csv
import datetime
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TOPOLOGIES = ["tree", "api-impl"]
SCENARIOS = ["clean", "noop", "private-body", "public-impl", "api-change", "add-file"]
CHANGE_SCENARIOS = {"private-body", "public-impl", "api-change", "add-file"}
DEFAULT_HUBS = "Identity,Notifications,ReportIssue"
# Short incremental builds vary more run to run (CV up to 11% in the pilot), so they get more runs.
DEFAULT_RUNS = {"clean": 10}
DEFAULT_INCREMENTAL_RUNS = 20
PROBE_BEGIN = "// bench-probe-begin"
PROBE_END = "// bench-probe-end"
# One line per compiled file. Batch lines ("Compiling\ A.swift, B.swift") are skipped so files are not counted twice.
COMPILE_LINE = re.compile(r"^SwiftCompile \S+ \S+ (/\S+\.swift) \(in target '([^']+)' from project")
FIELDS = ["timestamp", "topology", "linking", "scenario", "hub", "run", "seconds", "generate_seconds",
          "compiled_targets", "compiled_files", "targets", "exit_code"]


def project_dir(topology):
    return REPO / f"approach-{topology}"


def probe_file(topology, scenario, hub):
    """The generated file a change scenario edits."""
    root = project_dir(topology) / "Modules"
    if scenario == "api-change":
        module = hub if topology == "tree" else f"{hub}API"
        return root / module / "Sources" / "API" / f"{hub}Service.swift"
    return root / hub / "Sources" / "Impl" / "Domain" / f"Live{hub}Service.swift"


def added_file(topology, hub, run):
    return project_dir(topology) / "Modules" / hub / "Sources" / "Impl" / "Domain" / f"BenchAdded{run}.swift"


def probe_body(scenario, value):
    if scenario == "private-body":
        return f"private func benchProbe() -> Int {{ {value} }}"
    # A new public name every run changes the module's public interface.
    return f"public func benchProbe{value}() {{}}"


def set_probe(path, body):
    text = path.read_text()
    block = f"\n{PROBE_BEGIN}\n{body}\n{PROBE_END}\n" if body else ""
    pattern = re.compile(rf"\n{re.escape(PROBE_BEGIN)}\n.*?\n{re.escape(PROBE_END)}\n", re.S)
    text = pattern.sub("", text)
    path.write_text(text + block)


def generate(topology, linking):
    env = dict(os.environ, TUIST_LINKING=linking)
    started = time.monotonic()
    subprocess.run(["tuist", "generate", "--no-open"], cwd=project_dir(topology), env=env,
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return time.monotonic() - started


def build(topology, derived_data, log_path):
    command = [
        "xcodebuild", "-project", "Civitas.xcodeproj", "-scheme", "Civitas",
        "-configuration", "Debug", "-destination", "generic/platform=iOS Simulator",
        "-derivedDataPath", str(derived_data), "build",
        # Indexing runs alongside the build in Xcode and adds noise, so it is off for every run.
        "COMPILER_INDEX_STORE_ENABLE=NO",
    ]
    with open(log_path, "w") as log:
        started = time.monotonic()
        code = subprocess.run(command, cwd=project_dir(topology), stdout=log, stderr=subprocess.STDOUT).returncode
        seconds = time.monotonic() - started
    targets, files = set(), 0
    for line in Path(log_path).read_text(errors="replace").splitlines():
        match = COMPILE_LINE.match(line)
        if match:
            files += 1
            targets.add(match.group(2))
    return seconds, code, sorted(targets), files


def environment(linking):
    def run(*command):
        try:
            return subprocess.run(command, capture_output=True, text=True).stdout.strip()
        except FileNotFoundError:
            return ""
    swift = run("swift", "--version")
    return {
        "date": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "machine": run("sysctl", "-n", "hw.model"),
        "cpu": run("sysctl", "-n", "machdep.cpu.brand_string"),
        "cores": run("sysctl", "-n", "hw.ncpu"),
        "memory_bytes": run("sysctl", "-n", "hw.memsize"),
        "macos": platform.mac_ver()[0],
        "xcode": run("xcodebuild", "-version").replace("\n", " "),
        "swift": swift.splitlines()[0] if swift else "",
        "tuist": run("tuist", "version"),
        "commit": run("git", "-C", str(REPO), "rev-parse", "HEAD"),
        "dirty": bool(run("git", "-C", str(REPO), "status", "--porcelain", "--", "sources", "spec", "generator")),
        "linking": linking,
    }


class Recorder:
    def __init__(self, path, linking):
        path.parent.mkdir(parents=True, exist_ok=True)
        self.logs = path.parent / "logs"
        self.logs.mkdir(exist_ok=True)
        path.with_suffix(".env.json").write_text(json.dumps(environment(linking), indent=2) + "\n")
        new_file = not path.exists()
        self.file = open(path, "a", newline="")
        self.writer = csv.DictWriter(self.file, fieldnames=FIELDS)
        if new_file:
            self.writer.writeheader()

    def record(self, **row):
        row["timestamp"] = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")
        self.writer.writerow(row)
        self.file.flush()


def run_series(args, recorder, derived, scenario, hub, runs):
    topologies = args.topologies
    if scenario in CHANGE_SCENARIOS - {"add-file"}:
        for topology in topologies:
            set_probe(probe_file(topology, scenario, hub), probe_body(scenario, 0))
    if scenario != "clean":
        for topology in topologies:
            build(topology, derived[topology], recorder.logs / f"warmup-{topology}-{scenario}-{hub}.log")

    for run in runs:
        for topology in topologies:
            generate_seconds = 0.0
            if scenario == "clean":
                shutil.rmtree(derived[topology], ignore_errors=True)
            elif scenario == "add-file":
                added_file(topology, hub, run).write_text(f"struct BenchAdded{run} {{\n    var value = {run}\n}}\n")
                # Tuist globs sources when it generates, so a new file only exists for Xcode after this.
                generate_seconds = generate(topology, args.linking)
            elif scenario != "noop":
                set_probe(probe_file(topology, scenario, hub), probe_body(scenario, run))
            time.sleep(args.cooldown)
            log = recorder.logs / f"{scenario}-{hub}-{topology}-{args.linking}-{run}.log"
            seconds, code, targets, files = build(topology, derived[topology], log)
            recorder.record(topology=topology, linking=args.linking, scenario=scenario, hub=hub, run=run,
                            seconds=f"{seconds:.2f}", generate_seconds=f"{generate_seconds:.2f}",
                            compiled_targets=len(targets), compiled_files=files, targets=" ".join(targets), exit_code=code)
            print(f"{scenario:12} {hub:13} {topology:8} run {run:2}: {seconds:7.2f}s  {len(targets):2} targets  {files:3} files"
                  + ("" if code == 0 else f"  FAILED ({code}), see {log}"), flush=True)

    if scenario in CHANGE_SCENARIOS:
        for topology in topologies:
            if scenario == "add-file":
                for run in runs:
                    added_file(topology, hub, run).unlink(missing_ok=True)
                generate(topology, args.linking)
            else:
                set_probe(probe_file(topology, scenario, hub), None)
            build(topology, derived[topology], recorder.logs / f"restore-{topology}-{scenario}-{hub}.log")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--scenarios", default=",".join(SCENARIOS))
    parser.add_argument("--topologies", default=",".join(TOPOLOGIES))
    parser.add_argument("--linking", choices=["static", "dynamic"], default="static")
    parser.add_argument("--hubs", default=DEFAULT_HUBS, help="domains whose files the change scenarios edit")
    parser.add_argument("--runs", type=int, help="runs per scenario. Defaults to 10 for clean and 20 otherwise")
    parser.add_argument("--first-run", type=int, default=1, help="run number to start from, to resume a series")
    parser.add_argument("--cooldown", type=float, default=5.0, help="seconds to wait between timed builds")
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--derived-data", type=Path, default=Path.home() / "Library/Developer/CivitasBench")
    args = parser.parse_args()

    scenarios = args.scenarios.split(",")
    args.topologies = args.topologies.split(",")
    hubs = args.hubs.split(",")
    unknown = [s for s in scenarios if s not in SCENARIOS] + [t for t in args.topologies if t not in TOPOLOGIES]
    if unknown:
        sys.exit(f"unknown scenario or topology: {', '.join(unknown)}")

    recorder = Recorder(args.out, args.linking)
    derived = {t: args.derived_data / f"{t}-{args.linking}" for t in args.topologies}
    for topology in args.topologies:
        seconds = generate(topology, args.linking)
        print(f"generated {topology} ({args.linking}) in {seconds:.1f}s", flush=True)

    for scenario in scenarios:
        count = args.runs or DEFAULT_RUNS.get(scenario, DEFAULT_INCREMENTAL_RUNS)
        runs = range(args.first_run, args.first_run + count)
        for hub in (hubs if scenario in CHANGE_SCENARIOS else ["-"]):
            run_series(args, recorder, derived, scenario, hub, runs)


if __name__ == "__main__":
    main()
