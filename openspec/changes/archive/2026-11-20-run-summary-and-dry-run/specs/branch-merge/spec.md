## ADDED Requirements

### Requirement: Dry run
`jef merge` SHALL accept `-n`/`--dry-run`: in each repository that has both branches it prints "Would merge <source> into <target>", runs no mutating git command (no checkout or merge), counts it as done in the summary and shows "Dry run: true" in the banner.

#### Scenario: Dry run
- **WHEN** the user runs `jef merge -n feature-x develop`
- **THEN** "Would merge feature-x into develop" is printed and no branch or working tree changes
