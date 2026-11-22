# ios-modularization-benchmark

A controlled benchmark of how module topology affects build time in a modular Swift app: does splitting every feature into an interface module and an implementation module make builds faster?

Large iOS apps are split into many modules so teams can build in parallel. A common piece of advice goes further and splits every feature into a small interface module, which other features import, and an implementation module that only the app sees. The promise is faster incremental builds. This repository measures that advice. The same app, Civitas (a city services app), is generated in two topologies from identical Swift sources, at five sizes, and every change type is timed many times on one machine.

> **Status.** The full matrix ran on an Apple silicon Mac mini in November 2026 ([run notes](results/2026-11-macmini/README.md)). Three blocks of configurations were rerun after a flaw in stall recovery was found and fixed (see [Threats to validity](#threats-to-validity)). The paper is in preparation in [`paper/`](paper/).

## Contents

- [Research questions](#research-questions)
- [Key findings](#key-findings)
- [Design](#design)
- [Reproducing the results](#reproducing-the-results)
- [Results and data](#results-and-data)
- [Repository layout](#repository-layout)
- [Threats to validity](#threats-to-validity)
- [Citing](#citing)
- [License](#license)

## Research questions

- **RQ1.** What does the interface layout cost on clean and no-op builds?
- **RQ2.** How does each layout respond to each kind of change (a private body edit, a new private declaration, a public implementation edit, an interface change), at each app size and for features at different depths of the graph?
- **RQ3.** How well do graph metrics (targets, edges, files, depth, critical path) predict which targets recompile and how long a build takes?

## Key findings

Measured on an Apple M6 Mac mini (16 GB, macOS 27.0, Xcode 27.2, Swift 6.4.2, Tuist 4.210.0): 42 configurations, 2,970 timed builds. A ratio is the interface layout's median build time over the single-module layout's, so below 1 means the interface layout is faster.

| Build | Linking | 100 features | 200 features |
|---|---|---|---|
| Clean | static | 1.29 | 1.30 |
| Clean | dynamic | 1.37 | not run |
| No-op | static | 1.39 | 1.46 |
| Private body edit, hub feature | static | 1.28 | 1.34 |
| New private declaration, hub feature | static | 0.20 | 0.19 |
| New private declaration, hub feature | dynamic | 0.19 | not run |

1. **The interface layout costs on every full or no-op build.** Clean builds are 16 to 30 percent slower with static linking as the app grows from 16 to 200 features, and 37 percent slower at 100 features with dynamic linking, because it doubles the number of targets.
2. **It wins only when a change reaches the module interface.** A new private declaration in a widely used feature rebuilds every dependent in the single-module layout but only two targets in the interface layout, which makes the build about 5 times faster at 100 and 200 features, with static and with dynamic linking alike.
3. **It loses on the most common edit.** A change inside a function body recompiles one target in either layout, and the interface layout is still 7 to 43 percent slower, because every build pays for its larger graph.
4. **How much a change fans out decides the size of the win.** For the leaf feature, a change recompiles three or four targets in the single-module layout at 16 to 50 features, and the interface layout gains at most about 13 percent. At 200 features the same change recompiles 23 targets, and a new private declaration builds about 1.4 times faster in the interface layout.
5. **Graph size explains build time, graph shape does not.** Clean build time follows targets, edges and files (r of 0.96 to 1.00), not depth or the critical path. The predicted set of recompiled targets matches the build logs exactly in 91 of 126 change cells, and every mismatch over-predicts by one target, because Swift rebuilds a module only when a module it imports directly changes its interface.

Every table, with bootstrap intervals, effect sizes and scaling exponents, comes from `analysis/analyze.py` and `analysis/graph_metrics.py`.

## Design

```
spec/domains.yaml            domains and their dependencies, the single source of truth
sources/                     canonical Swift sources, written against interface modules
generator/                   civitas-gen: spec + sources -> both Tuist projects, at any size
approach-tree/               generated project: each feature is one module
approach-api-impl/           generated project: each feature is <Feature>API plus <Feature>
bench/                       the timing harness and the matrix runner
analysis/                    statistics and graph metrics behind the paper
results/                     raw timings, one CSV per configuration
paper/                       paper sources
```

- **Topologies.** In the tree layout each feature is one module and imports the features it uses. In the interface layout each feature is split into `<Feature>API` and `<Feature>`, features import only interface modules, and interface modules import only core modules. The two differ only in target membership, `import` lines and module boundaries.
- **Sizes.** 16 hand-written features, and 25, 50, 100 and 200 features generated deterministically from the same templates.
- **Change types.** Clean, no-op, private body edit, new private declaration, public implementation edit and interface change, each applied to a hub feature (Identity, Notifications) and a leaf (ReportIssue).
- **Runs.** Static linking at every size, dynamic linking at 16 and 100. Ten clean and twenty incremental runs per cell up to 50 features, five and ten at 100 and 200, alternating the two layouts. Builds that stall with no CPU use are killed and retried in place, keeping derived data, and every stall is logged. Any row timed after derived data had to be rebuilt from cold is flagged and left out.

## Reproducing the results

Requirements: an Apple silicon Mac with Xcode 27.2, and Tuist 4.210.0 (pinned in `mise.toml`).

```bash
git clone https://github.com/karthikbedre/ios-modularization-benchmark
cd ios-modularization-benchmark
swift run --package-path generator civitas-gen          # regenerate both projects
mise exec -- caffeinate -i bench/run_matrix.sh results/my-run   # the full matrix, resumable
analysis/analyze.py results/my-run > summary.md
analysis/graph_metrics.py results/my-run --out analysis/out/my-run
analysis/analyze.py results/my-run --out analysis/out/my-run && analysis/figures.py analysis/out/my-run results/my-run/figures   # needs matplotlib
```

To build one layout by hand: `cd approach-tree && tuist generate`. Set `TUIST_LINKING=dynamic` for dynamic frameworks. Edit `spec/domains.yaml` and `sources/`, never the generated `approach-*` folders, and rerun the generator after any change.

## Results and data

| Path | Contents |
|---|---|
| `results/2026-11-macmini/<linking>-<N>-<scenario>.csv` | One row per timed build: layout, run, seconds, recompiled targets and files, exit code, power source |
| `results/2026-11-macmini/<config>.env.json` | Machine, toolchain and harness commit for each configuration |
| `results/2026-11-macmini/hangs.csv` | Every stalled build that was killed and retried (none appear in the timings) |
| `results/2026-11-macmini/state-check/` | A check of how prior build state affects incremental times |
| `results/2026-11-macmini/excluded-stall-recovery/` | Blocks timed after the old stall recovery, kept for transparency and left out of the analysis |
| `results/2026-11-macmini/figures/` | The paper figures (300 dpi PNG), each with a CSV of exactly the values it plots |
| [`results/2026-11-macmini/README.md`](results/2026-11-macmini/README.md) | Run notes |

Raw build logs stay local. Data from an earlier run on different hardware is not part of the repository and is not pooled with these results.

## Threats to validity

- **One machine.** Hardware independence is argued through target and file counts and through ratios, not absolute times.
- **Prior build state matters, and stall recovery once broke it.** Incremental times depend on the state a block of configurations builds up: cold derived data plus one warm-up build roughly doubles them ([state check](results/2026-11-macmini/state-check)). Until 2026-11-19, recovery from a stalled build deleted derived data, so every later build in that block ran up to about 2.8 times slower. The harness now retries in place and flags any row timed after a cold rebuild, and the three affected blocks (static 25 and 200 features, dynamic 100) were rerun in full. The first runs are kept in [`excluded-stall-recovery`](results/2026-11-macmini/excluded-stall-recovery) with the affected cells listed. Before the fix, two headline figures were wrong: a new private declaration with dynamic linking looked about 14 times faster (it is about 5), and the leaf feature at 200 features looked about 2.7 times faster (it is about 1.4).
- **Generated features.** Features beyond the first 16 come from templates, so their code is more uniform than a real app's.
- **Build system.** Xcode through Tuist only. Other build systems may behave differently.

## Citing

Please cite the benchmark if you use it or its data. Metadata is in [CITATION.cff](CITATION.cff), and GitHub shows a citation box from it.

## License

- **Code** (generator, sources, harness, analysis): MIT, see [LICENSE](LICENSE).
- **Paper and results** (`paper/`, `results/`): Creative Commons Attribution 4.0 International (CC BY 4.0), see [paper/LICENSE](paper/LICENSE) and [results/LICENSE](results/LICENSE). You may reuse and adapt them with credit.
