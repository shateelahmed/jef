# branch-checkout Specification

## Purpose
Checking out the same local branch across every repository in the target directory (`jef checkout <branch>`).

## Requirements

### Requirement: Checkout existing local branch
The system SHALL check out the given branch in each repository where it exists locally, report "Checked out" per repository, and skip repositories where the branch does not exist locally.

#### Scenario: Branch exists locally
- **WHEN** repository `api` has local branch `feature-x` and is on `main`
- **THEN** `api` is switched to `feature-x` and "Checked out" is printed under its name

#### Scenario: Already on branch
- **WHEN** a repository is already on `feature-x`
- **THEN** no checkout is run and "Checked out" is printed

#### Scenario: Branch missing locally
- **WHEN** a repository has no local `feature-x`
- **THEN** it is skipped without output

#### Scenario: Checkout fails
- **WHEN** git cannot switch branches (e.g. uncommitted conflicting changes)
- **THEN** "Could not checkout" is printed and the next repository is processed

### Requirement: Create a new branch in chosen repositories
With `-b`/`--new`, `jef checkout -b <new_branch> <base>` SHALL create `<new_branch>` from `<base>` (not tracking it) and check it out in each repository the user chooses, printing "Created and checked out" per repository ("Created from origin/<base> and checked out" when the fallback below was used), or "Could not create" and counting the repository as failed when git fails. Both arguments are required and SHALL be valid branch/revision names; otherwise the command exits 2.

#### Scenario: Branch created from base
- **WHEN** the user chooses `alpha` and `beta` for `jef checkout -b feat main`
- **THEN** both repositories get local branch `feat` at `main`'s commit, are switched to it, and "Created and checked out" is printed under each name

#### Scenario: Base only on origin
- **WHEN** `jef checkout -b feat develop` is run and a repository has `develop` only as `origin/develop`
- **THEN** `feat` is created at `origin/develop`'s commit without an upstream, and "Created from origin/develop and checked out" is printed

#### Scenario: Wrong number of arguments
- **WHEN** `jef checkout -b feat` is run
- **THEN** "2 arguments required. 1 provided" is printed and the command exits 2

#### Scenario: Creation fails
- **WHEN** git cannot create or switch to the branch in a chosen repository
- **THEN** "Could not create" is printed under its name, the next repository is processed, and the command exits 3

### Requirement: Interactive repository picker
When `-b` is given without `-m` and stdin and stdout are terminals, the system SHALL show a checkbox list of the target repositories with nothing ticked and the cursor on the first available one. Up/Down or k/j move, Space toggles, `a` toggles all available repositories, Enter confirms and `q` or Esc cancels. Repositories that already have `<new_branch>` locally, or where `<base>` resolves neither locally nor as `origin/<base>`, SHALL be listed with the reason and SHALL NOT be selectable.

#### Scenario: Select with the keyboard
- **WHEN** the user moves to `beta`, presses Space and Enter
- **THEN** the branch is created only in `beta`

#### Scenario: Unavailable repository
- **WHEN** `gamma` already has local branch `feat`
- **THEN** `gamma` is listed with "branch exists" and pressing Space on it does not tick it

#### Scenario: Cursor starts on an available repository
- **WHEN** the first listed repository is unavailable
- **THEN** the cursor starts on the first available one, so Space ticks it

#### Scenario: No repository available
- **WHEN** every repository is unavailable
- **THEN** each is listed with its reason, "No repository can get <new_branch>. Nothing was created." is printed without showing the picker, and the command exits 1

#### Scenario: Cancel or empty selection
- **WHEN** the user presses `q`, Esc, or Enter with nothing ticked
- **THEN** "Aborted. Nothing was created." is printed, no repository is changed and the command exits 1

### Requirement: Choose repositories without the picker
`-m`/`--repo REPOS` (comma or space separated, repeatable) SHALL select repositories by directory name without showing the picker, and SHALL only be accepted together with `-b` (otherwise exit 2). Named repositories that are unavailable SHALL be reported with the reason and counted as skipped.

#### Scenario: Repositories named on the command line
- **WHEN** `jef checkout -b feat main -m alpha,beta` is run
- **THEN** `feat` is created and checked out in `alpha` and `beta` only, and no picker is shown

#### Scenario: -m without -b
- **WHEN** `jef checkout -m alpha feat` is run
- **THEN** a usage error is printed and the command exits 2

### Requirement: Reject unknown repositories and missing terminal
Unknown names given to `-m` SHALL be reported and the command SHALL exit 2 without changing anything. Without a terminal and without `-m`, the command SHALL print "Not running in a terminal. Re-run with --repo to choose repositories. Nothing was created." and exit 2.

#### Scenario: No terminal and no -m
- **WHEN** `jef checkout -b feat main` runs with stdin not a terminal
- **THEN** the not-a-terminal message is printed, nothing is created and the command exits 2

#### Scenario: Unknown repository name
- **WHEN** `-m alpha,nosuch` is given
- **THEN** `nosuch` is reported as unknown, nothing is created and the command exits 2
