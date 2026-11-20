## ADDED Requirements

### Requirement: Confirmation before deleting
Before deleting anything, `jef delete` SHALL scan all repositories with read-only checks, print a plan stating per repository whether the branch will be deleted locally, on origin, or both (and which repositories are skipped or fail), and ask `Delete branch '<branch>' in N repositories? [y/N]`. Only `y`, `Y` or `yes` SHALL proceed; any other answer or end of input SHALL print "Aborted. Nothing was deleted." and exit with status 1.

#### Scenario: Plan shows local, remote and both
- **WHEN** the user runs `jef delete -r feat` and one repository has `feat` locally and on origin, another only locally, another only on origin
- **THEN** the plan lists "local and remote (origin)", "local" and "remote (origin)" respectively before the prompt

#### Scenario: Local only without -r
- **WHEN** the user runs `jef delete feat` without `-r`
- **THEN** the plan states that only local branches are deleted

#### Scenario: Refused repositories are listed
- **WHEN** a repository cannot leave the branch or the branch is the remote default branch
- **THEN** the plan marks that repository as skipped or failing with the reason

#### Scenario: Declined
- **WHEN** the user answers `n` (or presses Enter, or input ends)
- **THEN** "Aborted. Nothing was deleted." is printed, exit status is 1 and no branch is removed

#### Scenario: Accepted
- **WHEN** the user answers `y`
- **THEN** the branches in the plan are deleted with the usual per-repository output, summary and exit codes

#### Scenario: Remotes queried once
- **WHEN** the user runs `jef delete -r -y feat`
- **THEN** each repository's origin is queried exactly once, for planning, and the deletion reuses that result

#### Scenario: Quiet repositories
- **WHEN** a repository has the branch neither locally nor (with `-r`) on origin
- **THEN** no "Working directory" header is printed for it in the deletion or dry-run output, and it is counted as skipped in the summary

#### Scenario: Nothing to delete
- **WHEN** the branch is deletable in no repository
- **THEN** no prompt is shown and the usual output and exit status apply

### Requirement: Skip confirmation with --yes
`jef delete` SHALL accept `-y`/`--yes`, which skips the prompt and deletes immediately. The plan SHALL still be printed.

#### Scenario: Yes flag
- **WHEN** the user runs `jef delete -y feat`
- **THEN** the plan is printed, no question is asked and the branches are deleted

### Requirement: No terminal without --yes
When stdin is not a terminal and `-y` is not given, `jef delete` SHALL print the plan, then "Not running in a terminal. Re-run with --yes to delete. Nothing was deleted.", exit with status 2 and delete nothing.

#### Scenario: Piped input
- **WHEN** `jef delete feat` runs with stdin not a terminal and the branch is deletable
- **THEN** exit status is 2 and no branch is removed

### Requirement: Dry run never prompts
`-n`/`--dry-run` SHALL never prompt and SHALL behave as before; when combined with `-y`, dry run wins and nothing is deleted.

#### Scenario: Dry run with yes
- **WHEN** the user runs `jef delete -n -y feat`
- **THEN** only "Would delete" lines are printed and nothing is deleted
