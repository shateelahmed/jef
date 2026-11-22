## MODIFIED Requirements

### Requirement: Push where local branch exists
In each repository where the branch exists locally, the system SHALL ask origin for the branch tip and push only when there is something to push, checking out the branch first. Up-to-date or behind branches are skipped without checkout; unreachable origin fails the repository; repositories without the local branch are skipped.

#### Scenario: Push
- **WHEN** repository `api` has local `feature-x` with commits origin lacks
- **THEN** "Pushing N commits" is printed and `api` is switched to `feature-x` and pushed with upstream tracking

#### Scenario: Cannot checkout
- **WHEN** checkout of the branch fails
- **THEN** a "Could not checkout" message is printed and nothing is pushed for that repository

#### Scenario: New branch
- **WHEN** origin does not have the branch
- **THEN** the branch is pushed

#### Scenario: Up to date
- **WHEN** origin's tip equals the local tip
- **THEN** "Nothing to push" is printed, the repository is skipped, nothing is checked out or pushed, and missing upstream tracking is set when origin/<branch> exists

#### Scenario: Behind origin
- **WHEN** the local tip is an ancestor of origin's tip
- **THEN** "Nothing to push (behind origin)" is printed and the repository is skipped

#### Scenario: Diverged
- **WHEN** neither tip is an ancestor of the other, or origin's tip is unknown locally
- **THEN** the push is attempted and a rejection fails the repository

#### Scenario: Origin unreachable
- **WHEN** asking origin for the branch fails
- **THEN** "Could not reach origin" is printed and the repository fails without checkout or push

### Requirement: Dry run
`jef push` SHALL accept `-n`/`--dry-run`: it checks origin read-only and, per repository with the branch locally, prints "Would push <branch> to origin" (plus the commit count when known; counted done) or "Nothing to push" (skipped), runs no mutating git command, and shows "Dry run: true" in the banner.

#### Scenario: Dry run
- **WHEN** the user runs `jef push -n feature-x`
- **THEN** "Would push feature-x to origin" is printed and origin does not receive the branch

#### Scenario: Dry run with nothing to push
- **WHEN** the branch is up to date or behind origin
- **THEN** "Nothing to push" is printed and the repository is skipped
