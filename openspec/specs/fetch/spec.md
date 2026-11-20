# fetch Specification

## Purpose
Fetching all remotes across all repositories (`jef fetch`).

## Requirements

### Requirement: Fetch and prune everywhere
The system SHALL run `git fetch --all --prune` in every repository in the target directory, printing each repository name before its fetch.

#### Scenario: Fetch
- **WHEN** the user runs `jef fetch`
- **THEN** every non-skipped repository is fetched with pruning
