## ADDED Requirements
### Requirement: Repository filter
Every command that operates on repositories (checkout, delete, fetch, find, merge, merged, migrate, pull, push, rebase, stash, status, sync, which) SHALL accept `-m`/`--repo REPOS`: directory names, comma or space separated, repeatable (the values accumulate). When given, the command SHALL operate only on the named repositories, in the usual order, as if the others did not exist: they are not visited, printed, counted, or considered by checks such as "does not exist in any repository".

#### Scenario: Filtered run
- **WHEN** `jef fetch -m alpha,gamma` is run in a target with `alpha`, `beta` and `gamma`
- **THEN** only `alpha` and `gamma` are fetched and printed, and the summary counts only them

#### Scenario: Repeated flag
- **WHEN** `jef pull -m alpha --repo beta main` is run
- **THEN** `alpha` and `beta` are pulled and `gamma` is not touched

#### Scenario: Branch checks see only the named repositories
- **WHEN** `jef merge -m alpha feat main` is run and only `beta` has `feat`
- **THEN** "Branch 'feat' does not exist in any repository" is printed and the command exits 2

### Requirement: Repository filter in banner and help
Commands that print a banner SHALL show "Repositories: all" without `-m` and the names as given with it. Each command's `--help` SHALL list `-m, --repo REPOS`.

#### Scenario: Banner
- **WHEN** `jef pull -m alpha,beta main` is run
- **THEN** the banner shows "Repositories: alpha,beta"

### Requirement: Unknown repository names
A name given to `-m` that is not a repository the command would visit SHALL print "unknown repository '<name>' (not a git repository in the target directory, or listed in SKIP_DIRS)" with the usage and exit 2 before any repository is touched, question asked or plan printed.

#### Scenario: Unknown name
- **WHEN** `jef push -m alpha,nosuch feat` is run
- **THEN** the unknown-repository error is printed, nothing is pushed and the command exits 2

#### Scenario: Skipped directory named
- **WHEN** `skipme` is in `SKIP_DIRS` and `jef which -m skipme` is run
- **THEN** the unknown-repository error is printed and the command exits 2

### Requirement: Migrate entries outside the filter
`jef migrate -m REPOS` SHALL NOT warn about `MIGRATE_CMDS` entries for repositories that exist but were not named with `-m`; it still warns about entries naming no repository of the target directory.

#### Scenario: Entry for a repository left out
- **WHEN** `MIGRATE_CMDS` has entries for `alpha` and `beta` and `jef migrate -m alpha` is run
- **THEN** only `alpha`'s command runs and no warning mentions `beta`
