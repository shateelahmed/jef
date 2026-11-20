## ADDED Requirements

### Requirement: Parallel fetch
`jef fetch` SHALL accept `-j N` / `--jobs N` where N is a positive integer (default 1) and fetch up to N repositories concurrently. The per-repository output SHALL be printed in the normal repository order regardless of completion order, followed by the usual summary, and the exit status SHALL be 3 if any repository failed. With N of 1 the output SHALL be unchanged. An N that is not a positive integer, or a missing value, SHALL be a usage error with exit status 2.

#### Scenario: Ordered output
- **WHEN** the user runs `jef fetch -j 4`
- **THEN** the output equals that of `jef fetch` and the summary counts every repository

#### Scenario: Invalid job count
- **WHEN** the user runs `jef fetch -j 0`
- **THEN** a usage error is printed and the exit status is 2

#### Scenario: One repository fails
- **WHEN** one repository's origin is unreachable and the user runs `jef fetch -j 2`
- **THEN** the summary reports one failure and the exit status is 3
