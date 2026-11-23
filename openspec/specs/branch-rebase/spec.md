# branch-rebase Specification

## Purpose
Rebasing one branch onto another across all repositories that have both (`jef rebase [-p] [-n] [-y] <branch> <onto>`).

## Requirements

### Requirement: Rebase where both branches exist
`jef rebase <branch> <onto_branch>` SHALL, in each repository where both branches exist locally, check out `<branch>` and run `git rebase <onto_branch>`, leaving `<branch>` checked out. Repositories where either branch is missing SHALL be skipped without output. Nothing is fetched. Both names SHALL be valid branch names (else exit 2).

#### Scenario: Rebase
- **WHEN** a repository has local `feature-x` and `develop`, and `develop` has commits that `feature-x` lacks
- **THEN** it checks out `feature-x`, runs `git rebase develop`, and `feature-x` then contains `develop`

#### Scenario: Missing branch
- **WHEN** a repository lacks either branch locally
- **THEN** it is skipped without output

#### Scenario: Already up to date
- **WHEN** `<onto_branch>` is already an ancestor of `<branch>`
- **THEN** the repository is reported as already up to date, nothing is checked out or changed, and it counts as skipped

#### Scenario: Cannot checkout
- **WHEN** checking out `<branch>` fails
- **THEN** "Could not checkout to <branch>. skipping..." is printed and the repository counts as failed

### Requirement: Plan
Before changing anything `jef rebase` SHALL print "Will rebase '<branch>' onto '<onto_branch>':" (mentioning the force-push with `-p`) with one line per repository that has both branches: "N commits" to replay, or "already up to date".

#### Scenario: Plan lines
- **WHEN** one repository needs 3 commits replayed and another is up to date
- **THEN** the plan shows "alpha: 3 commits" and "beta: already up to date"

### Requirement: Confirmation
`jef rebase` SHALL ask "Rebase '<branch>' onto '<onto_branch>' in N repositories? [y/N]" after the plan. `-y`/`--yes` SHALL skip the question. Any answer but `y`/`yes` SHALL print "Aborted. Nothing was rebased." and exit 1. Without a terminal and without `--yes` it SHALL print "Not running in a terminal. Re-run with --yes to rebase. Nothing was rebased." and exit 2. No question SHALL be asked when no repository needs a rebase, or with `--dry-run`.

#### Scenario: Declined
- **WHEN** the user answers `n`
- **THEN** nothing changes and the exit status is 1

#### Scenario: No terminal
- **WHEN** stdin is not a terminal and `--yes` is not given
- **THEN** nothing changes and the exit status is 2

### Requirement: Failed rebase
When `git rebase` fails, `jef rebase` SHALL run `git rebase --abort` only if a rebase is in progress, print that the rebase failed and was aborted, mark the repository failed and continue with the other repositories. The exit status SHALL be 3 if any repository failed.

#### Scenario: Conflict
- **WHEN** replaying the commits conflicts
- **THEN** the rebase is aborted, the branch is unchanged, no rebase is in progress and the exit status is 3

#### Scenario: Dirty working tree
- **WHEN** git refuses to rebase because of uncommitted changes
- **THEN** the repository counts as failed, nothing is aborted and the changes are kept

### Requirement: Push after rebase
With `-p`/`--push`, `jef rebase` SHALL run `git push --force-with-lease origin <branch>` after a successful rebase that rewrote commits. A repository that was already up to date SHALL NOT be pushed. A failed push SHALL mark the repository failed.

#### Scenario: Push
- **WHEN** a rebase succeeds with `-p`
- **THEN** origin's `<branch>` equals the local branch

#### Scenario: Push fails
- **WHEN** origin's branch has commits the local remote-tracking ref does not know
- **THEN** the push is refused and the repository counts as failed

### Requirement: Dry run
`jef rebase` SHALL accept `-n`/`--dry-run`: in each repository that would be rebased it prints "Would rebase <branch> onto <onto_branch> (N commits)" and, with `-p`, "Would force-push <branch> to origin", runs no mutating git command, counts it as done, and shows "Dry run: true" in the banner. It wins over `--yes`.

#### Scenario: Dry run
- **WHEN** the user runs `jef rebase -n -y feature-x develop`
- **THEN** "Would rebase feature-x onto develop (N commits)" is printed and no branch, working tree or remote changes

### Requirement: Summary
`jef rebase` SHALL count a repository as done when it was (or, in a dry run, would be) rebased, skipped when it lacks a branch or is up to date, and failed on a checkout, rebase or push failure.

#### Scenario: Mixed run
- **WHEN** one repository is rebased, one conflicts and one lacks the branch
- **THEN** the summary reads "1 done, 1 failed, 1 skipped"

### Requirement: Branch absent from every repository
When a branch named on the command line exists locally (`refs/heads/<name>`) in none of the target repositories, `jef rebase` SHALL print "Branch '<name>' does not exist in any repository" once for each such name and exit 2, before changing anything, printing a plan or asking for confirmation. This SHALL also apply with `--dry-run`, `--yes` and without a terminal. A branch that exists in only some repositories SHALL NOT cause an error: the repositories lacking it are skipped silently.

#### Scenario: One branch missing everywhere
- **WHEN** `jef rebase feat nosuch` is run and no repository has local branch `nosuch`
- **THEN** "Branch 'nosuch' does not exist in any repository" is printed, the command exits 2 and no repository is changed

#### Scenario: Both branches missing everywhere
- **WHEN** neither named branch exists in any repository
- **THEN** one line is printed for each name and the command exits 2

#### Scenario: Dry run
- **WHEN** `jef rebase -n feat nosuch` is run and `nosuch` exists nowhere
- **THEN** the same message is printed and the command exits 2

#### Scenario: No confirmation is asked
- **WHEN** `jef rebase -y feat nosuch` or a run without a terminal names a branch that exists nowhere
- **THEN** the message is printed, no "[y/N]" prompt appears and the command exits 2

#### Scenario: Branch present in some repositories only
- **WHEN** both branches exist in `alpha` but `beta` lacks one of them
- **THEN** no error is raised and `beta` is skipped silently
