# Configurations timed after a cold restore (excluded)

Kept for transparency and left out of the analysis. Each folder holds a block of configurations in which, after an Xcode build stalled, the harness deleted the stalled topology's derived data and rebuilt it. Every later build in that block then ran from cold-rebuilt derived data and took up to about 2.8 times longer than from the state the block normally builds up. In static 200-feature api-change for Identity in the single-module layout, run 1 took 54 s, a stall hit run 2, and runs 2 to 10 took about 150 s, for the same 199 targets and 1494 files.

| Folder | What it is | Affected cells |
|---|---|---|
| `static-200-run1` | The static 200-feature block from the first matrix run | After a stall in private-decl Notifications run 9: those last two runs, private-decl ReportIssue and all of public-impl in the single-module layout. After a stall in api-change Identity run 2: the rest of api-change in that layout. |
| `static-200-run2` | A rerun of that block on 2026-11-18 with the old recovery | After a stall in api-change Identity run 1: all of api-change in the single-module layout. |
| `dynamic-100-run1` | The dynamic 100-feature block from the first matrix run | After a stall in the untimed restore of private-decl Identity: private-decl in the single-module layout (Notifications took 73.5 s, against 37.8 s for the same work in public-impl). |

Recovery now retries a stalled build without deleting derived data and flags any row timed after a cold restore (`state` column, see `COLD_MARKER` in `bench/run.py`). Both blocks were rerun from cold derived data at the start of the block, in their original order, as in the matrix. Their CSVs replace these at the top of the results folder.
