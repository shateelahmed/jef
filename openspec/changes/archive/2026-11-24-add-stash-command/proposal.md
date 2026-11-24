## Why
Before switching or syncing branches across many repositories, local changes have to be stashed in each one by hand.

## What Changes
- New command `jef stash [-u|--include-untracked] [-n|--dry-run]`: runs `git stash push` in every repository that has local changes.
- Repositories with nothing to stash are skipped without output.
- `jef stash --clear [-y] [-n]`: runs `git stash clear` in every repository that has stashes, after showing how many each has and asking for confirmation (`-y` skips it).
- `jef stash --pop [-n]`: pops the latest stash in every repository that has one.
- `jef stash --list`: lists every repository's stashes as a bulleted list like `jef merged`.
- Listed in `jef help`; documented in README.md.

## Affected commands
- New `jef stash`; the `jef` dispatcher's command list.

## Out of scope
- `stash apply`/`drop` and choosing a stash entry other than the latest, stash messages, `-m` repository filter, parallel runs.
