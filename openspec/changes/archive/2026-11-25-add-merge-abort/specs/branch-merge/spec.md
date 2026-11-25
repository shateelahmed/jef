## ADDED Requirements
### Requirement: Abort merges in progress
`jef merge --abort` SHALL run `git merge --abort` in every repository where a merge is in progress (`MERGE_HEAD` exists), print "Aborted the merge" under its "Working directory" header and count it as done. Other repositories SHALL be skipped without output; when none has a merge in progress it SHALL print "No merge in progress" and exit 0. No confirmation is asked. The banner SHALL show the target directory, "Action: abort" and "Dry run".

#### Scenario: Merge aborted
- **WHEN** `alpha` has a conflicted merge in progress, `beta` has none, and `jef merge --abort` is run
- **THEN** `alpha` prints "Aborted the merge", no merge is in progress in `alpha`, its working tree is as before the merge, `beta` is not mentioned and the command exits 0

#### Scenario: Nothing to abort
- **WHEN** no repository has a merge in progress
- **THEN** "No merge in progress" is printed and the command exits 0

### Requirement: Abort dry run
With `-n`/`--dry-run`, `jef merge --abort` SHALL print "Would abort the merge" in each repository with a merge in progress and change nothing.

#### Scenario: Abort dry run
- **WHEN** `jef merge --abort -n` is run and `alpha` has a merge in progress
- **THEN** "Would abort the merge" is printed and the merge is still in progress

### Requirement: Abort failure
When `git merge --abort` fails, `jef merge --abort` SHALL print "Could not abort the merge", count the repository as failed, continue with the others and exit 3.

#### Scenario: Abort fails
- **WHEN** `git merge --abort` fails in `alpha`
- **THEN** "Could not abort the merge" is printed, the other repositories are processed and the exit status is 3

### Requirement: Abort arguments
`jef merge --abort` SHALL take no positional arguments: any branch argument with `--abort` SHALL be a usage error (exit 2). Without `--abort`, `jef merge` keeps requiring exactly two branch arguments.

#### Scenario: Branches with --abort
- **WHEN** `jef merge --abort feat main` is run
- **THEN** a usage error is printed and the command exits 2, changing nothing
