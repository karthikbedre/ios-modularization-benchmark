#!/bin/bash
# N=25 api-change anomaly check: cold derived data (A) against derived data with prior configurations (B).
set -u
cd ~/Documents/Personal/Research/ios-modularization-benchmark || exit 1
export PATH=/opt/homebrew/bin:$PATH
B=/private/tmp/claude-501/-Users-stark-Documents-eb1a/d1dd9187-0057-5561-9395-ec9daabb55b1/scratchpad/anomaly
R="mise exec -- caffeinate -i python3 bench/run.py --root build/scale/25 --hubs Notifications --cooldown 5"
echo "$(date): A cold"
$R --derived-data $B/derivedA --scenarios api-change --runs 5 --out $B/A/api-change.csv
echo "$(date): B history"
$R --derived-data $B/derivedB --scenarios clean,noop,private-body,private-decl,public-impl --runs 1 --out $B/B/history.csv
$R --derived-data $B/derivedB --scenarios api-change --runs 5 --out $B/B/api-change.csv
echo "$(date): done"
git status --porcelain -- build sources spec generator bench | head -3
