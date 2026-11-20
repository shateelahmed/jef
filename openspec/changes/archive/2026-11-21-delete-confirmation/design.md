# Design

## Context

`commands/jef-delete.sh` already predicts actions for `--dry-run` inside its per-repository function. See proposal.md for motivation.

## Goals / Non-Goals

**Goals:** one prediction code path shared by dry run, the confirmation plan and the real deletion; confirmation that works on bash 3.2.

**Non-Goals:** confirmation for other commands; changing per-repository output or the summary.

## Decisions

- A read-only `plan_repo` function sets what a repository would do (local, remote, switch needed, refusal note, failure). `delete_in_repo` calls it for both dry run and real runs, so predictions cannot drift from behaviour. Alternative: a separate plan scanner duplicating the checks, rejected as it would drift.
- A silent plan phase builds the plan before anything changes. Remote queries are `ls-remote` and `symbolic-ref`/`remote show`, all read-only. The repository list is built once; each repository's plan is cached in parallel indexed arrays (bash 3.2 has no associative arrays) keyed by its position, and the deletion pass reuses it, so every remote is queried exactly once per run.
- The deletion pass (and dry run) prints a repository's header only when its plan has something to delete or a message; other repositories print nothing but are counted as skipped.
- If nothing is deletable the scan is skipped for prompting and the normal run executes, which only prints messages; this keeps today's output and exit codes (0, or 3 when a branch cannot be left).
- The answer is read from stdin only when `[ -t 0 ]` (same as uninstall.sh); otherwise exit 2. delete does not source lib/spinner.sh, so nothing interferes with the prompt.
- Colours use the existing variables only.

## Risks / Trade-offs

- State can change between the plan and the deletion (for example a push in between) → the real run re-checks the checkout and git results, and the confirmation covers the branch name and scope, not exact commits.
- The cached plan can be stale by the time of deletion → git itself still refuses/fails per repository and the outcome is reported as before.
