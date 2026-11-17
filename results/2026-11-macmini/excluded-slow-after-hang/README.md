# Set aside: static N=25 api-change, first full run

This configuration was restarted on 2026-11-16 at about 10:00 PST after a build hung for 30 minutes and was killed. Its timings looked about twice as slow as the two runs completed before the hang (Notifications tree 23.4 s against about 12.0 s, with the same 360 compiled files), so it was set aside and run again after the full matrix finished.

The rerun reproduced these timings within 0 to 3 percent for every hub and topology, with identical compiled file counts. So the slowness was not caused by the killed build, and these rows are valid. The rerun in the parent folder is the one used in the analysis, and this folder is kept as a replication.

Open question: the two pre-hang runs (about 12 s for Notifications tree, about 5.9 s for api-impl) were discarded when the configuration restarted and are the outliers. Their logs are in logs/ on the benchmark Mac. A possible cause is a different warm-up state before the hang.
