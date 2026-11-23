# branch-sync Specification

## Purpose
Bringing every local branch up to date with the default branch across all repositories, in parallel: pull the default branch, then pull, merge (or rebase) and push each other branch (`jef sync [-r] [-m REPOS] [-j N] [-c] [-n] [-y]`).

## Requirements

### Requirement: Sync every local branch with the default branch
`jef sync` SHALL, in each repository, pull the local `DEFAULT_BRANCH`, then for every other local branch (alphabetically, protected ones included) pull it from `origin` when it exists there, merge the default branch into it (`-r`/`--rebase`: rebase it) and push it only when it differs from `origin/<branch>` (`--force-with-lease` when rebasing). A branch not on `origin` is synced locally only. No positional arguments; exit 1 when `DEFAULT_BRANCH` is not set.

#### Scenario: Merge mode
- **WHEN** `jef sync -y` is run and `alpha` has branch `feat` on `origin` and the default branch has new commits on `origin`
- **THEN** the default branch is fast-forwarded, `feat` is pulled from `origin`, the default branch is merged into it and `feat` is pushed so that `origin/feat` equals the local `feat`

#### Scenario: Rebase mode
- **WHEN** `jef sync -r -y` is run and `feat` is behind the default branch
- **THEN** `feat` is rebased onto the default branch and pushed with `--force-with-lease`, and `origin/feat` equals the local `feat`

#### Scenario: Local-only branch
- **WHEN** a local branch does not exist on `origin`
- **THEN** the default branch is merged (or rebased) into it locally, nothing is pulled or pushed for it and the summary says "local only"

#### Scenario: Protected branch
- **WHEN** a local branch such as `dev` is listed in PROTECTED_BRANCHES
- **THEN** it is synced like any other branch

#### Scenario: Nothing to do
- **WHEN** every branch already contains the default branch and equals its `origin` branch
- **THEN** nothing is pushed, the summary says "up to date" and the repository counts as skipped

#### Scenario: Default branch not configured
- **WHEN** `DEFAULT_BRANCH` is empty
- **THEN** "DEFAULT_BRANCH is not set" is printed and the command exits 1

#### Scenario: Repository without the default branch
- **WHEN** a repository has no local default branch
- **THEN** it is listed as "no <default>, skipped", is not touched and counts as skipped

### Requirement: Stop a repository on conflict or failure
When a step fails in a repository (uncommitted changes, fetch, default branch not fast-forwarding, checkout, pull, merge, rebase or push), `jef sync` SHALL abort any merge or rebase in progress, stop that repository, record its remaining branches as "not attempted", count it as failed and continue with the others. It SHALL return each repository to the branch it started on where possible and exit 3 when any repository failed.

#### Scenario: Merge conflict
- **WHEN** merging the default branch into `feat` conflicts in `alpha`
- **THEN** the merge is aborted, `- feat (conflict while merging main; merge aborted, stopped)` is shown with git's `CONFLICT` line(s) indented beneath it, later branches of `alpha` are "not attempted", other repositories are still synced and the command exits 3

#### Scenario: Rebase conflict
- **WHEN** rebasing `feat` conflicts
- **THEN** the rebase is aborted, no rebase is left in progress and `feat` is unchanged

#### Scenario: Uncommitted changes
- **WHEN** a repository has uncommitted changes to tracked files (untracked files do not count)
- **THEN** it is failed with "uncommitted changes" and nothing in it is changed

#### Scenario: Default branch diverged
- **WHEN** the local default branch cannot be fast-forwarded to `origin`
- **THEN** the repository is failed with "diverged" and its branches are "not attempted"

#### Scenario: Original branch restored
- **WHEN** a repository was on `feat` when the run started
- **THEN** `feat` is checked out again at the end, also after a failure

### Requirement: Confirmation, plan and dry run
`jef sync` SHALL print a plan as a bulleted tree under "Will sync these branches (...):" and always ask "Sync N branches in M repositories by merging <default>? [y/N]" unless `-y`/`--yes` is given. Without a terminal and without `-y` it exits 2 ("Not running in a terminal. Re-run with --yes to sync. Nothing was synced."); any other answer than y/yes exits 1 ("Aborted. Nothing was synced."). `-n`/`--dry-run` prints the plan under "Would sync these branches (...)" and changes nothing.

#### Scenario: No terminal
- **WHEN** `jef sync` runs without `-y` and stdin is not a terminal
- **THEN** the not-a-terminal message is printed, nothing is changed and the command exits 2

#### Scenario: Declined
- **WHEN** the user answers n
- **THEN** "Aborted. Nothing was synced." is printed, nothing is changed and the command exits 1

#### Scenario: Dry run
- **WHEN** `jef sync -n` is run
- **THEN** the plan is printed under "Would sync these branches (merge <default> into each, then push where on origin):", nothing is asked or changed and the command exits 0

### Requirement: Repository selection and parallel jobs
`-m`/`--repo REPOS` (comma or space separated, repeatable) SHALL limit the run and the summary to the named repositories; an unknown name SHALL exit 2 before any change. `-j`/`--jobs N` SHALL cap the number of repositories processed at once; without it all selected repositories run at once. `-c`/`--clear-proxy` SHALL clear proxy variables before any git command contacts a remote.

#### Scenario: Only named repositories
- **WHEN** `jef sync -y -m alpha` is run
- **THEN** only `alpha` is synced and summarised

#### Scenario: Unknown repository
- **WHEN** `-m alpha,nosuch` is given
- **THEN** `nosuch` is reported as unknown and the command exits 2

#### Scenario: Jobs
- **WHEN** `-j 1` is given
- **THEN** repositories are processed one at a time with the same results as the default

### Requirement: Quiet run and result tree
While syncing, `jef sync` SHALL NOT print git's output; the relevant lines (up to 5, CONFLICT first) of a failing step are shown under the failed branch. It SHALL then print "Synced branches:" with a Total line (synced, up to date, failed, not attempted), one block per repository with "- <branch> (<outcome>)" lines, default branch first, coloured by outcome (green synced, yellow up to date or local only, red failed, dim not attempted), and the usual Summary line.

#### Scenario: Result lines
- **WHEN** `jef sync -y` syncs `feat` in `alpha`
- **THEN** `alpha` lists `- main (up to date)` and `- feat (merged 1 commit from main, pushed)`, and no "Working directory" or git progress lines are printed

#### Scenario: Conflict detail
- **WHEN** merging conflicts in `c.txt`
- **THEN** the failed branch line is followed by an indented `CONFLICT (...): Merge conflict in c.txt` line

### Requirement: Listed by the dispatcher
The `jef` command list SHALL include `sync` with its description.

#### Scenario: Command list
- **WHEN** `jef help` is run
- **THEN** `sync` is listed with its description
