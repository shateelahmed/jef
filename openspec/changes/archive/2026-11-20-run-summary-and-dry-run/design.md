## Context

Commands iterate repositories through `for_each_repo` with a callback that prints and runs git. Most git exit statuses are ignored today.

## Goals / Non-Goals

**Goals:** a uniform per-repo outcome, a summary line, a distinct exit status, a safe preview mode.
**Non-Goals:** changing per-repo output wording, retries, parallelism.

## Decisions

- **Outcome API in lib/repos.sh.** `for_each_repo` resets three counters; callbacks call exactly one of `mark_repo_done`, `mark_repo_failed`, `mark_repo_skipped`; `finish_run` prints the summary and exits 3 if any failed. Plain integer counters work in bash 3.2 (no associative arrays).
- **Semantics.**
  - done: the git operation succeeded (including a checkout that was already on the branch). In dry-run: the action would be performed.
  - failed: a git command failed, the target branch could not be checked out ("Could not checkout"), `delete` could not leave the branch or could not query/delete on origin, or `pull` could not fetch.
  - skipped: the repo was visited but the operation does not apply (branch absent locally/remotely; delete finds nothing to delete, or refuses to delete the remote default branch). Skipped repos stay as silent as before.
  - A repo with no mark (not applicable) is not counted; every visited repo is marked in practice.
- **Exit codes.** 3 if any failed, else 0. 1, 2 and 127 are unchanged and occur before the loop. 3 was chosen as the next unused value.
- **Summary colour** uses only the existing variables (empty when not a TTY); the failed count is red only when non-zero.
- **Dry run.** Declared via `cli_extra_flags` as `n|dry-run|dry_run`. Only read-only git (`show-ref`, `ls-remote`, `symbolic-ref`, `branch --show-current`) runs. `merge` and `push` skip the checkout. `delete` predicts the switch off the branch: it fails (same message) when the branch is the DEFAULT_BRANCH or DEFAULT_BRANCH does not exist locally. The banner always shows "Dry run: true|false".
- **delete keeps "Branch not found in any repository"** before the summary.

## Risks / Trade-offs

- [Scripts relying on exit 0 despite git failures] -> documented as BREAKING in README.
- [Dry run cannot predict conflicts, dirty-tree checkout failures or push rejections] -> it reports intent only.
