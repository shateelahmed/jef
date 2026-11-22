## Context

`jef merged -D` scans once and deletes later, possibly after a confirmation prompt, so the world can change in between.

## Decisions

- **Protected branches**: `PROTECTED_BRANCHES` is split with globbing disabled (`set -f`) and matched with `case "$name" in $pattern)`, which works in bash 3.2. Local names and origin names (without `origin/`) are matched alike.
- **Compare-and-delete**: the scan keeps the sha of every candidate in arrays parallel to the name lists. Local: `git update-ref -d refs/heads/<b> <sha>` fails when the branch moved. Remote: one `git push origin --delete --force-with-lease=refs/heads/<b>:<sha> ... refs/heads/<b> ...`. A push can reject some branches and accept others, so a single `git ls-remote` afterwards tells which are gone: absent is deleted, a different sha is "changed since scan" (kept, not a failure), the same sha is a real failure. If ls-remote itself fails the push exit status decides.
- **Worktrees**: `update-ref` does not check worktrees, so `git worktree list --porcelain` is read once per repository and every branch checked out anywhere is kept.
- **Empty branches**: `git rev-list --first-parent <base>` is written to a temp file once per repository and each tip that already passed the ancestor test is looked up with `grep -qxF`. Squash and rebase merged branches (not ancestors) are never empty. A branch merged by fast-forward looks empty too and is kept: the safe side. The temp file is removed after each scan and by an EXIT trap (jef merged does not use parallel_run, which owns the other EXIT trap).
- **Long-only flags**: an `cli_extra_flags` entry with an empty short letter is set directly when its `--long` form is seen; getopts never sees it.
- **Notes**: `(checked out, kept)`, `(no commits, kept)` and `(changed since scan, kept)` are yellow, `(could not delete)` red, and every list (listing, plan, dry run, result) uses the same note function. The confirmation count only counts deletable branches.
