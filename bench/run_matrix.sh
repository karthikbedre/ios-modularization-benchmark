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

# Derived data for one size can reach several GB per topology. It is rebuilt cold when needed.
DERIVED="$HOME/Library/Developer/CivitasBench"
free_size() {
    local folder=$1 linking=$2
    if [ -n "${DRY:-}" ]; then echo "free derived data: $folder $linking"; return; fi
    rm -rf "${DERIVED:?}/${folder:?}/tree-${linking:?}" "${DERIVED:?}/${folder:?}/api-impl-${linking:?}"
}

run() {
    local name=$1 root=$2 linking=$3 scenario=$4; shift 4
    local base="$OUT/$name-$scenario"
    if [ -f "$base.done" ]; then echo "skip $name $scenario"; return; fi
    local command=(bench/run.py --root "$root" --linking "$linking" --scenarios "$scenario" --out "$base.csv" "$@")
    if [ -n "${DRY:-}" ]; then echo "${command[*]}"; return; fi
    local folder attempt code
    folder=$([ "$root" = . ] && echo ios-modularization-benchmark || basename "$root")
    for attempt in 1 2 3; do
        rm -f "$base.csv"
        code=0
        "${command[@]}" || code=$?
        if [ "$code" -eq 0 ]; then touch "$base.done"; return; fi
        # Exit 3 means a build hung and was killed. Start the configuration over from cold derived data.
        if [ "$code" -ne 3 ]; then echo "FAILED: $name $scenario exited $code" >&2; exit "$code"; fi
        echo "restarting $name $scenario after a hung build (attempt $attempt)"
        rm -rf "${DERIVED:?}/${folder:?}/tree-${linking:?}" "${DERIVED:?}/${folder:?}/api-impl-${linking:?}"
        # The restart begins from cold derived data, so its timings are flagged (see COLD_MARKER in run.py).
        for topology in tree api-impl; do
            mkdir -p "$DERIVED/$folder/$topology-$linking"
            date -u +%Y-%m-%dT%H:%M:%SZ > "$DERIVED/$folder/$topology-$linking/.bench-cold-restored"
        done
    done
    echo "FAILED: $name $scenario hung three times" >&2
    exit 3
}

for n in 25 50 100 200; do
    if [ -n "${DRY:-}" ]; then echo "civitas-gen --domains $n"; else swift run --package-path generator civitas-gen --domains "$n" --output "build/scale/$n"; fi
done

# Long builds vary little run to run (pilot CV 0.5 to 3.5% above 10 s), so large sizes use fewer runs.
# Each size's derived data is freed as soon as that size is done, so only one size is on disk at a time.
for scenario in $SCENARIOS; do run static-16 . static "$scenario"; done
free_size ios-modularization-benchmark static
for n in 25 50; do
    for scenario in $SCENARIOS; do run "static-$n" "build/scale/$n" static "$scenario"; done
    free_size "$n" static
done
for n in 100 200; do
    for scenario in $SCENARIOS; do run "static-$n" "build/scale/$n" static "$scenario" --clean-runs 5 --incremental-runs 10; done
    free_size "$n" static
done
for scenario in $SCENARIOS; do run dynamic-16 . dynamic "$scenario"; done
free_size ios-modularization-benchmark dynamic
for scenario in $SCENARIOS; do run dynamic-100 build/scale/100 dynamic "$scenario" --clean-runs 5 --incremental-runs 10; done
free_size 100 dynamic
echo "matrix complete: $OUT"
