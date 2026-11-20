## MODIFIED Requirements

### Requirement: Configuration from .env
The system SHALL load environment variables from a `.env` file located in the jef installation root when that file exists, and SHALL continue without error when it does not. The file SHALL be read as data and never executed: each non-blank, non-comment line of the form `KEY=VALUE` defines a variable, one pair of surrounding single or double quotes around the value is removed, surrounding whitespace is trimmed, and only keys made of letters, digits and underscores (not starting with a digit) are accepted. Other lines are ignored. A value that is `~`, `$HOME` or `${HOME}`, or starts with one of them followed by `/`, SHALL have that leading part replaced by the value of `HOME`; no other expansion (other variables, `~user`, command substitution) is performed.

#### Scenario: .env present
- **WHEN** a `.env` file exists in the installation root
- **THEN** its variables (`TARGET_DIR`, `DEFAULT_BRANCH`, `SKIP_DIRS`) are exported for the command

#### Scenario: .env absent
- **WHEN** no `.env` file exists
- **THEN** the command proceeds using only flags and the existing environment

#### Scenario: Unquoted value with spaces
- **WHEN** `.env` contains `SKIP_DIRS=archived, playground` without quotes
- **THEN** `SKIP_DIRS` is `archived, playground` and no command named `playground` is run

#### Scenario: Quoted value
- **WHEN** `.env` contains `SKIP_DIRS="archived, playground"` or the same value in single quotes
- **THEN** `SKIP_DIRS` is `archived, playground`

#### Scenario: Comments, blank lines and invalid keys
- **WHEN** `.env` contains blank lines, `# comment` lines, and lines whose key is not a valid variable name
- **THEN** those lines are ignored and nothing in them is executed

#### Scenario: Leading home reference expands
- **WHEN** `.env` contains `TARGET_DIR=~/code`, `TARGET_DIR=$HOME/code` or `TARGET_DIR=${HOME}/code`
- **THEN** `TARGET_DIR` is the value of `HOME` followed by `/code`

#### Scenario: Nothing else expands
- **WHEN** `.env` contains `TARGET_DIR=~other/code`, `TARGET_DIR=$HOMEDIR/code`, `TARGET_DIR=/x/$HOME` or `TARGET_DIR=$(echo /x)`
- **THEN** the value is kept literally

## ADDED Requirements

### Requirement: Colour output only on a terminal
The system SHALL emit colour escape codes only when standard output is a terminal, `NO_COLOR` is unset or empty, and the terminal's colour capabilities can be queried. Otherwise it SHALL print plain text. The progress spinner SHALL draw and clear only on a terminal. Output of `jef find` and `jef which` piped or redirected to a file SHALL contain no escape sequences.

#### Scenario: Piped output is plain
- **WHEN** `jef which` or `jef find <branch>` output is piped to another program
- **THEN** it contains no escape characters

#### Scenario: NO_COLOR set
- **WHEN** `NO_COLOR` is set to a non-empty value
- **THEN** no colour codes are printed even on a terminal

#### Scenario: Colour tool unavailable
- **WHEN** `tput` is missing or fails
- **THEN** the command runs normally with plain text

### Requirement: Command location independent of symlinks
The system SHALL locate its installation root from the real location of the running command, following symlinks (absolute or relative, including chains), without relying on `realpath`, so that a command symlinked into `PATH` works on macOS and Linux.

#### Scenario: Symlinked command
- **WHEN** a jef command is invoked through a symlink to the installed script
- **THEN** it finds its libraries and `.env` in the installation root
