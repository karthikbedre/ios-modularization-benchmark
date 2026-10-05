# ios-modularization-benchmark

A benchmark for how module graph topology affects build time in a modular iOS app.

The same app, Civitas (a city services app), is built in two topologies from identical Swift sources:

- **tree** (`approach-tree/`): each domain is one module. Domains import the modules of the domains they use.
- **api-impl** (`approach-api-impl/`): each domain is split into `<Domain>API` and `<Domain>`. Domains import only the API modules of other domains. API modules import only core modules.

The two variants differ only in target membership, `import` lines and module boundaries. Both are generated from `spec/domains.yaml`.

## Layout

```
spec/domains.yaml            domains and their dependencies, the single source of truth
sources/                     canonical Swift sources, written against API modules
generator/                   civitas-gen: spec + sources -> both Tuist projects
approach-tree/               generated Tuist project, tree topology
approach-api-impl/           generated Tuist project, api-impl topology
bench/                       benchmark harness (planned)
results/                     raw benchmark data (planned)
paper/                       paper sources (planned)
```

## Requirements

- Xcode 26.3
- Tuist 4.210.0 (pinned in `mise.toml`)

## Generate and build

```
swift run --package-path generator civitas-gen
cd approach-tree
tuist generate
```

Static frameworks are the default. Set `TUIST_LINKING=dynamic` when running `tuist generate` to build every module as a dynamic framework.

Edit `spec/domains.yaml` and `sources/`, never the generated `approach-*` folders. Rerun the generator after any change.

## License

Code is MIT licensed (`LICENSE`). Contents of `paper/` and `results/` are licensed under CC BY 4.0 (see the `LICENSE` file in each folder).
