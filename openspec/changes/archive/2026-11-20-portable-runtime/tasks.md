# Tasks

## 1. Portable runtime

- [x] 1.1 Replace `realpath` in every `commands/jef-*.sh` with the portable symlink-following resolver; add tests (symlinked command absolute/relative, no `realpath` left); verify `bats tests`
- [x] 1.2 Gate colours on TTY and `NO_COLOR` in `lib/terminal-color-codes.sh`, make the spinner TTY-only in `lib/spinner.sh`; add tests for piped and `NO_COLOR` output of `jef find` and `jef which`; verify `bats tests`

## 2. Fewer remote calls

- [x] 2.1 `jef delete -r`: use `refs/remotes/origin/HEAD` with fallback; add a test with origin/HEAD set; verify `bats tests/delete.bats`
- [x] 2.2 `jef pull`: fetch once, check `refs/remotes/origin/<branch>` locally; add tests (no ls-remote, pruned branch skipped); verify `bats tests/pull.bats`

- [x] 2.3 Fix `jef find` table alignment (border padding and header printf arguments); add a test that every table line has the same plain-text width; verify `bats tests/find.bats`

## 3. .env home expansion

- [x] 3.1 Expand leading `~`, `$HOME`, `${HOME}` in `lib/load-env.sh`; add tests; verify `bats tests/common.bats`
- [x] 3.2 Update README.md (`.env` bullet, new Output note) and .env.example; verify by reading the diff

## 4. Final checks

- [x] 4.1 `./scripts/check.sh`, `JEF_BASH=/bin/bash ./scripts/check.sh`, `openspec validate portable-runtime --strict`, `openspec validate --specs --strict`
