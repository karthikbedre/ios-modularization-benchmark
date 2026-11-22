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

## Graph metrics (RQ3)

`graph_metrics.py` reads each generated app's dependency graph from its Tuist manifest and reports targets, edges, Swift files, depth, width and the file-weighted critical path for each size and topology. It predicts the targets a change should recompile (the changed module plus all direct and transitive dependents) and compares that with the targets the build logs show, then correlates clean build time with each metric.

```
analysis/graph_metrics.py results/2026-11-macmini --out analysis/out/2026-11-macmini
```

Sizes above 16 are read from `build/scale/<N>`, which `civitas-gen --domains <N> --output build/scale/<N>` regenerates deterministically.

Findings from the 2026-11-macmini run: 91 of 126 change cells match the prediction exactly, and every mismatch is the prediction being one target too high. In the tree layout, Search depends on Identity only through other features and is not recompiled, because Swift rebuilds a module only when a module it imports directly changes its interface. In the interface layout, the app target is not recompiled after an interface change it does not use. Clean build time tracks targets, edges and files (r of 0.96 to 1.00), not depth or the critical path.

## Figures

`figures.py` draws the paper's figures from the tables `analyze.py --out` writes, each as a 300 dpi PNG with a CSV of exactly the values it plots. Unlike the scripts above it needs matplotlib.

```
analysis/analyze.py results/2026-11-macmini --out analysis/out/2026-11-macmini
analysis/figures.py analysis/out/2026-11-macmini results/2026-11-macmini/figures
```
