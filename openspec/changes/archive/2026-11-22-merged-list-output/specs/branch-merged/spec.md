## MODIFIED Requirements

### Requirement: List merged branches
`jef merged` SHALL fetch every selected repository (`git fetch --prune origin`) and list, per repository that has any, its merged local and remote (origin) branches as a bulleted block: the repository name on its own line, then an indented `local` and/or `remote` label (each only when it has branches) followed by one `- <branch>` line per branch (remote names prefixed with `origin/`), with a blank line before each block and no "Working directory" header. Problems of a repository (failed fetch, missing base branch) SHALL be printed indented under its name. On a terminal (and with `NO_COLOR` unset or empty) the repository name SHALL be green, the labels magenta, the branch names cyan and the `(checked out, kept)` note yellow; otherwise the output is plain text. The plan shown before `--delete` asks for confirmation SHALL use the same block, indented by 2. A repository with merged branches counts as done in the summary and one without as skipped.

#### Scenario: Base branch
- **WHEN** `origin/$DEFAULT_BRANCH` exists
- **THEN** it is the base, otherwise the local `$DEFAULT_BRANCH` is

#### Scenario: Ancestor-merged branches
- **WHEN** a repository has local branch `feat-a` and origin branch `feat-a`, both already contained in the default branch
- **THEN** both are listed under the repository

#### Scenario: Bulleted output
- **WHEN** repository `alpha` has merged local branches `feat-a` and `feat-b` and merged origin branch `feat-a`
- **THEN** the output has the lines `alpha`, `  local`, `    - feat-a`, `    - feat-b`, `  remote` and `    - origin/feat-a`

#### Scenario: Colours
- **WHEN** stdout is a terminal and `NO_COLOR` is unset
- **THEN** names, labels, branches and the checked-out note use green, magenta, cyan and yellow; piped output contains no escape codes

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

### Requirement: Dry run
With `-D`, `-n`/`--dry-run` SHALL print "Would delete these merged branches:" followed by the same bulleted blocks as the listing (indented by 2, problems under the repository name, checked-out branches marked `(checked out, kept)`), never prompt (even with `-y`) and change nothing. It SHALL NOT print per-branch "Would delete" lines or "Working directory" headers. A repository with deletable branches counts as done, one with a failed fetch as failed, others as skipped.

#### Scenario: Dry run with yes
- **WHEN** the user runs `jef merged -D -n -y` and `alpha` has merged branch `feat` locally and on origin
- **THEN** the output has `Would delete these merged branches:`, `  alpha`, `    local`, `      - feat`, `    remote`, `      - origin/feat`, no question is asked and no branch is removed

### Requirement: Delete merged branches
`-D`/`--delete` SHALL print a plan of the branches to delete per repository and ask `Delete N branches in M repositories? [y/N]`. Only `y`, `Y` or `yes` SHALL proceed; any other answer SHALL print "Aborted. Nothing was deleted." and exit with status 1. When stdin is not a terminal and `-y` was not given, the command SHALL print "Not running in a terminal. Re-run with --yes to delete. Nothing was deleted." and exit with status 2. When nothing is deletable no question is asked.

After deleting, the command SHALL print "Deleted merged branches:" followed by the plan's bulleted blocks (indented by 2): deleted branches plainly, the checked-out branch marked `(checked out, kept)` and branches that could not be deleted marked `(could not delete)` (red on a terminal), with git's error output indented below. It SHALL NOT print per-branch "Deleted ..." lines or "Working directory" headers.

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

#### Scenario: Deleted list
- **WHEN** the user runs `jef merged -D -y`, `alpha` has merged branch `feat` locally and on origin and `beta` has merged origin branch `other`
- **THEN** after "Deleted merged branches:" the output shows `  alpha`, `    local`, `      - feat`, `    remote`, `      - origin/feat`, then `  beta`, `    remote`, `      - origin/other`

#### Scenario: Remote refuses
- **WHEN** origin rejects the deletion in `alpha`
- **THEN** `      - origin/feat (could not delete)` is shown, the repository counts as failed and the exit status is 3
