# Proposal

## Why

Each of the 8 `commands/jef-*.sh` scripts repeats about 60 lines: long-to-short option mapping, `getopts`, the argument-count check, lib sourcing (some list files, `find`/`which` glob `lib/*.sh`) and the child-directory loop. The copies have drifted (for example `find` runs the proxy clear before its banner, the others after) and there is no way to ask a command what it does: `--help` is an "illegal option" and `jef` with no arguments fails with a shell "command not found".

## What Changes

- Add `lib/cli.sh`: one shared option parser (`-d/--directory`, `-c/--clear-proxy` for commands that accept it, `-h/--help`, plus per-command extra flags such as delete's `-r/--delete-remote-branch`), a usage printer and a `require_args` helper that keeps today's messages.
- Add `lib/repos.sh`: `for_each_repo <callback>` applies the existing `[ -d ]`, `SKIP_DIRS` and git-repo checks and calls the callback per repository; commands keep their own per-repository logic and header printing.
- Add `lib/common.sh`: the one way every command loads its libraries (`spinner.sh` and `clear-proxy.sh` stay explicit because of their side effects).
- Rewrite all 8 commands on top of these helpers; normal-run output stays byte-identical.
- `-h`/`--help` on every command prints usage and exits 0; an unknown option prints usage and exits 2.
- `jef` dispatcher: `jef`, `jef help`, `jef -h`, `jef --help` list commands; `jef help <command>` shows that command's help; an unknown command prints `jef: unknown command '<x>'` plus the list and exits 127.
- README: document `jef help`, `jef <command> --help` and a table of commands and flags.

Commands affected: checkout, delete, fetch, find, merge, pull, push, which, and the `jef` dispatcher.

Out of scope: new git behaviour, accepting options after positional arguments, changing banners/tables, install.sh, Windows support. The `quality-gates` and `harden-repo-iteration` changes are not edited.

## Capabilities

### New Capabilities

### Modified Capabilities
- `target-discovery`: ADDED requirement for per-command help/usage and unknown-option handling.
- `installation`: ADDED requirement for dispatcher help and unknown-command handling.

## Impact

- `commands/*.sh`, new `lib/cli.sh`, `lib/repos.sh`, `lib/common.sh`.
- `tests/`: new help/usage/dispatcher tests; the existing dispatcher "unknown command" test is updated for the new message.
- `README.md`. No new env vars, so `.env.example` is unchanged.
- Behaviour note: `jef find -c` now prints "Cleared proxy" after its banner, like every other command (it used to print it before).
