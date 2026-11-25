# branch-merge Specification

## Purpose
Merging one branch into another across all repositories (`jef merge <source> <target>`).

## Requirements

### Requirement: Merge where both branches exist
The system SHALL, in each repository where both branches exist locally, check out the target branch and merge the source branch into it, skipping repositories where either branch is missing.

#### Scenario: Merge
- **WHEN** a repository has local `feature-x` and `develop`
- **THEN** it checks out `develop` and runs `git merge feature-x`

#### Scenario: Missing branch
- **WHEN** a repository lacks either branch locally
- **THEN** it is skipped without output

#### Scenario: Cannot checkout target
- **WHEN** checking out the target branch fails
- **THEN** a "Could not checkout" message is printed and the repository is skipped

### Requirement: Dry run
`jef merge` SHALL accept `-n`/`--dry-run`: in each repository that has both branches it prints "Would merge <source> into <target>", runs no mutating git command (no checkout or merge), counts it as done in the summary and shows "Dry run: true" in the banner.

#### Scenario: Dry run
- **WHEN** the user runs `jef merge -n feature-x develop`
- **THEN** "Would merge feature-x into develop" is printed and no branch or working tree changes

### Requirement: Branch absent from every repository
When a branch named on the command line exists locally (`refs/heads/<name>`) in none of the target repositories, `jef merge` SHALL print "Branch '<name>' does not exist in any repository" once for each such name and exit 2, before changing anything, printing a plan. This SHALL also apply with `--dry-run` and without a terminal. A branch that exists in only some repositories SHALL NOT cause an error: the repositories lacking it are skipped silently.

#### Scenario: One branch missing everywhere
- **WHEN** `jef merge feat nosuch` is run and no repository has local branch `nosuch`
- **THEN** "Branch 'nosuch' does not exist in any repository" is printed, the command exits 2 and no repository is changed

#### Scenario: Both branches missing everywhere
- **WHEN** neither named branch exists in any repository
- **THEN** one line is printed for each name and the command exits 2

#### Scenario: Dry run
- **WHEN** `jef merge -n feat nosuch` is run and `nosuch` exists nowhere
- **THEN** the same message is printed and the command exits 2

#### Scenario: Branch present in some repositories only
- **WHEN** both branches exist in `alpha` but `beta` lacks one of them
- **THEN** no error is raised and `beta` is skipped silently

### Requirement: Abort merges in progress
`jef merge --abort` SHALL run `git merge --abort` in every repository where a merge is in progress (`MERGE_HEAD` exists), print "Aborted the merge" under its "Working directory" header and count it as done. Other repositories SHALL be skipped without output; when none has a merge in progress it SHALL print "No merge in progress" and exit 0. No confirmation is asked. The banner SHALL show the target directory, "Action: abort" and "Dry run".

#### Scenario: Merge aborted
- **WHEN** `alpha` has a conflicted merge in progress, `beta` has none, and `jef merge --abort` is run
- **THEN** `alpha` prints "Aborted the merge", no merge is in progress in `alpha`, its working tree is as before the merge, `beta` is not mentioned and the command exits 0

#### Scenario: Nothing to abort
- **WHEN** no repository has a merge in progress
- **THEN** "No merge in progress" is printed and the command exits 0

### Requirement: Abort dry run
With `-n`/`--dry-run`, `jef merge --abort` SHALL print "Would abort the merge" in each repository with a merge in progress and change nothing.

#### Scenario: Abort dry run
- **WHEN** `jef merge --abort -n` is run and `alpha` has a merge in progress
- **THEN** "Would abort the merge" is printed and the merge is still in progress

### Requirement: Abort failure
When `git merge --abort` fails, `jef merge --abort` SHALL print "Could not abort the merge", count the repository as failed, continue with the others and exit 3.

#### Scenario: Abort fails
- **WHEN** `git merge --abort` fails in `alpha`
- **THEN** "Could not abort the merge" is printed, the other repositories are processed and the exit status is 3

### Requirement: Abort arguments
`jef merge --abort` SHALL take no positional arguments: any branch argument with `--abort` SHALL be a usage error (exit 2). Without `--abort`, `jef merge` keeps requiring exactly two branch arguments.

#### Scenario: Branches with --abort
- **WHEN** `jef merge --abort feat main` is run
- **THEN** a usage error is printed and the command exits 2, changing nothing
