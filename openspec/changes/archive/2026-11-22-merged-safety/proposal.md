## Why

`jef merged -D` can delete branches it should not: long-lived branches (develop, qa, staging, uat) that happen to be merged, origin branches somebody pushed to between the scan and the deletion, and branches that have no commits of their own (just created from the default branch).

## What Changes

- New `.env` key `PROTECTED_BRANCHES` (names or glob patterns, comma or space separated): matching branches are never listed or deleted. The default branch and origin's HEAD branch stay protected. The banner shows a `Protected:` line.
- Compare-and-delete: the scan records each branch's commit; local branches are deleted with `git update-ref -d <ref> <sha>`, remote ones with one `git push --delete` per repository using `--force-with-lease=<ref>:<sha>` per branch, then `git ls-remote` shows which are gone. A branch that moved since the scan is kept and shown as `(changed since scan, kept)`.
- A branch checked out in any worktree (not just the main one) is kept.
- Branches whose tip is on the default branch's first-parent history have no commits of their own: they are listed as `(no commits, kept)` and deleted only with the new long-only flag `--include-empty`.
- `lib/cli.sh` supports long-only boolean flags (empty short letter).
- The confirmation count excludes kept branches.

Affected commands: `jef merged` (and the shared option parser). Out of scope: other commands, protecting branches in `jef delete`, a short form of `--include-empty`.

## Capabilities

### New Capabilities

### Modified Capabilities
- `branch-merged`: new requirements "Protected branches", "Branches without own commits" and "Compare-and-delete"; "Checked-out branch is kept" and "Delete merged branches" change.

## Impact

commands/jef-merged.sh, lib/cli.sh, tests/merged.bats, tests/merged-safety.bats, tests/cli.bats, tests/test_helper.bash, README.md, .env.example.
