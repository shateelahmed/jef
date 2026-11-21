## Why

After the base branch moves, feature branches across many repositories have to be rebased one by one. `jef merge` covers merging but nothing covers rebasing a branch onto another everywhere.

## What Changes

- New command `jef rebase [-d DIR] [-c] [-n] [-y] [-p] <branch> <onto_branch>`: in every repository where both branches exist locally, check out `<branch>` and run `git rebase <onto_branch>`. Repositories lacking either branch are skipped silently. Nothing is fetched.
- A read-only plan phase counts the commits to replay per repository; a branch that already contains `<onto_branch>` is reported as "already up to date" and skipped.
- The plan is printed and confirmed (`-y` skips the question, `-n` shows what would happen and never asks).
- A failing rebase (conflict, dirty working tree) is aborted if one is in progress, marks the repository failed and the run continues; the exit status is 3.
- `-p`/`--push` force-pushes the rebased branch with `--force-with-lease` to origin, only where commits were rewritten.
- Internal: `confirm_or_exit` in `lib/confirm.sh` takes an optional verb and past participle (default delete/deleted).
- README documents the command.

## Capabilities

### New Capabilities
- `branch-rebase`: rebasing a branch onto another across repositories.

### Modified Capabilities

## Impact

Affected commands: the new `rebase` command; `delete` and `merged -D` only through the `confirm_or_exit` internals (messages unchanged, guarded by tests/delete.bats and tests/merged.bats). Code: commands/jef-rebase.sh, commands/jef.sh, lib/confirm.sh, tests, README.md. No change to `.env.example` (no new variables).

Out of scope: a three-argument `--onto` form, interactive rebase, autostash, fetching before rebasing, remotes other than `origin`, resolving conflicts.
