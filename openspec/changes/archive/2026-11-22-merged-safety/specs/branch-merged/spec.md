## ADDED Requirements

### Requirement: Protected branches
Branches matching `PROTECTED_BRANCHES` (comma or space separated names or glob patterns, from `.env`) SHALL never be listed or deleted, locally or on origin. The default branch and origin's HEAD branch SHALL always be protected. The patterns SHALL NOT be expanded against files. The banner SHALL show `Protected: <list>` or `Protected: default branch only`.

#### Scenario: Names and patterns
- **WHEN** `PROTECTED_BRANCHES="dev, release/*"` and a repository has merged branches `dev`, `release/1.0` and `feat`
- **THEN** only `feat` is listed and deleted

#### Scenario: No expansion
- **WHEN** `PROTECTED_BRANCHES=qa*` and the current directory contains a file `qa-file`
- **THEN** a branch `qa-two` is still protected

### Requirement: Branches without own commits
A merged branch whose tip is on the first-parent history of the base SHALL be listed with the note `(no commits, kept)` and SHALL NOT be deleted, unless `--delete` is combined with the long-only flag `--include-empty`. Only branches that are ancestors of the base SHALL be checked; squash and rebase merged branches are never empty.

#### Scenario: Empty branch kept
- **WHEN** branch `empty` was just created from the default branch and the user runs `jef merged -D -y`
- **THEN** it is shown as `(no commits, kept)` and not deleted

#### Scenario: Include empty
- **WHEN** the user runs `jef merged -D -y --include-empty`
- **THEN** the branch without commits is deleted too

#### Scenario: Squash merged
- **WHEN** a branch with its own commit was squash-merged
- **THEN** it is not treated as empty

### Requirement: Compare-and-delete
Deletion SHALL only remove a branch that still points at the commit recorded by the scan. Local branches SHALL be deleted with `git update-ref -d <ref> <sha>`; the remote branches of a repository with one `git push --delete` carrying `--force-with-lease=<ref>:<sha>` per branch, then `git ls-remote` SHALL tell which are gone. A moved branch SHALL be kept with the yellow note `(changed since scan, kept)` and not counted as failed.

#### Scenario: Pushed after the scan
- **WHEN** somebody pushes to origin branch `feat` after the scan and the user confirms
- **THEN** `origin/feat` is kept, marked `(changed since scan, kept)`, the other branches are deleted and the exit status is 0

#### Scenario: Local branch moved
- **WHEN** a local branch gets a new commit after the scan
- **THEN** it is kept and marked `(changed since scan, kept)`

## MODIFIED Requirements

### Requirement: Checked-out branch is kept
A merged branch that is checked out in any worktree (the main one or an added one) SHALL be listed with the note `(checked out, kept)` and SHALL NOT be deleted locally. The command SHALL NOT switch branches.

#### Scenario: Checked out
- **WHEN** a repository is on a merged branch `feat` and the user runs `jef merged -D -y`
- **THEN** `feat` is kept, still checked out, and the other merged branches are deleted

#### Scenario: Other worktree
- **WHEN** merged branch `feat` is checked out in a second worktree of the repository
- **THEN** it is marked `(checked out, kept)` and not deleted

### Requirement: Delete merged branches
`-D`/`--delete` SHALL print a plan and ask `Delete N branches in M repositories? [y/N]`, counting only branches that will be deleted (not kept ones). Only `y`, `Y` or `yes` SHALL proceed; else "Aborted. Nothing was deleted." and exit 1. Without a terminal and without `-y`: "Not running in a terminal. Re-run with --yes to delete. Nothing was deleted." and exit 2. Nothing deletable: no question.

#### Scenario: Deletion commands
- **WHEN** the deletion is confirmed
- **THEN** local branches are deleted with `git update-ref -d` and the remote branches of a repository with a single leased `git push origin --delete`, and a failed deletion marks the repository failed

#### Scenario: Declined
- **WHEN** the user answers `n`
- **THEN** nothing is deleted and the exit status is 1

#### Scenario: Accepted
- **WHEN** the user answers `y`
- **THEN** the merged local and remote branches are deleted and the usual summary is printed

#### Scenario: No terminal
- **WHEN** `jef merged -D` runs with stdin not a terminal and without `-y`
- **THEN** the exit status is 2 and nothing is deleted

#### Scenario: Yes flag
- **WHEN** the user runs `jef merged -D -y`
- **THEN** the plan is printed, no question is asked and the branches are deleted

#### Scenario: Scope respected
- **WHEN** the user runs `jef merged -D -l -y`
- **THEN** only local branches are deleted and origin is left untouched

#### Scenario: Count excludes kept branches
- **WHEN** one branch is deletable and another is kept
- **THEN** the question says `Delete 1 branch in 1 repository?`
