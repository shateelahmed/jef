## 1. Outcome tracking

- [x] 1.1 Add mark_repo_done/failed/skipped and finish_run to lib/repos.sh
- [x] 1.2 Capture git exit codes and mark outcomes in checkout, delete, fetch, merge, pull, push; call finish_run

## 2. Dry run

- [x] 2.1 Declare -n/--dry-run in delete, merge, push; print "Would ..." lines and run no mutating git command

## 3. Tests and docs

- [x] 3.1 Add tests/summary.bats (summary counts, exit 3, dry-run unchanged refs, help text)
- [x] 3.2 Update README.md (flags table, exit codes, summary line)
- [x] 3.3 Run ./scripts/check.sh with bash and JEF_BASH=/bin/bash; validate OpenSpec
