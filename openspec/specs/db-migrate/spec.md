# db-migrate Specification

## Purpose
Running each repository's configured command (typically its database migration, e.g. via `docker exec`) non-interactively across all repositories (`jef migrate [-n] [-j N] [-b BRANCH]`), configured by `MIGRATE_CMDS` in `.env`.

## Requirements

### Requirement: Configured command per repository
`jef migrate` SHALL read `MIGRATE_CMDS` from `.env`, a list of `<repository directory name>:<command>` entries separated by `;` outside single or double quotes (the name is the text before the first `:`; whitespace around names and commands is trimmed; blank entries are ignored), and run each command with `bash -c` from inside the named repository. Repositories without an entry SHALL be skipped silently and count as skipped.

#### Scenario: Run in the repository
- **WHEN** `MIGRATE_CMDS="alpha:echo ran > migrated.txt"` and `jef migrate` runs
- **THEN** `migrated.txt` is created in the `alpha` repository, "Running: echo ran > migrated.txt" is printed and `alpha` counts as done

#### Scenario: No entry
- **WHEN** a repository has no entry
- **THEN** it is skipped without output

#### Scenario: Shell syntax
- **WHEN** a command contains `&&`, redirects or quotes
- **THEN** it is interpreted by `bash -c`

#### Scenario: Semicolon inside quotes
- **WHEN** an entry is `alpha:sh -c "echo one; echo two"`
- **THEN** it stays one entry and both echoes run in `alpha`

### Requirement: Non-interactive commands
`jef migrate` SHALL run every command with stdin redirected from `/dev/null`, with or without `-j`, so commands run non-interactively (e.g. `docker exec <container> ...` without `-it`) and a command that waits for input fails instead of hanging.

#### Scenario: Docker exec
- **WHEN** an entry is `alpha:docker exec alpha-app php artisan migrate --force`
- **THEN** `docker` is run with those arguments, its stdin is not a terminal and its exit status decides done or failed

#### Scenario: Command reads input
- **WHEN** a command reads from stdin while `jef migrate` is given input
- **THEN** the command reads end of input, and fails if it needs an answer

### Requirement: Configuration errors
If `MIGRATE_CMDS` is unset or contains no entries, `jef migrate` SHALL print how to set it and exit 1. An entry without `:`, with an empty name or an empty command, or whose name appears twice, or an unterminated quote, SHALL print the entry and exit 2 before running anything. An entry naming a repository that is not a git repository in the target directory (or is in `SKIP_DIRS`) SHALL print a warning and be ignored.

#### Scenario: Unset
- **WHEN** `MIGRATE_CMDS` is unset
- **THEN** a hint is printed and the exit status is 1

#### Scenario: Malformed or duplicate entry
- **WHEN** an entry is `alpha`, `alpha:`, `:cmd` or repeats a name
- **THEN** "Invalid MIGRATE_CMDS entry" is printed, nothing runs and the exit status is 2

#### Scenario: Unknown repository
- **WHEN** an entry names `nosuch` which is not a repository
- **THEN** a warning is printed and the other entries still run

### Requirement: Failures do not stop the run
When a command exits non-zero, `jef migrate` SHALL print "Migration failed in <repository> (exit N)", count the repository as failed and continue. The exit status SHALL be 3 if any repository failed.

#### Scenario: Failing command
- **WHEN** the command of `alpha` exits 7 and `beta` has a working command
- **THEN** "Migration failed in alpha (exit 7)" is printed, `beta` still runs and the exit status is 3

### Requirement: Dry run
`jef migrate` SHALL accept `-n`/`--dry-run`: it prints "Would run: <command>" per repository with an entry, runs nothing, counts it as done and shows "Dry run: true" in the banner.

#### Scenario: Dry run
- **WHEN** the user runs `jef migrate -n`
- **THEN** "Would run: <command>" is printed and no command is executed

### Requirement: Branch filter
`jef migrate` SHALL accept `-b`/`--branch BRANCH` (a valid branch name, else exit 2): repositories that do not have BRANCH checked out print "on <current>, not <BRANCH>. skipping..." and count as skipped. The banner shows "Branch filter: <BRANCH>" (or "any").

#### Scenario: Other branch
- **WHEN** `beta` has `feat` checked out and the user runs `jef migrate -b main`
- **THEN** `beta` prints "on feat, not main. skipping..." and its command does not run

### Requirement: Parallel jobs
`jef migrate` SHALL accept `-j`/`--jobs N` (positive integer, default 1, else exit 2). With N above 1 up to N repositories run at once, their output is printed in repository order when all are done.

#### Scenario: Same result as sequential
- **WHEN** the same `MIGRATE_CMDS` runs with `-j 2` and with `-j 1`
- **THEN** the output (apart from the "Jobs" line), summary and exit status are identical

### Requirement: Summary
`jef migrate` SHALL end with "Summary: X done, Y failed, Z skipped": done when the command succeeded (or would run in a dry run), skipped when the repository has no entry or is filtered out by `-b`, failed when the command exited non-zero.

#### Scenario: Mixed run
- **WHEN** one command succeeds, one fails and one repository has no entry
- **THEN** the summary reads "1 done, 1 failed, 1 skipped"
