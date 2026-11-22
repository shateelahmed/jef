# branch-merged Specification

## Purpose
Listing, and optionally deleting, branches already merged into the default branch across all repositories (`jef merged [-l|-r] [-m <repos>] [-D [-n] [-y]]`).

## Requirements

### Requirement: List merged branches
`jef merged` SHALL fetch every selected repository (`git fetch --prune origin`) and list, per repository that has any, its merged local and remote (origin) branches as a bulleted block (see "Bulleted list format"). A repository with merged branches counts as done in the summary and one without as skipped.

#### Scenario: Base branch
- **WHEN** `origin/$DEFAULT_BRANCH` exists
- **THEN** it is the base, otherwise the local `$DEFAULT_BRANCH` is

#### Scenario: Ancestor-merged branches
- **WHEN** a repository has local branch `feat-a` and origin branch `feat-a`, both already contained in the default branch
- **THEN** both are listed under the repository

#### Scenario: Listed per repository
- **WHEN** repository `alpha` has merged local branches `feat-a` and `feat-b` and merged origin branch `feat-a`
- **THEN** the output has the lines `alpha`, `  local`, `    - feat-a`, `    - feat-b`, `  remote` and `    - origin/feat-a`

#### Scenario: Squash-merged branch
- **WHEN** a branch with its own commit was squash-merged into the default branch on origin
- **THEN** it is listed even though it is not an ancestor

#### Scenario: Unmerged branch
- **WHEN** a branch has commits that are not in the default branch
- **THEN** it is not listed

#### Scenario: Nothing merged
- **WHEN** no repository has merged branches
- **THEN** "No merged branches found" is printed and the exit status is 0

#### Scenario: No base branch
- **WHEN** neither `origin/$DEFAULT_BRANCH` nor `$DEFAULT_BRANCH` exists in a repository
- **THEN** a message is printed, the repository is skipped and nothing else happens to it

#### Scenario: Old git
- **WHEN** git is older than 2.38
- **THEN** a single notice is printed and only the ancestor test is used

### Requirement: Bulleted list format
Branch lists (the listing, the `--delete` plan, the dry run and the deletion result) SHALL be bulleted blocks: the repository name on its own line, an indented `local` and/or `remote` label (only when that group has branches), then one `- <branch>` line per branch (remote names prefixed with `origin/`). Blocks are separated by a blank line, have no "Working directory" header, and a repository's problems are indented under its name. The plan, dry run and result indent the blocks by 2.

#### Scenario: Colours
- **WHEN** stdout is a terminal and `NO_COLOR` is unset
- **THEN** names, labels, branches and the checked-out note use green, magenta, cyan and yellow; piped output contains no escape codes

#### Scenario: Plain text when piped
- **WHEN** stdout is not a terminal or `NO_COLOR` is set
- **THEN** the same lines are printed without escape codes; on a terminal the repository name is green, the labels magenta, the branch names cyan and notes yellow (red for `(could not delete)`)

### Requirement: What counts as merged
A branch SHALL count as merged when it is an ancestor of the base, or when merging it into the base would change nothing (squash and rebase merges). `$DEFAULT_BRANCH`, `origin/HEAD` and origin's HEAD branch SHALL never be listed.

#### Scenario: Default branch never listed
- **WHEN** a repository has the default branch and origin's HEAD branch
- **THEN** neither is listed

### Requirement: Fetch failure
A repository whose fetch fails SHALL be reported as failed (exit status 3), its remote branches SHALL NOT be examined, and its local branches SHALL still be.

#### Scenario: Unreachable origin
- **WHEN** a repository's origin cannot be fetched
- **THEN** "Could not fetch origin" is printed, its local merged branches are still listed and the summary counts it as failed

### Requirement: Scope flags
`-l`/`--local` SHALL restrict the command to local branches and `-r`/`--remote` to remote branches. Neither flag, or both, SHALL mean both.

#### Scenario: Local only
- **WHEN** the user runs `jef merged -l`
- **THEN** only `local:` lines are printed

#### Scenario: Remote only
- **WHEN** the user runs `jef merged -r`
- **THEN** only `remote:` lines are printed

### Requirement: Repository filter
`-m`/`--repo` SHALL limit the run to the named repositories. Names are comma or space separated and the flag can be repeated. A name that is not a git repository in the target directory, or is listed in `SKIP_DIRS`, SHALL be a usage error (exit status 2).

