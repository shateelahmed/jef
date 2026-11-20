# Proposal

## Why

"scrippy" is long to type for a tool run many times a day. `jef` is 3 letters, easy to type, and was found free on Homebrew, Debian, Arch/AUR, Snap, Chocolatey and Scoop, which keeps later packaging open.

## What Changes

- **BREAKING**: the CLI entry point `scrippy <command>` becomes `jef <command>`; every installed command is renamed (`jef`, `jef-checkout`, `jef-delete`, `jef-fetch`, `jef-find`, `jef-merge`, `jef-pull`, `jef-push`, `jef-which`). No `scrippy` alias is kept.
- Rename `commands/scrippy.sh` to `commands/jef.sh` and `commands/scrippy-*.sh` to `commands/jef-*.sh`; the dispatcher calls `jef-<command>`.
- **BREAKING**: `install.sh` installs to `~/.jef` (commands in `~/.jef/commands`) and adds that directory to PATH; it globs `jef*.sh`.
- New `uninstall-scrippy.sh` at the repo root removes a previous scrippy install: the `~/.scrippy` directory and the PATH line the old installer added to shell rc files. It shows what it will remove, asks for confirmation (`-y` skips the prompt), and backs up each rc file before editing it.
- `install.sh` prints a notice when a previous `~/.scrippy` install is detected, recommending `./uninstall-scrippy.sh` (manual steps as a fallback); it never deletes or edits old files itself.
- README: new title and name, all usage examples, install path, plus a short "Migrating from scrippy" section.
- Specs: update requirements and scenarios that mention scrippy commands or paths; update Purpose lines that mention them.
- `AGENTS.md` ("Scrippy specifics" heading and title) and `openspec/config.yaml` context and rules text: scrippy becomes jef.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `installation`: install location `~/.jef`, `jef-*` scripts, `jef` entry point and `jef-<command>` dispatch, a legacy-install notice, and a scrippy uninstaller.
- `fetch`: scenario command becomes `jef fetch`.
- `target-discovery`: `.env` lives in the jef installation root; argument-count scenario uses `jef checkout`.

The other specs (`branch-checkout`, `branch-delete`, `branch-find`, `branch-merge`, `branch-pull`, `branch-push`, `branch-status`) mention scrippy only in their Purpose line, not in any requirement or scenario, so they get no delta; their Purpose text is edited directly during apply.

## Impact

- Affected commands: all of them, by name: checkout, delete, fetch, find, merge, pull, push, which, and the dispatcher.
- Affected files: `commands/*.sh` (renames and dispatcher), `install.sh`, new `uninstall-scrippy.sh`, `README.md`, `AGENTS.md`, `openspec/config.yaml`, `openspec/specs/*/spec.md` (Purpose lines). `.env.example` has no scrippy mention and needs no edit (to be confirmed by grep).
- Existing users re-run the installer, then run `./uninstall-scrippy.sh` to remove the old install (see design.md).
- Env var names (`TARGET_DIR`, `DEFAULT_BRANCH`, `SKIP_DIRS`) and all command behaviour and flags are unchanged.

## Out of Scope

- Renaming the GitHub repository or the local project folder (done manually by the user).
- Publishing packages (Homebrew, AUR, Debian, Snap, Chocolatey, Scoop).
- Windows support (planned later; names chosen here stay Windows-friendly).
- Fixing pre-existing bugs (fetch always clearing proxy, spinner PID handling, `wc -L` on macOS).
- A backward-compatible `scrippy` alias or shim.
- An uninstaller for `jef` itself (can follow as a separate change).
