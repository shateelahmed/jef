## ADDED Requirements

### Requirement: Parallel lookup
`jef find` SHALL accept `-j N` / `--jobs N` where N is a positive integer (default 1) and look up up to N repositories concurrently. The table rows SHALL be in the normal repository order and the output SHALL equal that with N of 1. The spinner SHALL keep running while lookups are in flight. An N that is not a positive integer, or a missing value, SHALL be a usage error with exit status 2.

#### Scenario: Ordered table
- **WHEN** the user runs `jef find -j 4 feature-x`
- **THEN** the table is identical to the one printed without `-j`

#### Scenario: Invalid job count
- **WHEN** the user runs `jef find -j abc feature-x`
- **THEN** a usage error is printed and the exit status is 2
