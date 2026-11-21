## Why

Repositories pile up branches that have already landed in the default branch. `jef delete` removes one named branch everywhere, but nothing finds the leftovers. A single command should list, per repository, the local and remote branches whose content is already in the default branch, and optionally delete them safely.

## What Changes

- New command `jef merged [-d DIR] [-c] [-l | -r] [-m REPOS] [-D] [-n] [-y]` lists the merged branches per repository.
- A branch counts as merged when it is an ancestor of the base (`origin/$DEFAULT_BRANCH`, else the local `$DEFAULT_BRANCH`) or merging it into the base would change nothing (this catches squash and rebase merges).
- Every selected repository is fetched first (`git fetch --prune origin`).
- `-l`/`--local` and `-r`/`--remote` restrict the scope; neither or both means both.
- `-m`/`--repo` limits the run to named repositories (comma or space separated, repeatable); an unknown or skipped name is a usage error.
- `-D`/`--delete` deletes the listed branches after the same confirmation as `jef delete`; `-n`/`--dry-run` shows what would be deleted and `-y`/`--yes` skips the question.
- The checked-out branch is listed as kept and never deleted.
- Internal: `lib/cli.sh` gets a value-flag type `list` (repeated flags accumulate); the confirmation prompt moves to `lib/confirm.sh` (`confirm_or_exit`).
- README documents the command.

## Capabilities

### New Capabilities
- `branch-merged`: listing and deleting branches merged into the default branch.

### Modified Capabilities

## Impact

Affected commands: the new `merged` command, and `delete`, which only gets an internal refactor (it uses `confirm_or_exit`; behaviour and messages are unchanged and guarded by tests/delete.bats). Code: commands/jef-merged.sh, commands/jef.sh, lib/cli.sh, lib/confirm.sh, commands/jef-delete.sh, tests, README.md. No change to `.env.example` (no new variables).

Out of scope: parallel `-j`, protected-branch patterns, remotes other than `origin`, changing HEAD away from a checked-out merged branch.
