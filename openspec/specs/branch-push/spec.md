# branch-push Specification

## Purpose
Pushing a local branch to origin across all repositories (`scrippy push <branch>`).

## Requirements
### Requirement: Push where local branch exists
The system SHALL, in each repository where the branch exists locally, check out the branch and run `git push -u origin <branch>`; repositories without the local branch are skipped.

#### Scenario: Push
- **WHEN** repository `api` has local `feature-x`
- **THEN** `api` is switched to `feature-x` and pushed with upstream tracking

#### Scenario: Cannot checkout
- **WHEN** checkout of the branch fails
- **THEN** a "Could not checkout" message is printed and nothing is pushed for that repository
