# Design

## Context

`jef merge` checks out the target and merges the source; `jef delete` and `jef merged -D` plan, confirm, then act with plan results cached in indexed arrays (bash 3.2 has no associative arrays). `jef rebase` combines both.

## Goals / Non-Goals

**Goals:** a safe bulk rebase that never leaves a repository mid-rebase; one read-only query per repository shared by the plan and the run; the confirmation behaviour of `jef delete`.

**Non-Goals:** `--onto` form, interactive rebase, autostash, fetching, conflict resolution.

## Decisions

- **Arguments.** `<branch> <onto_branch>` mirrors `jef merge <source> <destination>`. Both must exist locally, else the repository is skipped silently. No fetch, like merge.
- **Up to date.** If `onto` is an ancestor of `branch`, a rebase would change nothing: the repository is skipped without checking out anything and is never pushed.
- **Plan.** `git rev-list --count onto..branch` gives the commits to replay. The plan lists every repository with both branches; the question counts only those that will be rebased. No question when nothing will be rebased; a dry run never asks and wins over `--yes`.
- **Failure handling.** If `git rebase` fails, `git rebase --abort` runs only when `rebase-merge` or `rebase-apply` exists (found with `git rev-parse --git-path`), so a refusal (for example a dirty working tree) aborts nothing. The repository is marked failed and the run continues.
- **Push.** `git push --force-with-lease origin <branch>` after a successful rebase, so a push never overwrites commits that were not fetched. A failed push marks the repository failed.
- **Checkout.** `<branch>` stays checked out afterwards, as `merge` leaves its target.
- **Confirmation.** `confirm_or_exit <question> [<verb> <past>]` defaults to delete/deleted so existing messages stay byte-identical.

## Risks / Trade-offs

- A dirty working tree that git carries across the checkout makes the rebase refuse; the checkout has then already moved HEAD to `<branch>`.
- `--force-with-lease` relies on the remote-tracking ref; a stale one makes the push fail, which is the safe direction.
