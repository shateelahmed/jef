## MODIFIED Requirements

### Requirement: Configuration from .env
The system SHALL load environment variables from a `.env` file located in the jef installation root when that file exists, and SHALL continue without error when it does not. The file SHALL be read as data and never executed: each non-blank, non-comment line of the form `KEY=VALUE` defines a variable, one pair of surrounding single or double quotes around the value is removed, surrounding whitespace is trimmed, and only keys made of letters, digits and underscores (not starting with a digit) are accepted. Other lines are ignored.

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

### Requirement: Target directory resolution
The system SHALL use the directory given by `-d`/`--directory` as the target directory, falling back to `TARGET_DIR`, and SHALL exit with status 1 and an explanatory message when neither is set or the path is not a directory. Target directory paths containing spaces or other shell-special characters SHALL work.

#### Scenario: Flag overrides env
- **WHEN** `TARGET_DIR` is set and the user passes `--directory /other`
- **THEN** `/other` is used as the target directory

#### Scenario: No target configured
- **WHEN** neither `-d` nor `TARGET_DIR` is provided
- **THEN** the command prints that the target directory is not set, exits with status 1 and does not touch any repository

#### Scenario: Invalid target
- **WHEN** the resolved target path is not an existing directory
- **THEN** the command prints that it is not a valid directory and exits with status 1

#### Scenario: Target directory containing a space
- **WHEN** the target directory is `/home/me/my work` and contains repositories
- **THEN** every command operates on those repositories

### Requirement: First-level git repositories only
The system SHALL operate only on immediate child directories of the target directory that contain a `.git` entry (a directory, or a file as in linked worktrees and submodules), and SHALL silently ignore other children. Child directory names containing spaces SHALL be handled correctly.

#### Scenario: Non-repo child
- **WHEN** a child directory has no `.git` entry
- **THEN** it is skipped without output

#### Scenario: Nested repositories
- **WHEN** a git repository exists two or more levels below the target directory
- **THEN** it is not operated on

#### Scenario: Linked worktree or submodule
- **WHEN** a child directory's `.git` is a file (a linked worktree or a submodule checkout)
- **THEN** it is treated as a repository

#### Scenario: Repository name with a space
- **WHEN** a child repository is named `repo one`
- **THEN** commands operate on it and show its full name

### Requirement: Argument count validation
Commands that take positional arguments SHALL exit with status 2 and a message stating the required and provided counts when the number of positional arguments is wrong, using the singular "argument" when exactly one is required. An unrecognised option SHALL also exit with status 2.

#### Scenario: Missing branch argument
- **WHEN** the user runs `jef checkout` with no branch
- **THEN** "1 argument required. 0 provided" is printed, nothing else runs and the exit status is 2

#### Scenario: Singular wording for push
- **WHEN** the user runs `jef push` with no branch
- **THEN** "1 argument required. 0 provided" is printed (not "1 arguments")

## ADDED Requirements

### Requirement: Branch names are treated as data
Commands that take branch names SHALL treat them as literal values: names are never word-split or glob-expanded, local-branch existence is checked against exactly `refs/heads/<name>`, and a name starting with `-` SHALL be rejected (exit status 2) so it is never interpreted as a git option.

#### Scenario: Local branch check is exact
- **WHEN** a repository has a branch `feature/x` and the user runs `jef checkout x`
- **THEN** that repository is not matched

#### Scenario: Branch name starting with a dash
- **WHEN** the user passes a branch name beginning with `-` (for example `jef checkout -- -x`)
- **THEN** the command prints that it is not a valid branch name, exits with status 2 and git is never invoked with the name
