# Tasks

## 1. Proxy clearing

- [x] 1.1 Change `lib/clear-proxy.sh` to clear only when `clear_proxy` is exactly `true`. Verify that `jef which -d <dir>` and `jef fetch -d <dir>` do not print "Cleared proxy".
- [x] 1.2 Add `-c`/`--clear-proxy` to `commands/jef-fetch.sh` (long-option mapping, `clear_proxy=false` default, `c` getopts case). Verify that `jef fetch -c -d <dir>` prints "Clear proxy: true" and "Cleared proxy".
- [x] 1.3 Update the `jef fetch` line in `README.md` to document `-c`/`--clear-proxy`, and confirm `.env.example` needs no change (no new env var). Verify by reading the README usage section.

## 2. Spinner

- [x] 2.1 Rewrite `endspin` in `lib/spinner.sh` so that it:
  - kills, waits on and clears `SPINNER_PID`;
  - clears the line;
  - prints a message only when given arguments.

  Split the traps so INT exits 130 and TERM exits 143. Verify that `jef which` and `jef find` under `/bin/bash` (3.2) show no stray blank line or "Terminated" notice before the table.

## 3. Portable column widths

- [x] 3.1 Add `lib/max-length.sh` with `max_length`. Verify that `max_length abc "" abcdefg` prints `7` under `/bin/bash`.
- [x] 3.2 Replace the `wc -L` width calculations in `commands/jef-which.sh` and `commands/jef-find.sh` with `max_length`. In `find`, measure colour-stripped status arrays, and switch `strip_color` to `sed -E`. Verify that `grep -rn "wc -L\|sed -r" commands lib` finds no code uses, and that both tables render with widths fitting the longest entry.

## 4. Integration checks

- [x] 4.1 Run `bash -n` on every `.sh` file in `commands/`, `lib/`, `install.sh` and `uninstall-scrippy.sh`; all exit 0.
- [x] 4.2 Run `openspec validate fix-fetch-proxy-spinner-width --strict` and `openspec validate --specs --strict`; both pass.

## Workflow follow-up

- Archive the change only when the user explicitly asks.
