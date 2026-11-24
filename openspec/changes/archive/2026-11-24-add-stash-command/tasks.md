## 1. Command
- [x] 1.1 Add commands/jef-stash.sh (flags -u, -n; skip clean repos; Stashed / Could not stash / Would stash; finish_run)
- [x] 1.2 List `stash` in commands/jef.sh print_commands
- [x] 1.3 Add `--clear` (with `-y`, `-n`): plan, confirmation, `git stash clear`
- [x] 1.4 Add `--pop` (with `-n`) and `--list`; reject invalid option combinations

## 2. Tests and docs
- [x] 2.1 Add tests/stash.bats
- [x] 2.2 Update README.md (feature list, usage bullet, options table, summary/dry-run/exit-code notes)
- [x] 2.3 Add `--clear` tests and README notes
- [x] 2.4 Add `--pop`/`--list` tests and README notes
