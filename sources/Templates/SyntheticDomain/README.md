# Synthetic domain template

`civitas-gen --domains N` expands this template for every domain beyond the hand-written seeds.

Placeholders:

- `__Domain__` is the type-style name, for example `StreetPermits`
- `__domain__` is the value-style name, for example `streetPermits`
- `__TITLE__` is the display name, for example `Street Permits`
- `__Dep__` and `__dep__` are the same for one dependency. Any line that contains them is repeated once per dependency, so a domain with no dependencies drops those lines entirely.

Template files use the `.swift.template` and `.json.template` extensions, so nothing in this folder compiles or ships until the generator expands it.
