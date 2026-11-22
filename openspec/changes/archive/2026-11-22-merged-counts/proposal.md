## Why

The bulleted lists of `jef merged` give no sense of size. Counts next to each repository and `local`/`remote` label, and a grand total at the top, show at a glance how many branches are involved.

## What Changes

- Each repository name shows the number of branches listed under it, eg. `alpha (3)`.
- Each `local` / `remote` label shows the number of branches in that group, eg. `local (2)`.
- Each list (listing, `-D` plan, dry run, result) starts with `Total: N branches in M repositories` (singular for 1). Only repositories that show branches are counted; none is printed when nothing is merged.
- Counts have the colour of the name or label they follow.

## Capabilities

### Modified Capabilities
- `branch-merged`: the bulleted list format and the scenarios that show exact list lines.

## Impact

- `commands/jef-merged.sh` (`print_merged_tree`, new `print_merged_total`), `tests/merged.bats`, `README.md`.
