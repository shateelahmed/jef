# Tasks

## 1. Repo hygiene

- [x] 1.1 Replace `**/*test*` in `.gitignore` with an `.env`-only ignore; verify `git check-ignore tests/test_helper.bash` reports not ignored and `.env` still ignored
- [x] 1.2 Fix the stale gitignore note in `openspec/config.yaml`; verify `openspec validate --specs --strict` passes

## 2. Test suite

- [x] 2.1 Add `tests/test_helper.bash` (temp workspace, bare origins, isolated git, JEF_BASH, assertions); verify it loads in the suites
- [x] 2.2 Add bats suites for every command, the dispatcher, SKIP_DIRS, -d/--directory, TARGET_DIR fallback, arg-count errors and proxy clearing; verify `bats tests` passes
- [x] 2.3 Add skipped tests for known-broken behaviour (spaces, exit codes, worktrees/submodules); verify they run as skipped and fail only on behaviour when un-skipped

## 3. Check runner and CI

- [x] 3.1 Add executable `scripts/check.sh` (bash -n, shellcheck -S error, bats); verify exit 0 now and non-zero on an injected syntax error
- [x] 3.2 Add `.github/workflows/ci.yml` (ubuntu + macOS matrix, JEF_BASH=/bin/bash on macOS); verify YAML parses
- [x] 3.3 Run the suite under both `bash` and `/bin/bash` 3.2; verify both pass

## 4. Docs

- [x] 4.1 Update `AGENTS.md` objective checks and add a README "Development" section; verify both mention `./scripts/check.sh`
