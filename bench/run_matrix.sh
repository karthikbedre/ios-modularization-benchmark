#!/bin/bash
# Runs the full benchmark matrix for the paper. Resumable: a configuration that finished is skipped,
# and one that was interrupted starts over, so rerun the same command after any stop.
#
#   caffeinate -i bench/run_matrix.sh results/<run-name>
#
# Close Xcode, keep the machine on power and idle. DRY=1 prints the commands without running them.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=${1:?usage: bench/run_matrix.sh <results-dir>}
mkdir -p "$OUT"
SCENARIOS="clean noop private-body private-decl public-impl api-change"

if [ -n "$(git status --porcelain -- sources spec generator bench)" ]; then
    echo "Commit sources, spec, generator and bench first, so every result traces to a commit." >&2
    [ -z "${DRY:-}" ] && exit 1
fi

run() {
    local name=$1 root=$2 linking=$3 scenario=$4; shift 4
    local base="$OUT/$name-$scenario"
    if [ -f "$base.done" ]; then echo "skip $name $scenario"; return; fi
    local command=(bench/run.py --root "$root" --linking "$linking" --scenarios "$scenario" --out "$base.csv" "$@")
    if [ -n "${DRY:-}" ]; then echo "${command[*]}"; return; fi
    rm -f "$base.csv"
    "${command[@]}"
    touch "$base.done"
}

for n in 25 50 100 200; do
    if [ -n "${DRY:-}" ]; then echo "civitas-gen --domains $n"; else swift run --package-path generator civitas-gen --domains "$n" --output "build/scale/$n"; fi
done

# Long builds vary little run to run (pilot CV 0.5 to 3.5% above 10 s), so large sizes use fewer runs.
for scenario in $SCENARIOS; do run static-16 . static "$scenario"; done
for n in 25 50; do
    for scenario in $SCENARIOS; do run "static-$n" "build/scale/$n" static "$scenario"; done
done
for n in 100 200; do
    for scenario in $SCENARIOS; do run "static-$n" "build/scale/$n" static "$scenario" --clean-runs 5 --incremental-runs 10; done
done
for scenario in $SCENARIOS; do run dynamic-16 . dynamic "$scenario"; done
for scenario in $SCENARIOS; do run dynamic-100 build/scale/100 dynamic "$scenario" --clean-runs 5 --incremental-runs 10; done
echo "matrix complete: $OUT"
