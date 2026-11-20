# Tasks

## 1. Installer

- [x] 1.1 Rewrite `install.sh`: cp -R of commands/, lib/ and .env only, strip .sh, chmod, .env preservation/backup, rc-file selection, grep -F PATH check, legacy notice, Windows stub. Verify with `bash -n install.sh` and manual run under a temp HOME
- [x] 1.2 Add `uninstall.sh` (list, confirm, --yes, no-TTY abort, rc backup + line removal, .env backup, remove ~/.jef). Verify with `bash -n uninstall.sh` and manual run under a temp HOME

## 2. Tests

- [x] 2.1 Add `tests/install.bats` covering layout, executables, .env preservation, idempotent PATH line, zsh/bash/fish, and uninstall flows (n, --yes, no-tty). Verify `bats tests/install.bats` passes and `./scripts/check.sh` passes

## 3. Docs and validation

- [x] 3.1 Put the proposed README install/uninstall text in the report (orchestrator applies it); no .env.example change needed
- [x] 3.2 Verify `openspec validate installer-cleanup --strict` and `openspec validate --specs --strict` pass
