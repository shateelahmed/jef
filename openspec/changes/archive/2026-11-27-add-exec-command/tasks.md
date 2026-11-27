## 1. Option parsing
- [x] 1.1 lib/cli.sh: opt-in `cli_pass_through=true`: the --help scan, long-option conversion and getopts stop at the first positional word (after skipping values of value flags) or at `--` (dropped); everything after is cli_positional untouched
- [x] 1.2 tests/cli.bats: pass-through cases; other commands unchanged

## 2. Command
- [x] 2.1 Add commands/jef-exec.sh (banner, -m, -j via parallel_run, -b, -n, bash -c vs argv, JEF_REPO, </dev/null, failure line, finish_run)
- [x] 2.2 List `exec` in commands/jef.sh print_commands

## 3. Tests and docs
- [x] 3.1 Add tests/exec.bats covering every scenario; add exec to command lists in tests that enumerate commands
- [x] 3.2 Update README.md (feature list, usage bullet with examples, options table, exit-code and -n notes)
