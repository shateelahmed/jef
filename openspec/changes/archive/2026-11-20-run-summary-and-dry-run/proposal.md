## Why

Batch commands ignore most git exit statuses and leave the user to scroll through per-repo output to learn whether anything failed, so scripts cannot detect failures. There is also no way to preview what a destructive command (delete, merge, push) would do.

## What Changes

- `checkout`, `delete`, `fetch`, `merge`, `pull` and `push` print a final line "Summary: X done, Y failed, Z skipped".
- These commands exit with status 3 when any repository failed (git failures are now captured).
- **BREAKING**: git failures inside a repository now change the exit code (previously always 0).
- `delete`, `merge` and `push` accept `-n`/`--dry-run`: they print what would happen and run no mutating git command.
- README documents the summary line, `--dry-run` and exit code 3.

## Capabilities

### New Capabilities

### Modified Capabilities
- `target-discovery`: summary line and exit status 3 for the batch commands.
- `branch-delete`: `--dry-run`.
- `branch-merge`: `--dry-run`.
- `branch-push`: `--dry-run`.

## Impact

Affected commands: checkout, delete, fetch, merge, pull, push (find and which are unchanged). Code: lib/repos.sh, lib/cli.sh (docs only), the six command scripts, tests, README.

Out of scope: `--dry-run` for checkout, fetch and pull; a summary for find and which; machine-readable output.
