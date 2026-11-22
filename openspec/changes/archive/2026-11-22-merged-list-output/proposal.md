## Why

`jef merged` prints comma-joined branch lines, which are hard to scan when a repository has many merged branches.

## What Changes

- The listing is a coloured bulleted list: repository name (green), `local`/`remote` labels (magenta), one `- branch` line per branch (cyan), the `(checked out, kept)` note (yellow). The "Working directory" header is dropped and problems are indented under the name.
- The plan shown by `-D` before the confirmation uses the same block, indented by 2.
- `lib/terminal-color-codes.sh` gains `magenta` and `cyan`.
- README example updated.

## Capabilities

### New Capabilities

### Modified Capabilities
- `branch-merged`: the "List merged branches" requirement describes the new output.

## Impact

commands/jef-merged.sh, lib/terminal-color-codes.sh, tests/merged.bats, README.md. The result lines of `-D` ("Deleted local branch X", ...) and the exit codes are unchanged.
