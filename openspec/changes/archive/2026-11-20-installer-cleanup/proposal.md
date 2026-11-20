# Proposal

## Why

`install.sh` copies the whole repository (openspec/, .claude/, tests/, README...) into `~/.jef` using rsync, deletes `~/.jef` first (which destroys a user's installed `.env`), always appends to `~/.${shell}rc` (wrong for bash on macOS, and writes bogus files for fish), carries a dead Windows branch that calls a non-existent `install.ps1`, and jef has no uninstaller of its own.

## What Changes

- `install.sh` copies only `commands/`, `lib/` and `.env` (if present) with `cp -R` (no rsync); still strips `.sh` and makes commands executable.
- Re-install preserves the installed `.env` when the clone has none; when both exist the clone's wins and the old one is backed up to `~/.jef.env.bak`.
- Shell rc selection: zsh to `~/.zshrc`; bash to `~/.bash_profile` (macOS) or `~/.bashrc` (Linux); any other shell: nothing is written, the exact PATH line is printed. The PATH check uses `grep -F`.
- Remove the dead `install_windows` body; keep a "Windows is not supported yet" message and exit 1.
- New `uninstall.sh`: lists what it removes, confirms (`-y`/`--yes`, aborts without a TTY and no `-y`), backs up each rc file before removing only the jef PATH line (no `sed -i`), removes `~/.jef` but keeps `.env` as `~/.jef.env.bak` (offered).
- New `tests/install.bats`.

Commands affected: none of the `jef-*` commands; only the installer and the new uninstaller.

Out of scope: Windows support, changes to `uninstall-scrippy.sh`, the `quality-gates`, `harden-repo-iteration` and `shared-command-scaffolding` changes. README.md is updated by the orchestrator, not in this change's implementation.

## Capabilities

### New Capabilities

### Modified Capabilities
- `installation`: MODIFIED "Unix installation" and "Unsupported platforms"; ADDED "Shell rc file selection", "Configuration preservation" and "jef uninstaller".

## Impact

- `install.sh`, new `uninstall.sh`, new `tests/install.bats`.
- README.md (install/uninstall section) needs updating; no new env vars, so `.env.example` is unchanged.
- Behaviour note: installs no longer contain `openspec/`, `tests/`, `README.md` and similar files; `uninstall-scrippy.sh` is not copied (run it from the clone).
