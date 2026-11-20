# Design

## Context

Every command loads its helpers from `lib/`: `find` and `which` source every `lib/*.sh` file, and the other commands source specific files. Scripts must run on bash 3.2 with BSD tools (macOS) and on Linux. See proposal.md for the bugs.

## Goals / Non-Goals

**Goals:**
- A proxy check that is safe whether or not the calling command defines `clear_proxy`.
- Spinner stop and cleanup that does not depend on `$!` at call time.
- Width calculation with no external tool differences.

**Non-Goals:**
- Reworking the table rendering, including the known header misalignment in `find`.

## Decisions

1. **Proxy check: `[ "${clear_proxy:-false}" = true ]` instead of `if $clear_proxy`.** With an unset variable, `if $clear_proxy` runs an empty command, which succeeds. That is the root cause. A string test fails closed for unset, empty or misspelled values. `fetch` also initialises `clear_proxy=false` and gains the `c` getopts case, matching `push`/`pull`/`merge`/`find`/`delete`.
   - Alternative rejected: only initialising `clear_proxy=false` in each command. `which` sources the file via the glob without defining the variable, so the guard belongs in the lib.
2. **Spinner: `endspin` reads `SPINNER_PID`.** Both callers already set it, so `endspin` kills it, `wait`s on it, clears it, and prints a message only when given arguments.
   - The `wait` reaps the job, so bash prints no "Terminated" notice.
   - The INT/TERM traps call `endspin`, then exit 130 or 143.
   - Alternative rejected: passing the PID as `$1`. That would conflict with the existing "optional message" arguments and change every call site.
3. **Widths: new `lib/max-length.sh` with `max_length <items...>`**, using `${#item}`.
   - It matches how the headers were already measured (`${#header}`), counts characters in UTF-8 locales, and needs no subprocess or awk/wc variant.
   - Colour codes are stripped from `find` status cells into plain arrays before measuring.
   - Alternative rejected: `awk '{print length}'`. Its multibyte handling differs between BSD awk versions.
4. **`strip_color` uses `sed -E`.** It is supported by both GNU and BSD sed, while `-r` is a GNU-ism. This is a one-flag change in a line already being touched.

## Risks / Trade-offs

- [Behaviour change: `jef fetch` no longer clears the proxy implicitly] → README documents `-c`. The old behaviour was unintended and contradicted the spec.
- [`${#item}` counts bytes under the C/POSIX locale] → This matches the previous `wc -L` byte behaviour on GNU, so it is no regression.
