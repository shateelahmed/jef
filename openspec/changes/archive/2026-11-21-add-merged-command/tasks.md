# Tasks

## 1. Shared libraries

- [x] 1.1 Add value-flag type `list` to lib/cli.sh; verify with the list tests in tests/cli.bats
- [x] 1.2 Add lib/confirm.sh with `confirm_or_exit` and use it from commands/jef-delete.sh; verify tests/delete.bats still passes unchanged

## 2. Merged command

- [x] 2.1 Add commands/jef-merged.sh: fetch, merged test with the git 2.38 fallback, listing, `-l`/`-r`/`-m`; verify with tests/merged.bats
- [x] 2.2 Add `-D`/`-n`/`-y` deletion with confirmation and the checked-out branch rule; verify with tests/merged.bats
- [x] 2.3 List `merged` in commands/jef.sh and verify tests/dispatcher.bats passes

## 3. Tests

- [x] 3.1 Add tests/merged.bats (and helpers in tests/test_helper.bash) and list-flag cases in tests/cli.bats

## 4. Docs and checks

- [x] 4.1 Update README.md (feature bullet, usage with example output, flags table row, exit codes, summary, dry-run and `--yes` notes)
- [x] 4.2 Run `./scripts/check.sh --both`, `openspec validate add-merged-command --strict` and `openspec validate --specs --strict`
