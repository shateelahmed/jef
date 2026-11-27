## MODIFIED Requirements
### Requirement: Choose repositories without the picker
`-m`/`--repo REPOS` (comma or space separated, repeatable) SHALL limit `jef checkout` to the named repositories, with or without `-b`. With `-b` it SHALL select those repositories without showing the picker; named repositories that are unavailable SHALL be reported with the reason and counted as skipped. Without `-b` the branch SHALL be checked out only in the named repositories that have it.

#### Scenario: Repositories named on the command line
- **WHEN** `jef checkout -b feat main -m alpha,beta` is run
- **THEN** `feat` is created and checked out in `alpha` and `beta` only, and no picker is shown

#### Scenario: -m without -b
- **WHEN** `jef checkout -m alpha feat` is run and `alpha` and `beta` both have `feat`
- **THEN** `feat` is checked out in `alpha` only

