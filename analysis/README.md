# Analysis

`analyze.py` turns a results folder into the tables behind the paper. It needs only Python 3.9 or later and no packages.

```
analysis/analyze.py results/2026-11-macmini > summary.md
analysis/analyze.py results/2026-11-macmini --out analysis/out/2026-11-macmini
```

What it reports:

- **api-impl against tree** for every linking, size, scenario and hub. Median times, the ratio of medians with a 95% bootstrap interval (2,000 resamples, fixed seed), Cliff's delta, a two-sided Mann-Whitney U p-value, and the median recompiled targets and files for each topology.
- **Blast radius.** For each size, the Pearson correlation between median build time and median recompiled targets, and between time and recompiled files, across the incremental change cells.
- **Scaling.** For each scenario, hub and topology, the exponent k in time ~ N^k from a least-squares fit on log median time against log N.

With `--out` it also writes `summary.csv` (per topology), `ratios.csv`, `blast_radius.csv` and `scaling.csv`. `analysis/out/` is not committed, since every table can be rebuilt from `results/`.

Rules it follows:

- Only CSVs at the top level of the results folder are read. Subfolders such as `excluded-*` hold data that is kept for transparency and left out of the analysis.
- On the machine that ran the matrix, only configurations with a `.done` marker are read, so a configuration still running is skipped. A fresh clone has no markers and reads every committed CSV.
- Rows with a nonzero exit code or a power source other than AC are dropped and counted in the report.
- The p-value uses the normal approximation with a tie correction. With 5 runs per topology it is conservative (perfect separation gives about 0.01, where the exact test gives 0.008).
