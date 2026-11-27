## Columns
| Column | Values |
|---|---|
| Repository | directory name |
| Branch | current branch, or `(detached <short sha>)` |
| Origin | `up to date`, `ahead N`, `behind N`, `ahead N, behind M`, `not on origin` (no `refs/remotes/origin/<branch>`), `-` when detached |
| Changes | `clean`, or a comma list of `N conflicted`, `N changed`, `N untracked` (from `git status --porcelain`: unmerged XY codes DD AU UD UA DU AA UU are conflicted, `??` untracked, anything else changed) |
| Stashes | the number of stash entries, `-` for none |
| State | `merging` (MERGE_HEAD), `rebasing` (rebase-merge or rebase-apply directory, resolved with `git rev-parse --git-path`), `cherry-picking` (CHERRY_PICK_HEAD), `reverting` (REVERT_HEAD); empty otherwise |

Compared against `origin/<branch>` rather than the configured upstream, because `jef checkout -b` creates branches with `--no-track` and `jef push` pushes to `origin/<branch>`.

## Colours (terminal only, never with NO_COLOR)
Green: `up to date`, `clean`. Yellow: `ahead`/`behind`, `not on origin`, changed/untracked counts, stash counts. Red: conflicted counts, any State value, `fetch failed`. Padding is computed on the plain text so columns stay aligned with colours.

## Parallelism
Each repository's row is collected by a worker under `parallel_run` (lib/repos.sh) with all repositories at once, writing one tab-separated line to a per-repository file; the main process then reads the files in repository order, computes column widths and prints. With `-f` each worker first runs `git fetch --prune origin` quietly.
