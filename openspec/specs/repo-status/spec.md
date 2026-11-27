# repo-status Specification

## Purpose
Showing each repository's branch, position against origin, local changes, stashes and operation in progress in one table (`jef status`).

## Requirements

### Requirement: Status table
`jef status` SHALL print, after a banner (target directory, repositories, fetch, clear proxy), a header row and one row per repository with the columns Repository, Branch, Origin, Changes, Stashes and State, aligned to the widest value of each column. It SHALL change nothing in any repository and take no arguments.

#### Scenario: Clean repository
- **WHEN** `alpha` is on `main`, equal to `origin/main`, with no changes, stashes or operation in progress
- **THEN** its row shows `alpha`, `main`, `up to date`, `clean`, `-` and an empty State

#### Scenario: Skipped directories
- **WHEN** a directory is in `SKIP_DIRS` or is not a git repository
- **THEN** it has no row

### Requirement: Origin position
The Origin column SHALL compare the current branch with `origin/<branch>` using the local remote-tracking refs: `up to date`, `ahead N`, `behind N` or `ahead N, behind M`; `not on origin` when `refs/remotes/origin/<branch>` does not exist; `-` when HEAD is detached, in which case Branch shows `(detached <short sha>)`.

#### Scenario: Ahead and behind
- **WHEN** `alpha`'s `feat` has 2 commits that `origin/feat` lacks and `origin/feat` has 1 that `feat` lacks
- **THEN** its Origin is `ahead 2, behind 1`

#### Scenario: Local-only branch
- **WHEN** the current branch does not exist on origin
- **THEN** its Origin is `not on origin`

#### Scenario: Detached HEAD
- **WHEN** HEAD is detached
- **THEN** Branch shows `(detached <short sha>)` and Origin `-`

### Requirement: Local changes, stashes and operations
The Changes column SHALL be `clean` or a comma-separated list of the non-zero counts `N conflicted`, `N changed`, `N untracked`, in that order, taken from `git status --porcelain`. The Stashes column SHALL be the number of stash entries, or `-` for none. The State column SHALL be `merging`, `rebasing`, `cherry-picking` or `reverting` when that operation is in progress, and empty otherwise.

#### Scenario: Modified and untracked files
- **WHEN** `alpha` has 2 modified tracked files and 1 untracked file
- **THEN** its Changes is `2 changed, 1 untracked`

#### Scenario: Conflicted merge
- **WHEN** `alpha` has a merge in progress with one conflicted file
- **THEN** its Changes starts with `1 conflicted` and its State is `merging`

#### Scenario: Stashes
- **WHEN** `alpha` has 2 stash entries
- **THEN** its Stashes is `2`

### Requirement: Status totals
After the table `jef status` SHALL print "Total: N repositories, A with changes, B not up to date, C in progress" ("1 repository" when N is 1), where "with changes" counts rows whose Changes is not `clean`, "not up to date" counts rows whose Origin is anything but `up to date`, and "in progress" counts rows with a State. It SHALL exit 0 unless a fetch failed.

#### Scenario: Totals
- **WHEN** of 3 repositories one has changes and another is ahead of origin
- **THEN** "Total: 3 repositories, 1 with changes, 1 not up to date, 0 in progress" is printed and the exit status is 0

### Requirement: Status fetch
Without `-f`/`--fetch`, `jef status` SHALL NOT contact any remote. With it, each repository SHALL run `git fetch --prune origin` before its row is computed; a failed fetch SHALL show `fetch failed` in red in its Origin column (the row is still computed from the existing refs otherwise) and make the command exit 3. `-c`/`--clear-proxy` SHALL unset proxy variables first.

#### Scenario: Fetch shows new remote commits
- **WHEN** `origin/main` gained a commit since the last fetch and `jef status -f` is run
- **THEN** `alpha`'s Origin is `behind 1`, whereas without `-f` it would be `up to date`

#### Scenario: Fetch fails
- **WHEN** `alpha`'s origin is unreachable and `-f` is given
- **THEN** `alpha`'s Origin is `fetch failed`, the other rows are shown and the exit status is 3

### Requirement: Status repository filter
`-m`/`--repo REPOS` (comma or space separated, repeatable) SHALL limit the table and the totals to the named repositories; an unknown name SHALL be a usage error (exit 2).

#### Scenario: Filter
- **WHEN** `jef status -m alpha` is run
- **THEN** only `alpha` has a row and the total counts 1 repository

#### Scenario: Unknown repository
- **WHEN** `jef status -m nosuch` is run
- **THEN** a usage error is printed and the command exits 2
