# branch-delete Specification

## Purpose
Deleting a branch locally, and optionally on origin, across all repositories (`scrippy delete [-r] <branch>`).

## Requirements
### Requirement: Delete local branch
The system SHALL force-delete the given local branch in each repository where it exists, first switching to `DEFAULT_BRANCH` if the branch is currently checked out.

#### Scenario: Branch checked out
- **WHEN** a repository is on `feature-x` and `DEFAULT_BRANCH=main`
- **THEN** it switches to `main` and deletes `feature-x`

#### Scenario: Cannot leave branch
- **WHEN** switching to the default branch fails
- **THEN** a message is printed, the local branch is kept, and the remote branch is not deleted for that repository

### Requirement: Optional remote deletion
When `-r`/`--delete-remote-branch` is given, the system SHALL delete the branch from `origin` where it exists, unless it is the remote's default (HEAD) branch.

#### Scenario: Remote deletion
- **WHEN** `origin` has `feature-x` and the user passes `-r`
- **THEN** `feature-x` is deleted from origin and "local & remote deleted" (or "remote deleted") is reported

#### Scenario: Protect remote default branch
- **WHEN** the branch to delete is origin's HEAD branch
- **THEN** it is not deleted and a message says it is the default branch

### Requirement: Not found report
The system SHALL print "Branch not found in any repository" when the branch exists in no repository.

#### Scenario: Nowhere
- **WHEN** no repository has the branch locally (or remotely with `-r`)
- **THEN** "Branch not found in any repository" is printed
