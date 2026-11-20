# branch-checkout Specification

## Purpose
Checking out the same local branch across every repository in the target directory (`scrippy checkout <branch>`).

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
