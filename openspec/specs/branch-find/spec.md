# branch-find Specification

## Purpose
Reporting where a branch exists, locally and on origin, across all repositories (`jef find <branch>`).

## Requirements
### Requirement: Existence table
The system SHALL print a bordered table with one row per repository showing a green ✔ or red ✘ for whether the branch exists locally and on `origin`, with column widths sized to the content.

#### Scenario: Mixed presence
- **WHEN** `api` has `feature-x` locally only and `web` has it locally and remotely
- **THEN** the table shows `api` ✔/✘ and `web` ✔/✔

### Requirement: Progress indicator
The system SHALL show a spinner while collecting data and remove it before printing the table.

#### Scenario: Spinner
- **WHEN** remote lookups are in progress
- **THEN** a spinner is shown and is cleared before the table appears
