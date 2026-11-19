# Run 2026-11-macmini

Full benchmark matrix from `bench/run_matrix.sh`, started on 2026-11-16.

## Machine and toolchain

- Mac mini, Apple M6, 12 cores, 16 GB memory, macOS 27.0, on AC power for every timed build
- Xcode 27.2 (27B52), Apple Swift 6.4.2, Tuist 4.210.0

Each `<config>.env.json` records the machine, toolchain and the commit that was checked out when that configuration started. Static N=16 ran at 84d4f7d. Static N=25 and the first five N=50 configurations ran with the 30 minute hang timeout from 8f12bd1. From static N=50 api-change on, the harness detects a stalled build and retries only that build (see Notes). The sources and generator are the same at every commit on this branch.

## Files

- `<linking>-<N>-<scenario>.csv` has one row per timed build. Only finished configurations are committed.
- `hangs.csv` lists every stalled build that was killed and retried. None of them appear in the timing CSVs.
- Raw xcodebuild logs are kept locally and are not in the repository.

## Notes

- Twice on 2026-11-16 an xcodebuild run stopped making progress at 0% CPU (SWBBuildService). The first time was static N=25 clean, before the timeout existed. That configuration was stopped by hand and rerun in full. The second time was static N=25 api-change, which the 30 minute timeout caught. Both configurations were rerun from cold derived data, and no partial data from a hung run is in the CSVs.
- An earlier run on different hardware and Xcode 26.3 is not part of this folder. Timings from the two runs are not pooled.
- From 12:45 PST on 2026-11-16 a build counts as stalled when its process tree uses under 0.5 s of CPU and its log does not grow for 120 s. The stalled build is killed, the topology's derived data is deleted, the probe is set back to the previous run's value and built without timing, and the same run is timed again. The retried build sees the same change from the same fully built state as an undisturbed run. In a test with a frozen build service, the retried build took 12.27 s against 13.18 s for the run before it, with the same targets and files. Before this, a third stall at static N=50 api-change was stopped by hand at 12:42 and that configuration was rerun in full.
