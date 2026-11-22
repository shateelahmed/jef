## MODIFIED Requirements

### Requirement: Skipping directories
The system SHALL skip any child directory whose name matches an entry in `SKIP_DIRS`, a comma separated list, in every command. Whitespace around entries is ignored and empty entries are skipped. An entry containing whitespace SHALL be an error: the command prints `Invalid SKIP_DIRS: '<entry>' contains spaces; separate entries with commas` to stderr and exits 2 before touching any repository, except that `--help` still exits 0.

#### Scenario: Comma and space separated list
- **WHEN** `SKIP_DIRS="archived, playground"` and the target contains `archived`, `playground` and `api`
- **THEN** only `api` is considered

#### Scenario: Space separated list rejected
- **WHEN** `SKIP_DIRS="archived playground"`
- **THEN** the command exits 2 with the invalid-entry message and no repository is touched

#### Scenario: Help with invalid value
- **WHEN** `SKIP_DIRS="a b"` and the user runs a command with `--help`
- **THEN** the usage is printed and the exit status is 0

#### Scenario: Empty SKIP_DIRS
- **WHEN** `SKIP_DIRS` is empty or unset
- **THEN** no directory is skipped
