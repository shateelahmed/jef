## Why
A `jef merge` that conflicts leaves a merge in progress in every repository that conflicted; backing out means running `git merge --abort` in each one by hand.

## What Changes
- New long-only flag `jef merge --abort [-n]`: runs `git merge --abort` in every repository where a merge is in progress. It takes no branch arguments.
- Repositories without a merge in progress are skipped without output; when none has one, "No merge in progress" is printed and the command exits 0.
- Documented in README.md and `jef merge --help`.

## Affected commands
- `jef merge`.

## Out of scope
- `--continue`, aborting rebases, cherry-picks or other operations, a `-m` repository filter, a confirmation question.
