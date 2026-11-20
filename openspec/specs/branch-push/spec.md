# branch-push Specification

## Purpose
Pushing a local branch to origin across all repositories (`jef push <branch>`).

## Requirements

### Requirement: Push where local branch exists
The system SHALL, in each repository where the branch exists locally, check out the branch and run `git push -u origin <branch>`; repositories without the local branch are skipped.

#### Scenario: Push
- **WHEN** repository `api` has local `feature-x`
- **THEN** `api` is switched to `feature-x` and pushed with upstream tracking

#### Scenario: Cannot checkout
- **WHEN** checkout of the branch fails
- **THEN** a "Could not checkout" message is printed and nothing is pushed for that repository

### Requirement: Dry run
`jef push` SHALL accept `-n`/`--dry-run`: in each repository that has the branch locally it prints "Would push <branch> to origin", runs no mutating git command (no checkout or push), counts it as done in the summary and shows "Dry run: true" in the banner.

#### Scenario: Dry run
- **WHEN** the user runs `jef push -n feature-x`
- **THEN** "Would push feature-x to origin" is printed and origin does not receive the branch
