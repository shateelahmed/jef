# branch-stash Specification

## Purpose
`jef stash` stashes local changes in every repository of the target directory, and with `--clear`, `--pop` or `--list` clears, pops or lists the stashes across them.

## Requirements

### Requirement: Stash local changes in every repository
`jef stash` SHALL run `git stash push` in each repository of the target directory that has uncommitted changes to tracked files, print "Stashed" under its "Working directory" header and count it as done. With `-u`/`--include-untracked` untracked files SHALL count as changes and be stashed too (`git stash push --include-untracked`). Repositories with nothing to stash SHALL be skipped without output. It takes no arguments.

#### Scenario: Changes stashed
- **WHEN** repository `alpha` has a modified tracked file
- **THEN** "Working directory alpha" and "Stashed" are printed, the working tree is clean and `git stash list` has one entry

#### Scenario: Nothing to stash
- **WHEN** a repository has no changes to tracked files
- **THEN** it is skipped without output

#### Scenario: Untracked files
- **WHEN** a repository has only an untracked file
- **THEN** without `-u` it is skipped, and with `-u` the file is stashed

### Requirement: Stash failure
A failing `git stash push` SHALL print "Could not stash" and count the repository as failed; the other repositories are still processed and the command exits 3.

#### Scenario: Stash fails
- **WHEN** `git stash push` fails in a repository
- **THEN** "Could not stash" is printed under its name, the next repository is processed and the exit status is 3

### Requirement: Stash dry run
`jef stash` SHALL accept `-n`/`--dry-run`: in each repository that would be stashed it prints "Would stash", runs no mutating git command and counts it as done; the banner shows "Dry run: true".

#### Scenario: Dry run
- **WHEN** the user runs `jef stash -n` and `alpha` has changes
- **THEN** "Would stash" is printed and the changes are still in the working tree

### Requirement: Clear stashes
`jef stash --clear` SHALL run `git stash clear` in every repository that has at least one stash entry, after printing the plan "Will clear these stashes:" with one line per such repository ("  alpha: 3 stashes", "1 stash" when one) and asking "Clear N stashes in M repositories? [y/N]". Repositories without stashes SHALL be skipped without output. `--clear` SHALL NOT be combined with `-u` (usage error, exit 2).

#### Scenario: Stashes cleared
- **WHEN** `alpha` has 2 stash entries, `beta` has none, and the user answers `y`
- **THEN** "alpha: 2 stashes" is listed, `alpha` prints "Cleared 2 stashes", `git stash list` in `alpha` is empty and `beta` is not mentioned

#### Scenario: Nothing to clear
- **WHEN** no repository has a stash
- **THEN** "No stashes to clear" is printed, no question is asked and the command exits 0

#### Scenario: --clear with -u
- **WHEN** `jef stash --clear -u` is run
- **THEN** a usage error is printed and the command exits 2

### Requirement: Clear confirmation
`jef stash --clear` SHALL ask for confirmation through the shared prompt: `-y`/`--yes` skips it, any answer but `y`/`yes` prints "Aborted. Nothing was cleared." and exits 1, and without a terminal and without `--yes` it prints "Not running in a terminal. Re-run with --yes to clear. Nothing was cleared." and exits 2. With `-n` it prints the plan under "Would clear these stashes:", asks nothing and changes nothing. `-y` without `--clear` SHALL be a usage error (exit 2).

#### Scenario: Declined
- **WHEN** the user answers `n`
- **THEN** every stash is kept and the exit status is 1

#### Scenario: No terminal
- **WHEN** stdin is not a terminal and `--yes` is not given
- **THEN** every stash is kept and the exit status is 2

#### Scenario: Dry run
- **WHEN** `jef stash --clear -n` is run
- **THEN** the plan is printed under "Would clear these stashes:" and every stash is kept

### Requirement: Pop stashes
`jef stash --pop` SHALL run `git stash pop` (the latest entry, `stash@{0}`) in every repository that has at least one stash entry, printing "Popped stash@{0}: <stash subject>" under its "Working directory" header and counting it as done. Repositories without stashes SHALL be skipped without output. No confirmation is asked; with `-n` it prints "Would pop stash@{0}: <stash subject>" and changes nothing.

#### Scenario: Popped
- **WHEN** `alpha` has one stash with a modified tracked file and `beta` has none
- **THEN** `alpha` prints "Popped stash@{0}: ...", its change is back in the working tree and its stash list is empty; `beta` is not mentioned

#### Scenario: Pop dry run
- **WHEN** `jef stash --pop -n` is run and `alpha` has a stash
- **THEN** "Would pop stash@{0}: ..." is printed and the stash is still there

### Requirement: Pop failure
When `git stash pop` fails (a conflict, or local changes in the way), `jef stash --pop` SHALL print "Could not pop (the stash is kept)", count the repository as failed, continue with the others and exit 3.

#### Scenario: Pop fails
- **WHEN** popping in `alpha` conflicts with a local change
- **THEN** "Could not pop (the stash is kept)" is printed, `alpha`'s stash entry is still there and the exit status is 3

### Requirement: List stashes
`jef stash --list` SHALL change nothing and print, for repositories that have stashes, "Total: N stashes in M repositories", a blank line, then per repository its name with the count in parentheses (green) and one line per entry "  - stash@{i} (<date YYYY-MM-DD HH:MM>) <stash subject>" (the ref cyan), with a blank line between repositories, like `jef merged`. With no stash anywhere it SHALL print "No stashes".

#### Scenario: Listing
- **WHEN** `alpha` has 2 stashes and `beta` has none
- **THEN** "Total: 2 stashes in 1 repository" and "alpha (2)" with two "- stash@{" lines are printed, `beta` is not mentioned, and nothing changes

### Requirement: Stash option combinations
At most one of `--clear`, `--pop` and `--list` SHALL be given; `-u` only without them; `-y` only with `--clear`; `-n` not with `--list`. Any other combination SHALL be a usage error (exit 2).

#### Scenario: Two actions
- **WHEN** `jef stash --pop --clear` is run
- **THEN** a usage error is printed and the command exits 2
