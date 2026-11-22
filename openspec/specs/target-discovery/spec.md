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

### Requirement: .env is parsed as data
The system SHALL read `.env` as data and never execute it. Each non-blank, non-comment line of the form `KEY=VALUE` defines a variable. Surrounding whitespace is trimmed, and one pair of surrounding single or double quotes around the value is removed. Only keys made of letters, digits and underscores, not starting with a digit, are accepted; other lines are ignored.

#### Scenario: Unquoted value with spaces
- **WHEN** `.env` contains `SKIP_DIRS=archived, playground` without quotes
- **THEN** `SKIP_DIRS` is `archived, playground` and no command named `playground` is run

#### Scenario: Quoted value
- **WHEN** `.env` contains `SKIP_DIRS="archived, playground"` or the same value in single quotes
- **THEN** `SKIP_DIRS` is `archived, playground`

#### Scenario: Comments, blank lines and invalid keys
- **WHEN** `.env` contains blank lines, `# comment` lines, and lines whose key is not a valid variable name
- **THEN** those lines are ignored and nothing in them is executed

### Requirement: Home expansion in .env values
A `.env` value that is `~`, `$HOME` or `${HOME}`, or starts with one of them followed by `/`, SHALL have that leading part replaced by the value of `HOME`. No other expansion SHALL be performed: not other variables, not `~user`, and not command substitution.

#### Scenario: Leading home reference expands
- **WHEN** `.env` contains `TARGET_DIR=~/code`, `TARGET_DIR=$HOME/code` or `TARGET_DIR=${HOME}/code`
- **THEN** `TARGET_DIR` is the value of `HOME` followed by `/code`

#### Scenario: Nothing else expands
- **WHEN** `.env` contains `TARGET_DIR=~other/code`, `TARGET_DIR=$HOMEDIR/code`, `TARGET_DIR=/x/$HOME` or `TARGET_DIR=$(echo /x)`
- **THEN** the value is kept literally

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

### Requirement: Skipping directories
The system SHALL skip any child directory whose name matches an entry in `SKIP_DIRS`, a comma separated list, in every command. Whitespace around entries is ignored and empty entries are skipped. An entry containing whitespace SHALL be an error: the command prints `Invalid SKIP_DIRS: '<entry>' contains spaces; separate entries with commas` to stderr and exits 2 before touching any repository, except that `--help` still exits 0.

#### Scenario: Comma separated list
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

### Requirement: Optional proxy clearing
Commands that contact a remote (including `jef fetch`) SHALL accept `-c`/`--clear-proxy`, and when given SHALL unset `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY` (upper and lower case) before running git and print "Cleared proxy". When the flag is not given, no command SHALL change the proxy variables or print "Cleared proxy".

#### Scenario: Proxy cleared
- **WHEN** the user runs a remote-contacting command with `--clear-proxy`
- **THEN** proxy variables are unset for that run and "Cleared proxy" is printed

#### Scenario: Fetch with proxy clearing
- **WHEN** the user runs `jef fetch -c`
- **THEN** proxy variables are unset before fetching and "Cleared proxy" is printed

#### Scenario: Flag omitted
- **WHEN** the user runs any jef command (for example `jef fetch` or `jef which`) without `-c`/`--clear-proxy` while `HTTPS_PROXY` is set
- **THEN** `HTTPS_PROXY` stays set for git and "Cleared proxy" is not printed

### Requirement: Argument count validation
Commands that take positional arguments SHALL exit with status 2 and a message stating the required and provided counts when the number of positional arguments is wrong, using the singular "argument" when exactly one is required. An unrecognised option SHALL also exit with status 2.

#### Scenario: Missing branch argument
- **WHEN** the user runs `jef checkout` with no branch
- **THEN** "1 argument required. 0 provided" is printed, nothing else runs and the exit status is 2

#### Scenario: Singular wording for push
- **WHEN** the user runs `jef push` with no branch
- **THEN** "1 argument required. 0 provided" is printed (not "1 arguments")

### Requirement: Branch names are treated as data
Commands that take branch names SHALL treat them as literal values: names are never word-split or glob-expanded, local-branch existence is checked against exactly `refs/heads/<name>`, and a name starting with `-` SHALL be rejected (exit status 2) so it is never interpreted as a git option.

#### Scenario: Local branch check is exact
- **WHEN** a repository has a branch `feature/x` and the user runs `jef checkout x`
- **THEN** that repository is not matched

#### Scenario: Branch name starting with a dash
- **WHEN** the user passes a branch name beginning with `-` (for example `jef checkout -- -x`)
- **THEN** the command prints that it is not a valid branch name, exits with status 2 and git is never invoked with the name

### Requirement: Command help and usage
Every jef command SHALL accept `-h`/`--help`, print its usage (synopsis, options, one-line description) to stdout and exit 0 without touching any repository, whether or not a target directory is configured. An unrecognised option SHALL print a message and the command's usage to stderr and exit with status 2.

#### Scenario: Help requested
- **WHEN** the user runs `jef checkout --help` with no target directory configured
- **THEN** the usage is printed and the exit status is 0

#### Scenario: Unknown option
- **WHEN** the user runs `jef which --bogus`
- **THEN** an "unknown option" message and the usage are printed and the exit status is 2

#### Scenario: Option not supported by the command
- **WHEN** the user runs `jef checkout -c`, a command that has no proxy option
- **THEN** it is treated as an unknown option with exit status 2

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
