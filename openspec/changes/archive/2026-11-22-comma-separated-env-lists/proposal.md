## Why

List-valued `.env` keys accepted commas and/or spaces. That is ambiguous and unsafe: a value such as `dev qa` read as one pattern would silently unprotect branches. Comma separated is the one clear form.

## What Changes

- **BREAKING**: `SKIP_DIRS` and `PROTECTED_BRANCHES` are split on commas only (whitespace around entries is trimmed, empty entries ignored).
- An entry that contains whitespace inside it is a configuration error: message on stderr, exit 2, before any repository is touched (`--help` still works). `PROTECTED_BRANCHES` is only validated by `jef merged`.
- The `jef merged` banner shows protected entries joined by `, `.
- The `-m`/`--repo` flag is not an env key and stays comma or space separated.

## Capabilities

### Modified Capabilities

- `target-discovery`: Skipping directories uses a comma separated `SKIP_DIRS`, validated up-front.
- `branch-merged`: Protected branches uses a comma separated `PROTECTED_BRANCHES`, validated up-front.

## Impact

- `lib/env-list.sh` (new), `lib/skip-directory.sh`, `lib/common.sh`, `commands/jef-merged.sh`, `README.md`, `.env.example`, tests.
