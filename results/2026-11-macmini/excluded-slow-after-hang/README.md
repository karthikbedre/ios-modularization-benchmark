# Set aside: static N=25 api-change, first full run

This configuration was restarted on 2026-11-16 at about 10:00 PST after a build hung and was killed. The restart deleted the derived data, so the series began from cold derived data plus one warm-up build. Its incremental timings were about twice those of the two runs completed before the hang (Notifications tree 23.4 s against about 12.0 s, with the same 360 compiled files).

## Cause (checked 2026-11-17)

Incremental build time depends on the build state left by earlier builds, not only on what is compiled. A controlled check at N=25, Notifications api-change, five runs per condition, same 21 and 13 compiled targets and the same files:

| Condition | tree | api-impl |
|---|---|---|
| A: cold derived data, one warm-up build | 23.5 s | 11.0 s |
| B: derived data after clean, noop, private-body, private-decl and public-impl builds, as in the matrix | 12.0 s | 5.9 s |

Every other configuration in the matrix ran on derived data that earlier configurations had already built, which is condition B. This folder (the set-aside run) and the rerun now in the parent folder both ran in condition A, so both are inconsistent with the rest of the matrix and should not be used as they are. The two pre-hang runs reflected the matrix state.

The same effect hit three static N=200 configurations after a stalled build was retried, because the retry deleted that topology's derived data (see `hangs.csv`): private-decl Notifications tree (69 s before, 169 s after), public-impl Identity tree (53 s before, 149 s after) and api-change Identity tree (54 s before, 150 s after, 8 of 10 runs affected).

These configurations need to be rerun in the matrix state. Until then, treat them as affected.
