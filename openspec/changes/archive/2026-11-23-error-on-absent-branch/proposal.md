## Why
`jef merge feat devlop` (a typo) quietly skips every repository, prints "0 done, 0 failed, N skipped" and exits 0, so the mistake goes unnoticed.

## What Changes
- `jef merge <source> <target>` and `jef rebase <branch> <onto>` print "Branch '<name>' does not exist in any repository" for each named branch that exists locally (`refs/heads/<name>`) in none of the target repositories, and exit 2 before any change, plan or confirmation (also with `--dry-run`, `--yes` and no terminal).
- A branch present in only some repositories keeps today's behaviour: the other repositories are skipped silently.
- New shared helpers `branch_in_any_repo` and `require_branches_somewhere` in lib/repos.sh.

## Affected commands
- `jef merge` and `jef rebase` only.

## Out of scope
- Other commands (`checkout`, `pull`, `push`, `delete`, ...).
- Remote-only branches: nothing is fetched, so a branch that exists only on origin counts as absent.

## Impact
- Specs: branch-merge, branch-rebase. Code: lib/repos.sh, commands/jef-merge.sh, commands/jef-rebase.sh. Tests: tests/merge.bats, tests/rebase.bats (and any test passing a branch that exists nowhere). Docs: README.md.
