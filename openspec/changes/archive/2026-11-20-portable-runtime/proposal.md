## Why

jef still has portability and compatibility gaps: `realpath` is missing on macOS before 13 (every command fails at startup), colour codes and the spinner's escape sequences leak into piped output and ignore `NO_COLOR`, `jef delete -r` and `jef pull` make avoidable network calls, and the data-only `.env` parser from `harden-repo-iteration` stopped expanding `~` and `$HOME`, which breaks existing configurations such as `TARGET_DIR=~/code`.

## What Changes

- Replace `realpath` in every command with a small portable resolver (loop with plain `readlink`, then `cd ... && pwd -P`) that also follows a symlinked command.
- Emit colour codes only when stdout is a TTY and `NO_COLOR` is unset or empty (and `tput` works); otherwise the colour variables are empty. The spinner draws and clears only on a TTY. Piped `jef find` and `jef which` output therefore contains no escape codes.
- `jef delete -r` reads the remote default branch from the local `refs/remotes/origin/HEAD` and falls back to `git remote show origin` only when that ref is missing.
- `jef pull` fetches once (output captured), checks `refs/remotes/origin/<branch>` locally and skips the repository silently when it is absent, replacing the `ls-remote` plus `fetch` pair.
- `.env` values: a leading `~`, `$HOME` or `${HOME}` expands to `HOME`. Nothing else is expanded.
- Fix the `jef find` table: borders now pad the Local and Remote columns by 2 like the Directory column, and the header row no longer shifts its width arguments, so border, header and rows align.
- README.md and .env.example document the `.env` expansion and a new "Output" note.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `target-discovery`: `.env` home expansion, colour output behaviour (TTY and `NO_COLOR`), and independence from the location/symlinks of the command.

## Impact

- Commands affected: checkout, delete, fetch, find, merge, pull, push, which (script location), delete and pull (remote queries), find and which (colour).
- Files: `commands/*.sh`, `lib/terminal-color-codes.sh`, `lib/spinner.sh`, `lib/load-env.sh`, `tests/*`, `README.md`, `.env.example`.
- Out of scope: install section, Windows support, new commands or flags, other `.env` expansion (`$VAR`, `~user`, command substitution).
