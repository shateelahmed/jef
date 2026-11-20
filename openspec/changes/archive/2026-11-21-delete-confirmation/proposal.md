## Why

`jef delete` removes branches (and with `-r` remote branches, which is hard to undo) in every repository without asking. A mistyped branch name or a forgotten `-r` has immediate consequences. The user should see what will be deleted, where, and confirm first.

## What Changes

- `jef delete` first scans every repository with read-only checks and prints a plan: per repository whether the branch will be deleted locally, on origin, or both, plus repositories where deletion is refused or fails.
- It then asks `Delete branch '<b>' in N repositories? [y/N]`. Only `y`/`yes` proceeds; anything else or EOF prints "Aborted. Nothing was deleted." and exits 1.
- New `-y`/`--yes` skips the prompt (the plan is still printed).
- Without a terminal on stdin and without `-y`, it prints the plan and "Not running in a terminal. Re-run with --yes to delete. Nothing was deleted." and exits 2.
- If nothing is deletable, no prompt is shown and the existing output and exit codes apply.
- `-n`/`--dry-run` never prompts; with `-y` dry run wins. Dry run and the plan share one prediction code path.
- **BREAKING**: non-interactive callers (scripts, CI) must now pass `-y`/`--yes` to `jef delete`.
- README documents the flag, the prompt and the new exit code meanings.

## Capabilities

### New Capabilities

### Modified Capabilities
- `branch-delete`: confirmation before deleting, `-y`/`--yes`, new exit codes 1 and 2 cases.

## Impact

Affected command: `delete` only. Code: commands/jef-delete.sh, tests, README.md. No change to `.env.example` (no env vars).

Out of scope: confirmation for `merge`, `push` or other commands; an environment variable to default to yes; per-repository prompts.
