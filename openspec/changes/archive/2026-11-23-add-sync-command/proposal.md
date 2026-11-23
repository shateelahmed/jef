## Why
Keeping every local branch of a multi-repository project up to date with the default branch takes many commands per repository: pull the default branch, then for each branch check it out, pull it, merge (or rebase) the default branch in and push. `jef sync` does all of it in one command, in parallel across repositories.

## What Changes
- New command `jef sync [-r|--rebase] [-m REPOS] [-j N] [-c] [-n] [-y]`. Per repository: refuse uncommitted changes, `git fetch --prune origin`, pull the local `DEFAULT_BRANCH` (fast-forward only), then for every other local branch (protected ones included), alphabetically: pull it from `origin` when it exists there, merge the local default branch into it (`--rebase`: rebase it onto the default branch) and push it only when there is something to push (`--force-with-lease` with `--rebase`). Branches that are not on `origin` are synced locally and not pushed.
- The first conflict or failure aborts any merge or rebase in progress, stops that repository only (its later branches are "not attempted") and the other repositories carry on. Each repository ends on the branch it started on.
- A plan (local refs only) is printed and the user is always asked to confirm (`-y` skips; no terminal without `-y` exits 2); `-n` prints the plan and "Would" lines and changes nothing.
- Repositories run in parallel (`-j N`, default all of them); output is shown per repository, followed by a per-repository, per-branch sync summary and the usual `Summary: X done, Y failed, Z skipped` (exit 3 when a repository failed).
- Supporting changes: `rebase_in_progress` moves from `jef-rebase.sh` to `lib/repos.sh`; `parallel_run` skips `list_repos` when `parallel_use_repo_list` is true (so `-m` is honoured); `lib/terminal-color-codes.sh` gains `dim`.

## Affected commands
- New: `jef sync`.
- The `jef` dispatcher lists `sync` in its command list.
- Other commands behave as before (only code is shared).

## Out of scope
- Remotes other than `origin`.
- Treating protected branches differently from other branches.
- A `--continue` after conflicts (a conflict always aborts and stops that repository).
- Syncing branches that exist only on the remote, or deleting branches.

## Impact
- Spec: new capability branch-sync. Code: new commands/jef-sync.sh, commands/jef.sh, lib/repos.sh, lib/terminal-color-codes.sh, commands/jef-rebase.sh. Tests: new tests/sync.bats. Docs: README.md, .env.example.
