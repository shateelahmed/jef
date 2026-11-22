## MODIFIED Requirements

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
- **THEN** the output has the lines `Total: 3 branches in 1 repository`, `alpha (3)`, `  local (2)`, `    - feat-a`, `    - feat-b`, `  remote (1)` and `    - origin/feat-a`

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
Branch lists (the listing, the `--delete` plan, the dry run and the result) SHALL be bulleted blocks: the repository name with its branch count, an indented `local` and/or `remote` label with its count (only when that group has branches), then one `- <branch>` line per branch (remote ones prefixed `origin/`). Blocks are separated by a blank line and problems are indented under the name. The plan, dry run and result indent the blocks by 2. Each list starts with a `Total` line.

#### Scenario: Colours
- **WHEN** stdout is a terminal and `NO_COLOR` is unset
- **THEN** names, labels, branches and the checked-out note use green, magenta, cyan and yellow; piped output contains no escape codes

#### Scenario: Plain text when piped
- **WHEN** stdout is not a terminal or `NO_COLOR` is set
- **THEN** the same lines are printed without escape codes; on a terminal the repository name is green, the labels magenta, the branch names cyan and notes yellow (red for `(could not delete)`)

#### Scenario: Counts
- **WHEN** repository `alpha` shows two local and one remote branch
- **THEN** its lines are `alpha (3)`, `  local (2)` and `  remote (1)`; each count has the colour of the name or label it follows; branches noted as kept are counted

#### Scenario: Total line
- **WHEN** branches are shown in 2 repositories, 4 in all
- **THEN** the list starts with `Total: 4 branches in 2 repositories` (`Total: 1 branch in 1 repository` for one), indented like the blocks; the listing prints it before the first block, the other lists directly under their header

#### Scenario: Repository with only a problem
- **WHEN** a repository shows only a problem such as "Could not fetch origin" and no branches
- **THEN** its name has no count and it is not counted in the total

#### Scenario: Nothing to show
- **WHEN** no branches are shown
- **THEN** no `Total` line is printed

### Requirement: Deletion result list
After deleting, `jef merged -D` SHALL print "Deleted merged branches:" followed by the plan's blocks: deleted branches plainly, the checked-out branch marked `(checked out, kept)` and branches that could not be deleted marked `(could not delete)`, with git's error output indented below. It SHALL NOT print per-branch "Deleted ..." lines.

#### Scenario: Deleted list
- **WHEN** the user runs `jef merged -D -y`, `alpha` has merged branch `feat` locally and on origin and `beta` has merged origin branch `other`
- **THEN** after "Deleted merged branches:" the output shows `  Total: 3 branches in 2 repositories`, `  alpha (2)`, `    local (1)`, `      - feat`, `    remote (1)`, `      - origin/feat`, then `  beta (1)`, `    remote (1)`, `      - origin/other`

#### Scenario: Remote refuses
- **WHEN** origin rejects the deletion in `alpha`
- **THEN** `      - origin/feat (could not delete)` is shown, the repository counts as failed and the exit status is 3

### Requirement: Dry run
With `-D`, `-n`/`--dry-run` SHALL print "Would delete these merged branches:" followed by the same bulleted blocks as the listing (indented by 2, problems under the repository name, checked-out branches marked `(checked out, kept)`), never prompt (even with `-y`) and change nothing. It SHALL NOT print per-branch "Would delete" lines or "Working directory" headers. A repository with deletable branches counts as done, one with a failed fetch as failed, others as skipped.

#### Scenario: Dry run with yes
- **WHEN** the user runs `jef merged -D -n -y` and `alpha` has merged branch `feat` locally and on origin
- **THEN** the output has `Would delete these merged branches:`, `  Total: 2 branches in 1 repository`, `  alpha (2)`, `    local (1)`, `      - feat`, `    remote (1)`, `      - origin/feat`, no question is asked and no branch is removed
