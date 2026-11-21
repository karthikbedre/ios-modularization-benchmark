"""Checks the stall recovery in run.py without running Xcode: a fake build stalls on demand.

    python3 bench/test_recovery.py
"""
from pathlib import Path
import importlib.util, sys, types, tempfile
from pathlib import Path
spec = importlib.util.spec_from_file_location("run", Path(__file__).with_name("run.py")); run = importlib.util.module_from_spec(spec)
sys.argv = ["run.py"]; spec.loader.exec_module(run)
tmp = Path(tempfile.mkdtemp())
derived = {"tree": tmp / "tree"}
derived["tree"].mkdir(); (derived["tree"] / "warm-file").write_text("x")
calls = {"n": 0}
plan = []
def fake_build(topology, dd, timeout, log, stall=None):
    calls["n"] += 1
    if plan and plan.pop(0) == "stall":
        raise run.BuildHung("stalled", 130)
    return 1.0, 0, ["A"], 1
run.build = fake_build
run.set_probe = lambda *a, **k: None
run.probe_file = lambda *a, **k: None
run.wait_for_ac = lambda: None
run.time.sleep = lambda s: None
class Rec:
    logs = tmp
    def record_hang(self, **row): pass
args = types.SimpleNamespace(build_timeout=10, cooldown=0)
# 1. one stall in a timed build: retried in place, derived data kept, state warm
plan[:] = ["stall", "ok", "ok"]
run.timed_build(args, Rec(), derived, "private-decl", "Identity", range(1, 11), 3, "tree", tmp / "l.log")
assert (derived["tree"] / "warm-file").exists(), "derived data was deleted"
assert run.build_state("private-decl", derived["tree"]) == "warm"
# 2. repeated stalls in an untimed build: last attempt is from cold, marker written, state flagged
plan[:] = ["stall", "stall", "ok"]
run.untimed_build(args, Rec(), derived, "tree", tmp / "u.log", "warmup", "private-decl", "Identity", 0)
assert not (derived["tree"] / "warm-file").exists()
assert run.build_state("private-decl", derived["tree"]) == "after-cold-restore"
assert run.build_state("clean", derived["tree"]) == "clean"
print("recovery tests passed")
