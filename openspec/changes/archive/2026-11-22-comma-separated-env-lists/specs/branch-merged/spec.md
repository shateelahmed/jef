## MODIFIED Requirements

### Requirement: Protected branches
Branches matching `PROTECTED_BRANCHES` (comma separated names or glob patterns, from `.env`) SHALL never be listed or deleted, locally or on origin. The default branch and origin's HEAD branch SHALL always be protected. Patterns SHALL NOT be expanded against files. An entry containing whitespace SHALL exit 2 with `Invalid PROTECTED_BRANCHES: '<entry>' contains spaces; separate entries with commas` before any work. The banner SHALL show `Protected: <entries joined by ", ">` or `Protected: default branch only`.

#### Scenario: Names and patterns
- **WHEN** `PROTECTED_BRANCHES="dev, release/*"` and a repository has merged branches `dev`, `release/1.0` and `feat`
- **THEN** only `feat` is listed and deleted, and the banner shows `Protected: dev, release/*`

#### Scenario: No expansion
- **WHEN** `PROTECTED_BRANCHES=qa*` and the current directory contains a file `qa-file`
- **THEN** a branch `qa-two` is still protected

#### Scenario: Space separated list rejected
- **WHEN** `PROTECTED_BRANCHES="dev qa"` and the user runs `jef merged -D -y`
- **THEN** it exits 2 with the invalid-entry message and nothing is deleted
