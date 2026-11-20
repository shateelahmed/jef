## ADDED Requirements

### Requirement: Dry run
`jef push` SHALL accept `-n`/`--dry-run`: in each repository that has the branch locally it prints "Would push <branch> to origin", runs no mutating git command (no checkout or push), counts it as done in the summary and shows "Dry run: true" in the banner.

#### Scenario: Dry run
- **WHEN** the user runs `jef push -n feature-x`
- **THEN** "Would push feature-x to origin" is printed and origin does not receive the branch
