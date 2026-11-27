## ADDED Requirements
### Requirement: Run a command in every repository
`jef exec <command...>` SHALL run the command from inside each repository of the target directory (or each one named with `-m`), in the usual order, printing the "Working directory <name>" header and then the command's output (stdout and stderr). At least one argument is required (otherwise a usage error, exit 2). The banner shows the target directory, repositories, the command, the branch filter, jobs and dry run.

#### Scenario: Command in every repository
- **WHEN** `jef exec git rev-parse --abbrev-ref HEAD` is run with `alpha` on `main` and `beta` on `dev`
- **THEN** `alpha`'s header is followed by `main`, `beta`'s by `dev`, the summary is "2 done, 0 failed, 0 skipped" and the exit status is 0

#### Scenario: No command
- **WHEN** `jef exec` is run without arguments
- **THEN** a usage error is printed and the exit status is 2

### Requirement: Exec failures
A command that exits 0 SHALL count as done; any other exit status SHALL print "Exited with status N" in red and count the repository as failed, and the run continues. The run ends with the usual summary and exits 3 when any repository failed.

#### Scenario: A failing command
- **WHEN** the command exits 1 in `alpha` and 0 elsewhere
- **THEN** `alpha` shows "Exited with status 1", the other repositories still run and the exit status is 3

### Requirement: Shell string or argument list
With exactly one argument, `jef exec` SHALL run it as `bash -c "<argument>"`, so pipes, `&&`, `;`, redirects, quotes and variables work. With two or more arguments it SHALL run them as the command and its arguments exactly as given, with no further splitting or expansion. Each command SHALL run with the repository as its working directory, `JEF_REPO` set to the repository's directory name, and stdin from `/dev/null`.

#### Scenario: Shell string
- **WHEN** `jef exec 'git log --oneline | wc -l'` is run
- **THEN** each repository prints its commit count

#### Scenario: Arguments kept as given
- **WHEN** `jef exec git log -1 --format='%h %s'` is run
- **THEN** git receives `--format=%h %s` as one argument and prints the short hash and subject

#### Scenario: Repository name in the environment
- **WHEN** `jef exec 'echo "$JEF_REPO"'` is run
- **THEN** each repository prints its own directory name

### Requirement: Command options are not jef options
For `jef exec`, option parsing SHALL stop at the first word that is not a jef option or the value of one, or at `--` (which is dropped): from there on every word, including `-h`, `--help`, `-n`, `-1` and `--dry-run`, SHALL be part of the command. jef options SHALL be given before the command. Other commands SHALL parse options as before.

#### Scenario: Command flags passed through
- **WHEN** `jef exec -m alpha git log -1 --dry-run` is run
- **THEN** only `alpha` runs `git log -1 --dry-run` (jef's dry run is not turned on)

#### Scenario: Help flag inside the command
- **WHEN** `jef exec grep -h foo README.md` is run
- **THEN** jef's usage is not printed and `grep -h foo README.md` runs in each repository

#### Scenario: Double dash
- **WHEN** `jef exec -- -weird-command` is run
- **THEN** `-weird-command` is the command, not an unknown jef option

### Requirement: Exec dry run
With `-n`/`--dry-run`, `jef exec` SHALL print "Would run: <command>" under each repository's header, run nothing and count the repositories as done.

#### Scenario: Dry run
- **WHEN** `jef exec -n touch x` is run
- **THEN** "Would run: touch x" is printed for every repository and no file is created

### Requirement: Exec branch filter
`-b`/`--branch BRANCH` SHALL run the command only in repositories that have BRANCH checked out; the others SHALL print "on <current>, not <BRANCH>. skipping..." and count as skipped. An invalid branch name SHALL exit 2.

#### Scenario: Branch filter
- **WHEN** `jef exec -b dev pwd` is run with `alpha` on `main` and `beta` on `dev`
- **THEN** only `beta` runs the command and `alpha` is skipped

### Requirement: Exec parallel jobs
`-j`/`--jobs N` SHALL run up to N repositories at once (default 1, which streams output as it comes). With N above 1 each repository's output SHALL be kept and printed in the usual repository order once it has finished, with the same headers, failure lines, summary and exit status as a sequential run.

#### Scenario: Parallel run
- **WHEN** `jef exec -j 4 'sleep 1; echo "$JEF_REPO"'` is run over 3 repositories
- **THEN** it takes about one second, and the output shows the repositories in order, each with its own name
