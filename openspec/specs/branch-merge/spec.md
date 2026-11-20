# branch-merge Specification

## Purpose
Merging one branch into another across all repositories (`scrippy merge <source> <target>`).

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
