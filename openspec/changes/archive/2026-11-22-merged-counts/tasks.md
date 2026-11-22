# Tasks

## 1. Implementation

- [x] 1.1 Show branch counts next to repository names and `local`/`remote` labels in `print_merged_tree`
- [x] 1.2 Add `print_merged_total` and print it first in the listing and under the header of the plan, dry run and result

## 2. Tests and docs

- [x] 2.1 Update the exact-line expectations in `tests/merged.bats` and add tests for counts, the total (plural and singular), fetch-problem-only repositories and nothing merged
- [x] 2.2 Update the merged output example in `README.md`
- [x] 2.3 Run `./scripts/check.sh --both` and `openspec validate merged-counts --strict`
