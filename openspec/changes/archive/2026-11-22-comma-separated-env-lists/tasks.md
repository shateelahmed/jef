## 1. Implementation

- [x] 1.1 Add `lib/env-list.sh` (comma split, trim, ignore empties, reject entries with whitespace)
- [x] 1.2 Validate `SKIP_DIRS` when `lib/skip-directory.sh` is loaded by `lib/common.sh` (exit 2)
- [x] 1.3 Use it for `PROTECTED_BRANCHES` in `commands/jef-merged.sh`; banner joins entries with `, `
- [x] 1.4 Update README.md and .env.example

## 2. Tests and checks

- [x] 2.1 Update existing tests to comma separated values; add invalid-entry, whitespace and `--help` tests
- [x] 2.2 `./scripts/check.sh --both` and `openspec validate --specs --strict` pass
