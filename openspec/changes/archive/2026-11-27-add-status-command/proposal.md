## Why
Before a `sync`, `merge` or `checkout` across many repositories you need to know each one's state: the branch it is on, whether it is ahead of or behind origin, whether it has local changes or stashes, and whether a merge or rebase is still in progress. Today that takes `jef which`, `jef stash --list` and a look into every repository.

## What Changes
- New read-only command `jef status [-f|--fetch] [-m|--repo REPOS] [-c|--clear-proxy]`: one aligned table row per repository with its branch, its position against `origin/<branch>`, its local changes, its stash count and any operation in progress, followed by a totals line.
- The information is collected in parallel; rows are printed in the usual repository order.
- Nothing is fetched unless `-f` is given.
- Listed in `jef help`; documented in README.md.

## Affected commands
- New `jef status`; the `jef` dispatcher's command list. `jef which` is unchanged.

## Out of scope
- Comparing against a configured upstream other than `origin/<branch>`, per-file listings, machine-readable output, `-j`.
