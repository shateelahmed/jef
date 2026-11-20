# Design

## Context

Scrippy is plain Bash with no build step. Naming is spread across: `commands/scrippy.sh` (dispatcher, runs `"scrippy-$command"`), `commands/scrippy-*.sh` (eight command scripts), `install.sh` (installs to `~/.scrippy`, globs `scrippy*.sh`, strips `.sh`, appends the commands dir to the rc file), README, AGENTS.md, `openspec/config.yaml` and several spec Purpose lines. The `lib/*.sh` files and `.env.example` contain no scrippy references. The installer copies the whole repo clone with rsync, so `.env` comes from the clone, not from the old install. See proposal.md for motivation.

## Goals / Non-Goals

**Goals:**
- A consistent `jef` name everywhere users or scripts see it.
- A safe upgrade path for people with an existing `~/.scrippy` install.
- Stay bash 3.2 / BSD compatible.

**Non-Goals:**
- Behaviour, flag or env-var changes; backward-compatible shims; repo/folder rename; packaging; Windows support (but `jef` and `jef-*` are valid Windows-friendly names); fixing pre-existing bugs (fetch always clearing proxy, spinner PID, `wc -L` on macOS).

## Decisions

1. **Clean break, no `scrippy` alias.** The tool is personal and early; an alias would keep two names alive and need its own removal later. Alternative: install a `scrippy` shim that warns and forwards, rejected as extra surface for little benefit.
2. **Rename with `git mv`** (`scrippy.sh` to `jef.sh`, `scrippy-X.sh` to `jef-X.sh`) to preserve history. The dispatcher becomes `"jef-$command" "$@"`. Because `install.sh` strips `.sh`, `jef.sh` installs as `jef`.
3. **Installer paths:** `installation_directory="$HOME/.jef"`, glob `jef*.sh` for both chmod and the `.sh`-stripping loop. The stale commented-out `bulk-git` line referencing scrippy is removed or updated.
4. **Legacy install handling is notice-only.** The installer must not delete `~/.scrippy` or edit old rc lines, since silently modifying user dotfiles or removing directories is hard to undo. Before the PATH step, it checks whether `$HOME/.scrippy` exists or the rc file contains `.scrippy/commands` (using `grep -q` with a fixed string, POSIX flags only). If so it prints a notice recommending `./uninstall-scrippy.sh`, with the manual steps as a fallback: `rm -rf ~/.scrippy` and delete the `export PATH=...~/.scrippy/commands` line from the rc file. Installation of `~/.jef` proceeds regardless. If the rc file does not exist, the check must not error out.
5. **No `.env` migration.** The installer rsyncs the repository directory, so the `.env` used is the one in the clone the user runs `install.sh` from. Nothing is read from `~/.scrippy`, so there is nothing to copy; the notice does not mention it.
6. **Env var names unchanged** (`TARGET_DIR`, `DEFAULT_BRANCH`, `SKIP_DIRS`): none are scrippy-prefixed.
7. **README** gets the new title, examples and install path, and a short "Migrating from scrippy" section mirroring the installer notice and documenting `uninstall-scrippy.sh`. Remaining "scrippy" mentions in the repo after the change are limited to that section, the installer notice, `uninstall-scrippy.sh`, and this change's artifacts.
8. **Specs:** requirement/scenario text is updated through MODIFIED deltas (installation, fetch, target-discovery) plus one ADDED requirement for the legacy notice. Purpose lines in the other specs are not requirements, so they are edited directly as part of apply.

9. **`uninstall-scrippy.sh`** (repo root, standalone Bash, bash 3.2/BSD-safe). Removing files and editing dotfiles is opt-in and explicit, so it lives in its own script rather than the installer.
   - **Finds:** the directory `$HOME/.scrippy`, and lines containing `/.scrippy/commands` that start with `export PATH=` in `~/.zshrc`, `~/.bashrc`, `~/.bash_profile`, `~/.profile` and `~/.<basename $SHELL>rc` (de-duplicated, existing files only). That is exactly what the old installer wrote, and it records the expanded absolute path, which this pattern still matches.
   - **Nothing found:** prints "No scrippy installation found." and exits 0, so it's safe to re-run.
   - **Confirm:** lists everything it will remove and asks `[y/N]`. `-y`/`--yes` skips the prompt. With no terminal and no `-y` it aborts with exit 1 and changes nothing.
   - **rc edits:** copies each file it edits to `<file>.scrippy-uninstall.bak` first, then removes only the matching lines. It filters with `grep -v` into a temp file and writes back with `cat tmp > file`, which keeps permissions and symlinked dotfiles and avoids the `sed -i` difference between macOS and GNU.
   - **Directory removal:** `rm -rf` only when `$HOME` is non-empty and the target is exactly `$HOME/.scrippy`. If it's a symlink, only the link is removed.
   - **Never touches** `~/.jef`, `.env` files, or any other rc line.
   - **Ends** by printing what was removed and reminding the user to restart the terminal or source the rc file.
   - **Alternative rejected:** having `install.sh` clean up automatically, because changing dotfiles without being asked is surprising and hard to undo.

## Risks / Trade-offs

- [Existing users' commands vanish after the old dir is removed or PATH is changed] → The notice and README migration section give exact steps; both old and new can coexist until cleanup since names do not collide.
- [Both PATH lines remain in the rc file] → Harmless; the notice asks the user to remove the old one.
- [Missed rename leaves a broken dispatch (`jef-$command` not found)] → Verification greps for `scrippy` and runs an installed `jef which` in a temp HOME.
- [Testing the installer touches the real HOME] → Use a temp `HOME` and a temp `SHELL` rc file.
- [Uninstaller removes a user-edited PATH line or the wrong directory] → Only lines matching both `export PATH=` and `/.scrippy/commands` are removed, rc backups are kept, the directory path is fixed to `$HOME/.scrippy`, and nothing happens without confirmation.
