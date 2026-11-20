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

### Requirement: Parallel lookup
`jef find` SHALL accept `-j N` / `--jobs N` where N is a positive integer (default 1) and look up up to N repositories concurrently. The table rows SHALL be in the normal repository order and the output SHALL equal that with N of 1. The spinner SHALL keep running while lookups are in flight. An N that is not a positive integer, or a missing value, SHALL be a usage error with exit status 2.

#### Scenario: Ordered table
- **WHEN** the user runs `jef find -j 4 feature-x`
- **THEN** the table is identical to the one printed without `-j`

#### Scenario: Invalid job count
- **WHEN** the user runs `jef find -j abc feature-x`
- **THEN** a usage error is printed and the exit status is 2
