## 1. Helpers
- [x] 1.1 Add `branch_in_any_repo` and `require_branches_somewhere` to lib/repos.sh

## 2. Commands
- [x] 2.1 commands/jef-merge.sh: after the banner, run `list_repos` and `require_branches_somewhere` before anything else
- [x] 2.2 commands/jef-rebase.sh: call `require_branches_somewhere` right after `list_repos` in the plan phase

## 3. Tests and docs
- [x] 3.1 Add tests to tests/merge.bats and tests/rebase.bats; fix existing tests that pass a branch existing in no repository
- [x] 3.2 Update README.md (merge and rebase usage, exit code 2 list)
