## Context

Commands iterate repositories with `for_each_repo` and callbacks that print immediately. Parallel execution must work on bash 3.2 (no `wait -n`, no associative arrays) and keep output deterministic.

## Decisions

- **Value-taking flags**: new optional array `cli_value_flags` with entries `short|long|variable|METAVAR|default|type|description`. They are added to the getopts string with a trailing colon, support `--long VALUE` and `--long=VALUE`, and show as `-j, --jobs N` in help. Type `posint` validates a positive integer (usage error, exit 2). `cli_extra_flags` is untouched.
- **Slot scheduling by polling**: each job is a background subshell that writes `<i>.out` (stdout+stderr) and then `<i>.rc` (exit status). Before starting a job the runner counts jobs whose `.rc` file is missing and sleeps 0.05 s while that is >= N. Batching would idle on the slowest repo of each batch; `jobs -pr` would also count find's background spinner. A marker file per job avoids both, and needs no `wait -n`.
- **Waiting**: the runner waits on its own PIDs only; a bare `wait` would block forever on find's spinner.
- **Temp dir and traps**: one `mktemp -d` directory removed by an EXIT trap, which also kills unfinished jobs. EXIT is separate from the spinner's INT/TERM traps, which call `exit` and so still trigger it.
- **Outcome protocol**: the worker function writes the repo's output to stdout and returns 0 (done), 1 (failed) or 2 (skipped). The parent replays outputs in repository order, then applies outcomes with mark_repo_*, so finish_run and exit 3 are unchanged.
- **-j 1 uses the existing sequential path** (for_each_repo), so output stays byte-identical. find keeps one shared result-appending function for both paths. find's local lookup now sends stderr to /dev/null so worker output holds only the result.

## Risks

Output of fetch under -j N>1 is captured, so it appears after all jobs finish rather than live.
