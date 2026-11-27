#!/usr/bin/env bash
# Run training jobs from a list, at most P at a time. On the PC's 8 GB card two
# jobs of 16,384 households a step fit; a third spills GPU memory into system
# memory and the jobs die of out-of-memory errors.
#   bash neural/scripts/queue.sh neural/jobs/<name>.jobs [P]
# Each line of the jobs file: <tag> <testset.mat> [<testset2.mat>] variants=<v>
# (the arguments of train_rung.jl); lines starting with # are skipped. The log
# of each job is neural/data/logs/<tag>.txt. JULIA_FLAGS (for example
# --heap-size-hint=3G) is passed to julia.
set -u
jobs=$1
P=${2:-2}
cd "$(dirname "$0")/../.."
mkdir -p neural/data/logs
grep -v -E '^\s*(#|$)' "$jobs" | xargs -P "$P" -L 1 bash -c '
    tag=$0
    start=$(date +%H:%M)
    julia ${JULIA_FLAGS:-} --project=neural neural/scripts/train_rung.jl "$tag" "$@" > "neural/data/logs/$tag.txt" 2>&1
    rc=$?
    echo "$tag: started $start, ended $(date +%H:%M), exit $rc"'
