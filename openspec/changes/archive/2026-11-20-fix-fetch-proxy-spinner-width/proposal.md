# Proposal

## Why

The `rename-to-jef` change listed three bugs that were already there before it and left them out of scope:
- `jef fetch` cleared the proxy variables on every run, because it never initialised `clear_proxy`. `jef which` printed "Cleared proxy" for the same reason.
- The spinner was stopped by accident rather than by its PID.
- Table widths used GNU-only `wc -L`, which BSD/macOS `wc` may lack.

This change records their fixes. The fixes were implemented before this change was written down; see the Impact section.

## What Changes

- `jef fetch` accepts `-c`/`--clear-proxy` like the other remote-contacting commands. Without it, proxy variables are left alone; before this change they were always cleared.
- No command clears proxy variables or prints "Cleared proxy" unless `-c`/`--clear-proxy` was given. This also stops `jef which` from printing it.
- The spinner used by `jef find` and `jef which` is stopped by its recorded PID. It leaves no stray blank line or "Terminated" notice, and on Ctrl-C/SIGTERM it exits with the conventional codes 130 and 143.
- Table column widths in `jef find` and `jef which` are computed in portable bash instead of `wc -L`, so they work on macOS/BSD and count characters rather than bytes.
- README documents the new `fetch` flag.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `target-discovery`: "Optional proxy clearing" now states that proxy variables are left untouched, and nothing is printed, when the flag is not given, and that `jef fetch` is one of the commands that accept it.

The spinner and width fixes change no specified behaviour: `branch-find` and `branch-status` do not specify the spinner or how widths are computed. So they get no delta.

## Impact

- Affected commands: `fetch` (new flag, no longer clears the proxy by default), `which` (no spurious "Cleared proxy"), `find` and `which` (spinner, column widths). `checkout`, `delete`, `merge`, `pull` and `push` behave the same; they share the hardened proxy check.
- Files: `lib/clear-proxy.sh`, `lib/spinner.sh`, new `lib/max-length.sh`, `commands/jef-fetch.sh`, `commands/jef-find.sh`, `commands/jef-which.sh`, `README.md`.
- Users who relied on `jef fetch` clearing the proxy implicitly must now pass `-c`.
- No env var changes, so `.env.example` is unchanged.
- The fixes are already implemented in the working tree, uncommitted. This change records them, and its tasks are marked done once verified.

## Out of Scope

- The `jef find` table header row being one character narrower than its borders in the Local and Remote columns. This is a separate formatting bug.
- Other GNU/BSD portability audits beyond `wc -L` and `sed -r` in `strip_color`.
- Adding a `--clear-proxy` flag to `jef checkout` or `jef which`.
