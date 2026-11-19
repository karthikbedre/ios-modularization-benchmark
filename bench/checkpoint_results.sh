#!/bin/bash
# Commits the CSV and environment file of every finished configuration in a results folder,
# then pushes the current branch. Configurations still running (no .done marker) are left out.
#
#   bench/checkpoint_results.sh results/<run-name> [message]
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=${1:?usage: bench/checkpoint_results.sh <results-dir> [message]}
MESSAGE=${2:-"Add finished benchmark configurations to $OUT"}

for done in "$OUT"/*.done; do
    [ -e "$done" ] || continue
    base=${done%.done}
    git add -- "$base.csv" "$base.env.json"
done
for extra in README.md hangs.csv; do [ -f "$OUT/$extra" ] && git add -- "$OUT/$extra"; done

if git diff --cached --quiet; then echo "checkpoint: nothing new"; exit 0; fi
git commit -q -m "$MESSAGE"
branch=$(git branch --show-current)
for wait in 0 2 4 8 16; do
    sleep "$wait"
    if git push -q -u origin "$branch"; then echo "checkpoint: pushed $(git rev-parse --short HEAD)"; exit 0; fi
done
echo "checkpoint: committed $(git rev-parse --short HEAD) but push failed" >&2
exit 1
