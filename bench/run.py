#!/usr/bin/env python3
"""Build-time benchmark harness for the Civitas topologies.

Runs each scenario for every topology, interleaving topologies run by run so drift
(thermal state, background work) spreads evenly across them. Appends one CSV row per
timed build and writes the environment next to the CSV.

Scenarios
  clean          delete derived data, then build
  noop           build again with nothing changed
  private-body   change the body of a private function in the hub's implementation
  private-decl   add a new top-level private declaration to the hub's implementation
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
import gzip
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
# Folder holding approach-<topology>. The repo for N=16, build/scale/<N> for generated sizes.
ROOT = REPO
TOPOLOGIES = ["tree", "api-impl"]
SCENARIOS = ["clean", "noop", "private-body", "private-decl", "public-impl", "api-change", "add-file"]
CHANGE_SCENARIOS = {"private-body", "private-decl", "public-impl", "api-change", "add-file"}
DEFAULT_HUBS = "Identity,Notifications,ReportIssue"
# Short incremental builds vary more run to run (CV up to 11% in the pilot), so they get more runs.
DEFAULT_RUNS = {"clean": 10}
DEFAULT_INCREMENTAL_RUNS = 20
PROBE_BEGIN = "// bench-probe-begin"
PROBE_END = "// bench-probe-end"
# One line per compiled file. Batch lines ("Compiling\ A.swift, B.swift") are skipped so files are not counted twice.
COMPILE_LINE = re.compile(r"^SwiftCompile \S+ \S+ (/\S+\.swift) \(in target '([^']+)' from project")
# Exit code for a build that hung, so run_matrix.sh can restart the configuration.
HUNG_EXIT = 3
# Seconds without CPU use or log output before a build counts as stalled. Set from --stall-seconds.
STALL_SECONDS = 120.0
# A stalled build is retried this many times before the configuration is given up and restarted.
BUILD_ATTEMPTS = 3
FIELDS = ["timestamp", "topology", "linking", "scenario", "hub", "run", "seconds", "generate_seconds",
          "compiled_targets", "compiled_files", "targets", "exit_code", "power"]


def project_dir(topology):
    return ROOT / f"approach-{topology}"


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
    if scenario == "private-decl":
        # Body edits leave dependents alone. A new top-level name may not (swiftlang/swift#92617).
        return f"private func benchProbe{value}() -> Int {{ {value} }}"
    # A new public name every run changes the module's public interface.
    return f"public func benchProbe{value}() {{}}"


def set_probe(path, body):
    text = path.read_text()
    block = f"\n{PROBE_BEGIN}\n{body}\n{PROBE_END}\n" if body else ""
    pattern = re.compile(rf"\n{re.escape(PROBE_BEGIN)}\n.*?\n{re.escape(PROBE_END)}\n", re.S)
    text = pattern.sub("", text)
    path.write_text(text + block)


def power_source():
    """'ac' or 'battery'. Desktops without a battery report AC."""
    output = subprocess.run(["pmset", "-g", "batt"], capture_output=True, text=True).stdout
    return "battery" if "Battery Power" in output else "ac"


def wait_for_ac():
    """Timing on battery is not comparable, so a timed build only starts on AC power."""
    if power_source() == "ac":
        return
    print("on battery power, waiting for the charger before the next timed build", flush=True)
    while power_source() != "ac":
        time.sleep(30)
    print("charger connected, resuming", flush=True)


def generate(topology, linking):
    env = dict(os.environ, TUIST_LINKING=linking)
    started = time.monotonic()
    subprocess.run(["tuist", "generate", "--no-open"], cwd=project_dir(topology), env=env,
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return time.monotonic() - started


class BuildHung(Exception):
    def __init__(self, message, seconds):
        super().__init__(message)
        self.seconds = seconds


def tree_cpu_seconds(root_pid):
    """CPU time used so far by a process and all its descendants (xcodebuild, SWBBuildService, compilers)."""
    output = subprocess.run(["ps", "-A", "-o", "pid=,ppid=,time="], capture_output=True, text=True).stdout
    children, cpu = {}, {}
    for line in output.splitlines():
        parts = line.split()
        if len(parts) != 3:
            continue
        pid, ppid = int(parts[0]), int(parts[1])
        children.setdefault(ppid, []).append(pid)
        seconds = 0.0
        for field in parts[2].replace("-", ":").split(":"):
            seconds = seconds * 60 + float(field)
        cpu[pid] = seconds
    total, stack = 0.0, [root_pid]
    while stack:
        pid = stack.pop()
        total += cpu.get(pid, 0.0)
        stack.extend(children.get(pid, []))
    return total


def build(topology, derived_data, timeout, log_path, stall=None):
    command = [
        "xcodebuild", "-project", "Civitas.xcodeproj", "-scheme", "Civitas",
        "-configuration", "Debug", "-destination", "generic/platform=iOS Simulator",
        "-derivedDataPath", str(derived_data), "build",
        # Indexing runs alongside the build in Xcode and adds noise, so it is off for every run.
        "COMPILER_INDEX_STORE_ENABLE=NO",
    ]
    hung = False
    with open(log_path, "w") as log:
        started = time.monotonic()
        process = subprocess.Popen(command, cwd=project_dir(topology), stdout=log, stderr=subprocess.STDOUT)
        # Xcode 27.2 builds sometimes stall at 0% CPU (SWBBuildService, 2026-11-16). A build counts as stalled
        # when its whole process tree used under 0.5 s of CPU and its log did not grow for `stall` seconds.
        # A slow but working build always does one or the other. `timeout` is a hard upper bound as well.
        stall = stall or STALL_SECONDS
        stalled = threading.Event()
        finished = threading.Event()

        def watchdog():
            # Runs beside a blocking wait(), so the measured time is as exact as without it.
            last_progress, last_cpu, last_size = started, 0.0, 0
            while not finished.wait(15):
                now = time.monotonic()
                cpu, size = tree_cpu_seconds(process.pid), os.path.getsize(log_path)
                if cpu - last_cpu >= 0.5 or size != last_size:
                    last_progress, last_cpu, last_size = now, cpu, size
                if now - last_progress >= stall or now - started >= timeout:
                    stalled.set()
                    process.kill()
                    return

        guard = threading.Thread(target=watchdog, daemon=True)
        guard.start()
        code = process.wait()
        seconds = time.monotonic() - started
        finished.set()
        guard.join()
        hung = stalled.is_set()
        if hung:
            subprocess.run(["pkill", "-9", "-f", "SWBBuildService"], check=False)
            time.sleep(2)
            code = -1
    targets, files = set(), 0
    text = Path(log_path).read_text(errors="replace")
    for line in text.splitlines():
        match = COMPILE_LINE.match(line)
        if match:
            files += 1
            targets.add(match.group(2))
    # Logs are kept for auditing but are large and repetitive, so they are stored compressed.
    with gzip.open(f"{log_path}.gz", "wt") as compressed:
        compressed.write(text)
    Path(log_path).unlink()
    if hung:
        raise BuildHung(f"build stalled after {seconds:.0f}s, see {log_path}.gz", seconds)
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
        "power_mode": next((line.split()[-1] for line in run("pmset", "-g").splitlines() if line.strip().startswith("powermode")), ""),
        "root": str(ROOT.relative_to(REPO)) if ROOT.is_relative_to(REPO) else str(ROOT),
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
        self.hangs = path.parent / "hangs.csv"
        self.config = path.stem

    def record_hang(self, **row):
        """Stalled builds are logged here and never appear in the timing CSV."""
        fields = ["timestamp", "config", "phase", "topology", "scenario", "hub", "run", "attempt", "seconds_before_kill"]
        new_file = not self.hangs.exists()
        with open(self.hangs, "a", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=fields)
            if new_file:
                writer.writeheader()
            row.update(timestamp=datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
                       config=self.config)
            writer.writerow(row)

    def record(self, **row):
        row["timestamp"] = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")
        self.writer.writerow(row)
        self.file.flush()


def untimed_build(args, recorder, derived, topology, log, phase, scenario, hub, run):
    """A build whose time is not recorded. After a stall it starts over from cold derived data."""
    for attempt in range(1, BUILD_ATTEMPTS + 1):
        try:
            return build(topology, derived[topology], args.build_timeout, log)
        except BuildHung as error:
            print(f"STALL: {phase} {scenario} {hub} {topology} run {run}, attempt {attempt}: {error}", flush=True)
            recorder.record_hang(phase=phase, topology=topology, scenario=scenario, hub=hub, run=run,
                                 attempt=attempt, seconds_before_kill=f"{error.seconds:.0f}")
            shutil.rmtree(derived[topology], ignore_errors=True)
    raise BuildHung(f"{phase} build stalled {BUILD_ATTEMPTS} times", 0)


def timed_build(args, recorder, derived, scenario, hub, runs, run, topology, log):
    """Times one build. If it stalls, rebuild the state the timed build starts from, then time it again.

    Recovery deletes the topology's derived data, puts the probe back to the previous run's value,
    builds without timing, and sets this run's value again. The retried build then sees the same
    change from the same fully built state as an undisturbed run.
    """
    for attempt in range(1, BUILD_ATTEMPTS + 1):
        try:
            return build(topology, derived[topology], args.build_timeout, log)
        except BuildHung as error:
            print(f"STALL: timed {scenario} {hub} {topology} run {run}, attempt {attempt}: {error}", flush=True)
            recorder.record_hang(phase="timed", topology=topology, scenario=scenario, hub=hub, run=run,
                                 attempt=attempt, seconds_before_kill=f"{error.seconds:.0f}")
            shutil.rmtree(derived[topology], ignore_errors=True)
            if scenario == "clean":
                continue
            if scenario == "add-file":
                raise
            if scenario != "noop":
                previous = run - 1 if run > runs.start else 0
                set_probe(probe_file(topology, scenario, hub), probe_body(scenario, previous))
            untimed_build(args, recorder, derived, topology, recorder.logs / f"recover-{topology}-{scenario}-{hub}-{run}.log",
                          "recovery", scenario, hub, run)
            if scenario != "noop":
                set_probe(probe_file(topology, scenario, hub), probe_body(scenario, run))
            wait_for_ac()
            time.sleep(args.cooldown)
    raise BuildHung(f"timed build stalled {BUILD_ATTEMPTS} times", 0)


def run_series(args, recorder, derived, scenario, hub, runs):
    topologies = args.topologies
    if scenario in CHANGE_SCENARIOS - {"add-file"}:
        for topology in topologies:
            set_probe(probe_file(topology, scenario, hub), probe_body(scenario, 0))
    if scenario != "clean":
        for topology in topologies:
            untimed_build(args, recorder, derived, topology, recorder.logs / f"warmup-{topology}-{scenario}-{hub}.log",
                          "warmup", scenario, hub, 0)

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
            wait_for_ac()
            time.sleep(args.cooldown)
            log = recorder.logs / f"{scenario}-{hub}-{topology}-{args.linking}-{run}.log"
            seconds, code, targets, files = timed_build(args, recorder, derived, scenario, hub, runs, run, topology, log)
            recorder.record(topology=topology, linking=args.linking, scenario=scenario, hub=hub, run=run,
                            seconds=f"{seconds:.2f}", generate_seconds=f"{generate_seconds:.2f}",
                            compiled_targets=len(targets), compiled_files=files, targets=" ".join(targets), exit_code=code,
                            power=power_source())
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
            untimed_build(args, recorder, derived, topology, recorder.logs / f"restore-{topology}-{scenario}-{hub}.log",
                          "restore", scenario, hub, 0)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--scenarios", default=",".join(SCENARIOS))
    parser.add_argument("--topologies", default=",".join(TOPOLOGIES))
    parser.add_argument("--linking", choices=["static", "dynamic"], default="static")
    parser.add_argument("--hubs", default=DEFAULT_HUBS, help="domains whose files the change scenarios edit")
    parser.add_argument("--runs", type=int, help="runs for every scenario, overriding the two options below")
    parser.add_argument("--clean-runs", type=int, default=DEFAULT_RUNS["clean"])
    parser.add_argument("--incremental-runs", type=int, default=DEFAULT_INCREMENTAL_RUNS)
    parser.add_argument("--first-run", type=int, default=1, help="run number to start from, to resume a series")
    parser.add_argument("--cooldown", type=float, default=5.0, help="seconds to wait between timed builds")
    parser.add_argument("--build-timeout", type=float, default=1800.0,
                        help="hard upper bound on one build in seconds")
    parser.add_argument("--stall-seconds", type=float, default=120.0,
                        help="seconds with no CPU use and no log output before a build counts as stalled and is retried")
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--derived-data", type=Path, default=Path.home() / "Library/Developer/CivitasBench")
    parser.add_argument("--root", type=Path, default=REPO, help="folder holding approach-<topology>, such as build/scale/100")
    args = parser.parse_args()
    global ROOT, STALL_SECONDS
    ROOT = args.root.resolve()
    STALL_SECONDS = args.stall_seconds

    scenarios = args.scenarios.split(",")
    args.topologies = args.topologies.split(",")
    hubs = args.hubs.split(",")
    unknown = [s for s in scenarios if s not in SCENARIOS] + [t for t in args.topologies if t not in TOPOLOGIES]
    if unknown:
        sys.exit(f"unknown scenario or topology: {', '.join(unknown)}")

    recorder = Recorder(args.out, args.linking)
    derived = {t: args.derived_data / ROOT.name / f"{t}-{args.linking}" for t in args.topologies}
    for topology in args.topologies:
        seconds = generate(topology, args.linking)
        print(f"generated {topology} ({args.linking}) in {seconds:.1f}s", flush=True)

    try:
        for scenario in scenarios:
            count = args.runs or (args.clean_runs if scenario == "clean" else args.incremental_runs)
            runs = range(args.first_run, args.first_run + count)
            for hub in (hubs if scenario in CHANGE_SCENARIOS else ["-"]):
                run_series(args, recorder, derived, scenario, hub, runs)
    except BuildHung as error:
        # Leave the generated sources as they were, so a restart begins from a clean project.
        for topology in args.topologies:
            for hub in hubs:
                for scenario in CHANGE_SCENARIOS - {"add-file"}:
                    path = probe_file(topology, scenario, hub)
                    if path.exists():
                        set_probe(path, None)
                for added in (project_dir(topology) / "Modules" / hub).glob("Sources/Impl/Domain/BenchAdded*.swift"):
                    added.unlink()
        print(f"HUNG: {error}", flush=True)
        sys.exit(HUNG_EXIT)


if __name__ == "__main__":
    main()
