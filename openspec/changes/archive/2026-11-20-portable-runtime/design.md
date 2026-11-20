## Context

See proposal.md. The commands locate the install root before `lib/` can be sourced, so the resolver cannot live in `lib/`.

## Decisions

- **Resolver duplicated in each command**: a ~7 line loop (`readlink` without `-f`, relative link targets resolved against the link's directory, then `cd ... && pwd -P`). Alternative: a shared file, rejected because it cannot be sourced before the location is known.
- **Colour gating in `lib/terminal-color-codes.sh`**: `[ -t 1 ]` and `NO_COLOR` empty; `tput ... 2>/dev/null || ""`. Any failure yields empty strings, so call sites need no change.
- **Spinner**: `spin` returns immediately and `endspin` skips the clear-line sequence when stdout is not a TTY, so no escape codes or carriage returns reach pipes.
- **delete -r**: `git symbolic-ref --quiet --short refs/remotes/origin/HEAD` with the `origin/` prefix stripped; fall back to `git remote show origin` parsing when it fails.
- **pull**: one `git fetch --all --prune` per repository with output captured; the header and captured output are printed only when `refs/remotes/origin/<branch>` exists. Output for matching repositories is unchanged (except git's TTY-only progress meter, which is not shown because output is captured). A failed fetch for a repository whose remote-tracking ref is absent is skipped silently as before; with a stale local ref the pull then reports its own error.
- **.env expansion**: applied after quote removal to values equal to or starting with `~/`, `$HOME/`, `${HOME}/`; uses substring offsets rather than quoted `${v#pattern}` (bash 3.2 quirks). Quoted values expand too, as in the previous sourced behaviour for double quotes.

## Risks / Trade-offs

- [Quoted single values like `'$HOME/x'` expand, unlike a shell] → acceptable, documented in README.
- [Piped tests cannot exercise the TTY colour path] → the gate is a single condition; tests cover the piped and `NO_COLOR` paths.
