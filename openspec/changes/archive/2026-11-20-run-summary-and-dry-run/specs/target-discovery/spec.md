## ADDED Requirements

### Requirement: End-of-run summary
The checkout, delete, fetch, merge, pull and push commands SHALL print one line "Summary: X done, Y failed, Z skipped" after visiting all repositories; `find` and `which` SHALL NOT. Colour SHALL come only from the standard colour variables, so the line is plain when output is not a terminal.

#### Scenario: Outcome meanings
- **WHEN** a repository's git operation succeeds (or, with `--dry-run`, would be performed)
- **THEN** it counts as done; a failed git command or failed checkout counts as failed; a repository where the operation does not apply (for example the branch is absent) counts as skipped

#### Scenario: Mixed outcome
- **WHEN** `jef push feat` runs over three repositories and only one has `feat`
- **THEN** the last line is "Summary: 1 done, 0 failed, 2 skipped"

### Requirement: Failure exit status
The commands that print a summary SHALL exit with status 3 when at least one repository failed, and with status 0 otherwise. Statuses 1 (target directory problem), 2 (usage error) and 127 (unknown command) are unchanged.

#### Scenario: Repository failure
- **WHEN** a merge conflicts in one repository
- **THEN** the summary reports 1 failed and the exit status is 3

#### Scenario: Nothing failed
- **WHEN** every visited repository is done or skipped
- **THEN** the exit status is 0
