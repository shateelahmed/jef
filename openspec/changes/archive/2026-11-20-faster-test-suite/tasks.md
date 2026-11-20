## 1. Fixture template

- [x] 1.1 Add `build_fixture_template`, `build_workspace_from_scratch` and template-copy `setup_workspace` with origin URL repointing in `tests/test_helper.bash`; verify with `bats tests/which.bats`
- [x] 1.2 Add `setup_file() { build_fixture_template; }` to every bats file using the workspace; add isolation tests (origin URL points at the test's own origins, template origins untouched after a push) in `tests/push.bats`; verify with `bats tests`

## 2. Parallel runner

- [x] 2.1 Make the interrupt test marker unique per run in `tests/parallel.bats`; verify with `bats tests/parallel.bats`
- [x] 2.2 Rewrite the bats step of `scripts/check.sh` to use `xargs -P`, add `--quick [files...]` and `--both`; verify with `bash -n`, `./scripts/check.sh --quick tests/which.bats` and `./scripts/check.sh`

## 3. Trim redundant tests

- [x] 3.1 Trim redundant per-command loops in `tests/common.bats` (keep one loop test per flag); list every removed test in the report; verify with `bats tests/common.bats`

## 4. Docs and final verification

- [x] 4.1 Update AGENTS.md "jef specifics" and the README "Development" section; verify by reading the diff
- [x] 4.2 Run `./scripts/check.sh` 3 times under bash and once with `JEF_BASH=/bin/bash`, plus `openspec validate faster-test-suite --strict` and `openspec validate --specs --strict`; record before/after timings
