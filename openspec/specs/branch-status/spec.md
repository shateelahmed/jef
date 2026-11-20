# branch-status Specification

## Purpose
Showing which branch each repository currently has checked out (`scrippy which`).

## Requirements
### Requirement: Current branch table
The system SHALL print a bordered table whose first row is the target directory (highlighted) followed by one row per repository with its current branch, column widths sized to content.

#### Scenario: Listing
- **WHEN** `api` is on `main` and `web` is on `develop`
- **THEN** the table shows the target directory row, then `api | main` and `web | develop`

#### Scenario: Skipped and non-repo directories
- **WHEN** a child is listed in `SKIP_DIRS` or is not a git repository
- **THEN** it does not appear in the table
