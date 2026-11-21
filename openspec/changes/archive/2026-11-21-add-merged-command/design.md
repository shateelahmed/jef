# Design

## Context

`jef delete` already has a plan, confirm, act structure with cached results in indexed arrays (bash 3.2 has no associative arrays). `jef merged` follows it. See proposal.md for motivation.

## Goals / Non-Goals

**Goals:** detect squash and rebase merges as well as ordinary ones; one scan per repository shared by the listing, the plan and the deletion; the same confirmation behaviour as `jef delete`.

**Non-Goals:** parallel scanning, protected-branch patterns, remotes other than `origin`.

## Decisions

- **Merged test.** Branch B is merged when `git merge-base --is-ancestor B base` succeeds, or when `git merge-tree --write-tree base B` succeeds and the tree it prints equals `git rev-parse base^{tree}` (merging B would change nothing, which is what a squash or rebase merge leaves). Alternative: `git cherry`, rejected because it fails for squash merges.
- **Git 2.38 fallback.** `merge-tree --write-tree` needs git 2.38. The version is parsed once from `git --version`; on older (or unparseable) versions a single notice is printed and only the ancestor test is used.
- **Base.** `origin/$DEFAULT_BRANCH` if it exists (so the check reflects the freshly fetched remote), else the local `$DEFAULT_BRANCH`; if neither exists the repository is skipped with a message.
- **Excluded branches.** `$DEFAULT_BRANCH`, `origin/HEAD` and origin's HEAD branch (from the local `refs/remotes/origin/HEAD`, no network).
- **Fetch failure.** The repository is marked failed and its remote branches are not examined (they would be stale); local branches still are.
- **Scan once.** A silent scan phase fetches and tests each repository and caches the results in parallel indexed arrays keyed by position in the repository list; listing, plan and deletion reuse them.
- **Checked-out branch.** Listed as `(checked out, kept)` and never deleted; unlike `jef delete` it does not switch branches, so a bulk cleanup never moves HEAD.
- **Deleting.** Local branches use `git branch -D` (`-d` refuses squash-merged branches, which the merged test has already proven safe). Remote branches of a repository are deleted with one `git push origin --delete`.
- **List flags.** `lib/cli.sh` gets value-flag type `list`: repeated occurrences are joined with a space. `-m` uses it; the command splits on commas and spaces.
- **Confirmation.** `confirm_or_exit <question>` in `lib/confirm.sh` holds the tty check, prompt and abort messages moved verbatim from `jef delete`.

## Risks / Trade-offs

- A squash-merged branch whose files were later changed on the base is no longer detected (merging it would change something), so it is not listed. Safe direction: nothing is deleted wrongly.
- Branches pushed or merged between the scan and the deletion: git itself still decides per branch, and the confirmation covers the listed branches, not exact commits.
