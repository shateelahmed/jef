# Tasks

## 1. Shared library

- [x] 1.1 Generalise `confirm_or_exit` in lib/confirm.sh (optional verb and past participle, default delete/deleted); verify tests/delete.bats and tests/merged.bats pass unchanged

## 2. Rebase command

- [x] 2.1 Add commands/jef-rebase.sh: arguments, banner, plan phase, confirmation, rebase with abort on failure; verify with tests/rebase.bats
- [x] 2.2 Add `-p`/`--push` and `-n`/`--dry-run`; verify with tests/rebase.bats
- [x] 2.3 List `rebase` in commands/jef.sh

## 3. Tests

- [x] 3.1 Add tests/rebase.bats; add rebase to the command lists in tests/cli.bats and tests/dry-run.bats

## 4. Docs and checks

- [x] 4.1 Update README.md (feature bullet, usage, flags table row, exit codes, summary, dry-run and `--yes` notes)
- [x] 4.2 Run `./scripts/check.sh --both`, `openspec validate add-rebase-command --strict` and `openspec validate --specs --strict`