#### Scenario: Several repositories
- **WHEN** the user runs `jef merged -m alpha,beta -m gamma`
- **THEN** only alpha, beta and gamma are examined

#### Scenario: Unknown name
- **WHEN** the user runs `jef merged -m nope`
- **THEN** an error and the usage are printed and the exit status is 2

### Requirement: Checked-out branch is kept
A merged branch that is checked out SHALL be listed with the note `(checked out, kept)` and SHALL NOT be deleted locally. The command SHALL NOT switch branches.

#### Scenario: Checked out
- **WHEN** a repository is on a merged branch `feat` and the user runs `jef merged -D -y`
- **THEN** `feat` is kept, still checked out, and the other merged branches are deleted

### Requirement: Delete merged branches
`-D`/`--delete` SHALL print a plan of the branches to delete per repository and ask `Delete N branches in M repositories? [y/N]`. Only `y`, `Y` or `yes` SHALL proceed; any other answer SHALL print "Aborted. Nothing was deleted." and exit with status 1. When stdin is not a terminal and `-y` was not given, the command SHALL print "Not running in a terminal. Re-run with --yes to delete. Nothing was deleted." and exit with status 2. When nothing is deletable no question is asked.

#### Scenario: Deletion commands
- **WHEN** the deletion is confirmed
- **THEN** local branches are deleted with `git branch -D`, the remote branches of a repository with a single `git push origin --delete`, and a failed deletion marks the repository failed

#### Scenario: Declined
- **WHEN** the user answers `n`
- **THEN** nothing is deleted and the exit status is 1

#### Scenario: Accepted
- **WHEN** the user answers `y`
- **THEN** the merged local and remote branches are deleted and the usual summary is printed

#### Scenario: No terminal
- **WHEN** `jef merged -D` runs with stdin not a terminal and without `-y`
- **THEN** the exit status is 2 and nothing is deleted

#### Scenario: Yes flag
- **WHEN** the user runs `jef merged -D -y`
- **THEN** the plan is printed, no question is asked and the branches are deleted

#### Scenario: Scope respected
- **WHEN** the user runs `jef merged -D -l -y`
- **THEN** only local branches are deleted and origin is left untouched

### Requirement: Deletion result list
After deleting, `jef merged -D` SHALL print "Deleted merged branches:" followed by the plan's blocks: deleted branches plainly, the checked-out branch marked `(checked out, kept)` and branches that could not be deleted marked `(could not delete)`, with git's error output indented below. It SHALL NOT print per-branch "Deleted ..." lines.

#### Scenario: Deleted list
- **WHEN** the user runs `jef merged -D -y`, `alpha` has merged branch `feat` locally and on origin and `beta` has merged origin branch `other`
- **THEN** after "Deleted merged branches:" the output shows `  alpha`, `    local`, `      - feat`, `    remote`, `      - origin/feat`, then `  beta`, `    remote`, `      - origin/other`

#### Scenario: Remote refuses
- **WHEN** origin rejects the deletion in `alpha`
- **THEN** `      - origin/feat (could not delete)` is shown, the repository counts as failed and the exit status is 3

### Requirement: Dry run
With `-D`, `-n`/`--dry-run` SHALL print "Would delete these merged branches:" followed by the same bulleted blocks as the listing (indented by 2, problems under the repository name, checked-out branches marked `(checked out, kept)`), never prompt (even with `-y`) and change nothing. It SHALL NOT print per-branch "Would delete" lines or "Working directory" headers. A repository with deletable branches counts as done, one with a failed fetch as failed, others as skipped.

#### Scenario: Dry run with yes
- **WHEN** the user runs `jef merged -D -n -y` and `alpha` has merged branch `feat` locally and on origin
- **THEN** the output has `Would delete these merged branches:`, `  alpha`, `    local`, `      - feat`, `    remote`, `      - origin/feat`, no question is asked and no branch is removed

### Requirement: Repeatable list flags
Value flags of type `list` in the shared option parser SHALL accumulate: each repeated occurrence (`-m a`, `--repo b`, `--repo=c`) SHALL be appended to the value, separated by a space.

#### Scenario: Repeated flag
- **WHEN** the user runs `jef merged -m alpha --repo=beta`
- **THEN** the repository filter is `alpha beta`
