# Tasks

## 1. Implementation

- [x] 1.1 Support long-only boolean flags in lib/cli.sh
- [x] 1.2 Add `PROTECTED_BRANCHES` filtering and the `Protected:` banner line to commands/jef-merged.sh
- [x] 1.3 Record shas at scan, delete with update-ref and one leased push per repository, verify with ls-remote
- [x] 1.4 Keep branches checked out in any worktree
- [x] 1.5 Detect branches without commits of their own; add `--include-empty`
- [x] 1.6 Show the new notes consistently and exclude kept branches from the confirmation count

## 2. Tests and docs

- [x] 2.1 Update tests/merged.bats and tests/test_helper.bash (merged branches need a commit of their own)
- [x] 2.2 Add tests/merged-safety.bats (protected, races, worktree, empty branches) and long-only flag tests in tests/cli.bats
- [x] 2.3 Update README.md and .env.example

## 3. Checks

- [x] 3.1 Run `./scripts/check.sh --both`, `openspec validate merged-safety --strict` and `openspec validate --specs --strict`
