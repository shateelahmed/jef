# target-discovery Specification

## Purpose
Shared behaviour every jef command uses to decide which repositories to operate on: configuration loading, target directory resolution, child-directory iteration, directory skipping, and optional proxy clearing.

## Requirements

### Requirement: Configuration from .env
The system SHALL load environment variables from a `.env` file located in the jef installation root when that file exists, and SHALL continue without error when it does not.

#### Scenario: .env present
- **WHEN** a `.env` file exists in the installation root
- **THEN** its variables (`TARGET_DIR`, `DEFAULT_BRANCH`, `SKIP_DIRS`) are exported for the command

#### Scenario: .env absent
- **WHEN** no `.env` file exists
- **THEN** the command proceeds using only flags and the existing environment

### Requirement: Target directory resolution
The system SHALL use the directory given by `-d`/`--directory` as the target directory, falling back to `TARGET_DIR`, and SHALL exit with an explanatory message when neither is set or the path is not a directory.

#### Scenario: Flag overrides env
- **WHEN** `TARGET_DIR` is set and the user passes `--directory /other`
- **THEN** `/other` is used as the target directory

#### Scenario: No target configured
- **WHEN** neither `-d` nor `TARGET_DIR` is provided
- **THEN** the command prints that the target directory is not set and exits without touching any repository

#### Scenario: Invalid target
- **WHEN** the resolved target path is not an existing directory
- **THEN** the command prints that it is not a valid directory and exits

### Requirement: First-level git repositories only
The system SHALL operate only on immediate child directories of the target directory that contain a `.git` directory, and SHALL silently ignore other children.

#### Scenario: Non-repo child
- **WHEN** a child directory has no `.git` directory
- **THEN** it is skipped without output

#### Scenario: Nested repositories
- **WHEN** a git repository exists two or more levels below the target directory
- **THEN** it is not operated on

### Requirement: Skipping directories
The system SHALL skip any child directory whose name matches an entry in `SKIP_DIRS`, a comma and/or whitespace separated list, in every command.

#### Scenario: Comma and space separated list
- **WHEN** `SKIP_DIRS="archived, playground"` and the target contains `archived`, `playground` and `api`
- **THEN** only `api` is considered

#### Scenario: Empty SKIP_DIRS
- **WHEN** `SKIP_DIRS` is empty or unset
- **THEN** no directory is skipped

### Requirement: Optional proxy clearing
Commands that contact a remote SHALL accept `-c`/`--clear-proxy`, and when given SHALL unset `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY` (upper and lower case) before running git and print "Cleared proxy".

#### Scenario: Proxy cleared
- **WHEN** the user runs a remote-contacting command with `--clear-proxy`
- **THEN** proxy variables are unset for that run and "Cleared proxy" is printed

### Requirement: Argument count validation
Commands that take positional arguments SHALL exit with a message stating the required and provided counts when the number of positional arguments is wrong.

#### Scenario: Missing branch argument
- **WHEN** the user runs `jef checkout` with no branch
- **THEN** "1 argument required. 0 provided" is printed and nothing else runs
