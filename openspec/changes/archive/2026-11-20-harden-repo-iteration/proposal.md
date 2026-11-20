## Why

The `quality-gates` change added a test suite that pins current behaviour and records known bugs as skipped tests. These bugs make jef unreliable: paths or repo names containing spaces break every command, usage and configuration errors exit 0, git worktrees and submodules are ignored, and `.env` is executed as shell code (so an unquoted `SKIP_DIRS=archived, playground` runs `playground` as a command).

## What Changes

- Iterate child directories with a glob instead of parsing `ls` output; quote every path and branch variable so paths with spaces work everywhere. Check local branches with `show-ref --verify --quiet refs/heads/<branch>` and pass `--` to git where supported so branch names starting with `-` are not read as options.
- Exit with status 2 on usage errors (wrong argument count, invalid option) and 1 when the target directory is unset or invalid. Fix "1 arguments required" in `jef push` (singular for 1).
- Treat a child as a repository when `.git` exists as a file or directory, so linked worktrees and submodules are included; all commands use the shared `is_git_repo` helper.
- **BREAKING (minor)**: `.env` is parsed as data (`KEY=VALUE` lines, optional surrounding quotes, `#` comments) instead of being sourced. Shell syntax in `.env` (command substitution, `export`, variable expansion) is no longer evaluated. Unquoted values with spaces now work.
- Use `local` in shared helper functions; fix typos ("is each directory", "No supported").
- Raise shellcheck to `-S warning` in `scripts/check.sh` and fix the findings.
- Remove the skips from `tests/known_issues.bats` (moving the tests into the relevant suites) and add tests for the new behaviour.
- Update README.md (worktrees/submodules, spaces, exit codes, `.env` format; drop the quote-`SKIP_DIRS` and skipped-tests notes).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `target-discovery`: `.env` parsing, target directory exit status, first-level repository detection (worktrees/submodules, paths with spaces), argument-count exit status, and safe handling of branch names.

## Impact

- Commands affected: checkout, delete, fetch, find, merge, pull, push, which (and the dispatcher unchanged).
- Files: `commands/*.sh`, `lib/*.sh`, `install.sh`, `scripts/check.sh`, `tests/*.bats`, `README.md`.
- Out of scope: new commands/flags, changing output formats, Windows support, restructuring option parsing.
