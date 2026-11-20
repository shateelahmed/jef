# Design

## Context

See proposal.md. Must run on bash 3.2 / BSD tools and Linux. Tests run both scripts with a temporary `HOME` and a fake `SHELL`; only its basename matters.

## Decisions

- **cp -R of three paths instead of rsync**: rsync is not guaranteed present; an allow-list (commands, lib, .env) cannot accidentally ship dev files, unlike an exclude-list.
- **Preserve .env by stashing it**: before `rm -rf ~/.jef`, the installed `.env` is copied to a temp file. After the copy: no clone `.env` means restore the stash; both exist means the clone's wins and the stash is written to `~/.jef.env.bak` (only if the contents differ). Alternative (rsync-style in-place update of ~/.jef) rejected: stale files from older versions would linger.
- **Rc selection by basename of `$SHELL`**: `case` on zsh, bash (with `$OSTYPE` darwin* vs other), anything else prints the PATH line. Alternative of detecting the running shell via `$ZSH_VERSION` is useless because the script runs under bash.
- **uninstall.sh keeps the .env via a backup copy**: with a prompt-free default (the confirmation already lists it), `.env` is always copied to `~/.jef.env.bak` when present and non-empty, rather than a second prompt which would complicate `--yes` and non-TTY use. The listing says so.
- **Rc editing without sed -i**: `cp -p` to `<rc>.jef-uninstall.bak`, then `grep -vF`-style filtering into a temp file and `cat` back (keeps symlinks and permissions), same approach as `uninstall-scrippy.sh`. Only lines containing `/.jef/commands` are removed.

## Risks / Trade-offs

- Windows users get exit 1 as before (was exit 0 in the dead branch) → documented.
- Uninstall does not touch the rc files where jef's PATH line was never added (e.g. fish) → nothing to remove; ~/.jef is still removed.
