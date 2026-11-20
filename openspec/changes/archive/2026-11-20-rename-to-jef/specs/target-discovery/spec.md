## MODIFIED Requirements

### Requirement: Configuration from .env
The system SHALL load environment variables from a `.env` file located in the jef installation root when that file exists, and SHALL continue without error when it does not.

#### Scenario: .env present
- **WHEN** a `.env` file exists in the installation root
- **THEN** its variables (`TARGET_DIR`, `DEFAULT_BRANCH`, `SKIP_DIRS`) are exported for the command

#### Scenario: .env absent
- **WHEN** no `.env` file exists
- **THEN** the command proceeds using only flags and the existing environment

### Requirement: Argument count validation
Commands that take positional arguments SHALL exit with a message stating the required and provided counts when the number of positional arguments is wrong.

#### Scenario: Missing branch argument
- **WHEN** the user runs `jef checkout` with no branch
- **THEN** "1 argument required. 0 provided" is printed and nothing else runs
