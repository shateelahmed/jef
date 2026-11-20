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
