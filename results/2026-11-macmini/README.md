# Run 2026-11-macmini

Full benchmark matrix from `bench/run_matrix.sh`, started on 2026-11-16.

## Machine and toolchain

- Mac mini, Apple M6, 12 cores, 16 GB memory, macOS 27.0, on AC power for every timed build
- Xcode 27.2 (27B52), Apple Swift 6.4.2, Tuist 4.210.0

Each `<config>.env.json` records the machine, toolchain and the commit that was checked out when that configuration started. Static N=16 ran at 84d4f7d. Later configurations ran with the hang timeout from 8f12bd1. Commits after that on this branch only add results, so the harness and sources are the same.

## Files

- `<linking>-<N>-<scenario>.csv` has one row per timed build. Only finished configurations are committed.
- Raw xcodebuild logs are kept locally and are not in the repository.

## Notes

- Twice on 2026-11-16 an xcodebuild run stopped making progress at 0% CPU (SWBBuildService). The first time was static N=25 clean, before the timeout existed. That configuration was stopped by hand and rerun in full. The second time was static N=25 api-change, which the 30 minute timeout caught. Both configurations were rerun from cold derived data, and no partial data from a hung run is in the CSVs.
- An earlier run on different hardware and Xcode 26.3 is not part of this folder. Timings from the two runs are not pooled.
