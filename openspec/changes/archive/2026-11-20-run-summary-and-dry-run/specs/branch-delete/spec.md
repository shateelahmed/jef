## ADDED Requirements

### Requirement: Dry run
`jef delete` SHALL accept `-n`/`--dry-run`: it prints "Would delete local branch <branch>" and, with `-r`, "Would delete remote branch <branch>" per repository, runs no mutating git command (no checkout, branch deletion or push), leaves repositories and origins unchanged, counts would-be actions as done in the summary, and shows "Dry run: true" in the banner.

#### Scenario: Dry run with remote deletion
- **WHEN** the user runs `jef delete -n -r feature-x` and a repository has the branch locally and on origin
- **THEN** both "Would delete" lines are printed and the branch still exists locally and on origin
