# Tasks

## 1. Library fixes

- [x] 1.1 Rewrite `lib/load-env.sh` as a data parser, quote paths in `lib/target-directory.sh`, exit 1 on target errors, use `local` in helpers; verify with `bats tests/common.bats`
- [x] 1.2 `is_git_repo` uses `-e`; add `is_valid_branch_name`; verify with the worktree/submodule tests

## 2. Command fixes

- [x] 2.1 In every command: glob iteration, quoted variables, `is_git_repo`, exact branch check, `--`, exit 2 on usage errors, header typo, singular "argument" in push; verify with `bats tests`
- [x] 2.2 Fix install.sh typo ("Not supported"); verify with `bash -n install.sh`

## 3. Tests

- [x] 3.1 Move the tests from `tests/known_issues.bats` into the relevant suites, remove the skips and the file, add tests for unquoted/quoted/commented/invalid `.env` input, dash-prefixed branch names and exit codes; verify `bats tests` has 0 skips

## 4. Tooling and docs

- [x] 4.1 Raise shellcheck to `-S warning` in `scripts/check.sh`, add `.shellcheckrc`, fix all findings; verify `./scripts/check.sh`
- [x] 4.2 Update README.md (worktrees/submodules, spaces, exit codes, `.env` format, remove outdated notes); verify by reading the diff
- [x] 4.3 Run `./scripts/check.sh` with bash and with `JEF_BASH=/bin/bash`, `openspec validate harden-repo-iteration --strict` and `openspec validate --specs --strict`
