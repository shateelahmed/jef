## Why

`jef fetch` and `jef find` spend almost all their time waiting on the network, one repository after another. Running a few repositories at once makes them much faster on large workspaces.

## What Changes

- `jef fetch` and `jef find` accept `-j N` / `--jobs N` (positive integer, default 1) to process up to N repositories concurrently.
- Output is deterministic: per-repo output (fetch) and table rows (find) appear in the normal repository order, and the fetch summary and exit status 3 keep working.
- An invalid N (0, negative, non-numeric, missing) is a usage error (exit 2).
- With the default of 1 the behaviour and output are unchanged.
- `lib/cli.sh` gains a generic value-taking flag declaration (`cli_value_flags`); `lib/repos.sh` gains a bash 3.2 compatible parallel runner.
- README documents the flag.

## Capabilities

### New Capabilities

### Modified Capabilities
- `fetch`: `-j`/`--jobs` with ordered output.
- `branch-find`: `-j`/`--jobs` with ordered table rows.

## Impact

Affected commands: fetch, find. Code: lib/cli.sh, lib/repos.sh, commands/jef-fetch.sh, commands/jef-find.sh, tests, README.

Out of scope: parallelism for commands that change repositories (checkout, delete, merge, pull, push), a configurable default via env var, progress output per job.
