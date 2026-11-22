# Tasks

## 1. Implementation

- [x] 1.1 Add `magenta` and `cyan` to lib/terminal-color-codes.sh
- [x] 1.2 Print the listing and the `-D` plan as coloured bulleted blocks in commands/jef-merged.sh

## 2. Tests and docs

- [x] 2.1 Update tests/merged.bats (new format, colour test)
- [x] 2.2 Update the README example

## 3. Checks

- [x] 3.1 Run `./scripts/check.sh --both`, `openspec validate merged-list-output --strict` and `openspec validate --specs --strict`

## Dry run

- [x] Print `jef merged -D -n` as the same bulleted list under "Would delete these merged branches:"; update tests/merged.bats, README.md and the Dry run requirement
- [x] Print the result of `jef merged -D` as the same bulleted list under "Deleted merged branches:", marking branches that could not be deleted; update tests/merged.bats, README.md and the Delete requirement
