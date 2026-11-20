# branch-pull Specification

## Purpose
Pulling a branch across all repositories that have it on origin (`jef pull <branch>`).

## Requirements
### Requirement: Pull where remote branch exists
The system SHALL, in each repository where the branch exists on `origin`, fetch with prune, check out the branch, and pull it; repositories without the remote branch are skipped.

#### Scenario: Pull
- **WHEN** `origin` has `develop` in repository `api`
- **THEN** `api` is fetched, switched to `develop`, and pulled

#### Scenario: No remote branch
- **WHEN** `origin` lacks the branch
- **THEN** the repository is skipped without output

#### Scenario: Cannot checkout
- **WHEN** checkout of the branch fails
- **THEN** a "Could not checkout" message is printed and no pull happens in that repository
