## ADDED Requirements
### Requirement: Branch absent from every repository
When a branch named on the command line exists locally (`refs/heads/<name>`) in none of the target repositories, `jef merge` SHALL print "Branch '<name>' does not exist in any repository" once for each such name and exit 2, before changing anything, printing a plan. This SHALL also apply with `--dry-run` and without a terminal. A branch that exists in only some repositories SHALL NOT cause an error: the repositories lacking it are skipped silently.

#### Scenario: One branch missing everywhere
- **WHEN** `jef merge feat nosuch` is run and no repository has local branch `nosuch`
- **THEN** "Branch 'nosuch' does not exist in any repository" is printed, the command exits 2 and no repository is changed

#### Scenario: Both branches missing everywhere
- **WHEN** neither named branch exists in any repository
- **THEN** one line is printed for each name and the command exits 2

#### Scenario: Dry run
- **WHEN** `jef merge -n feat nosuch` is run and `nosuch` exists nowhere
- **THEN** the same message is printed and the command exits 2

#### Scenario: Branch present in some repositories only
- **WHEN** both branches exist in `alpha` but `beta` lacks one of them
- **THEN** no error is raised and `beta` is skipped silently
