# jef

jef runs git commands across every first-level git repository in a directory. It is especially helpful when you work on a project made of multiple microservices, each in its own repository.

## Use case
Checkout the following scenario. You have a project `amazing` that contains 10 microservices and currently you are working on features `awesome` and `cool`. `awesome` resides in 3 microservices and `cool` is in 5. The features also have 2 microservices in common. You need to constantly switch between these features for development. This is where jef comes in handy. jef can find, checkout to, pull or delete a specific git branch in multiple first level directories.

## Features
- Find a branch locally and on the remote (`jef find`)
- Check out, pull, push or merge a branch everywhere it exists (`jef checkout`, `jef pull`, `jef push`, `jef merge`)
- Rebase a branch onto another everywhere both exist, optionally force-pushing it (`jef rebase`)
- Stash local changes in every repository that has them (`jef stash`)
- Bring every local branch up to date with the default branch in one go: pull, merge (or rebase) and push, in parallel (`jef sync`)
- Delete a branch locally and optionally on the remote (`jef delete`)
- List (and optionally delete) local and remote branches already merged into the default branch (`jef merged`)
- Fetch and prune every repository (`jef fetch`)
- Run each repository's own command, such as its database migration, from one `.env` setting (`jef migrate`)
- List the branch each repository has checked out (`jef which`)
- Skip directories with `SKIP_DIRS`, override the target with `-d`, and clear proxy variables with `-c`

## Requirements
- macOS or Linux (Windows is not supported yet)
- bash (the macOS system bash 3.2 works) and git

## Installation
- Clone the repository.
- Copy the `.env.example` file to same directory as `.env`.
- Update the envs to your need in the `.env` file.
    - `TARGET_DIR`: Set absolute path to the directory where you want to run jef in by default.
    - `DEFAULT_BRANCH`: Set default branch (eg. `master`, `main`) for your repository.
    - `PROTECTED_BRANCHES`: Comma separated branch names or glob patterns (eg. `dev,qa,staging,uat,release/*`) that `jef merged` never lists or deletes. `DEFAULT_BRANCH` and the branch origin's HEAD points to are always protected.
    - `SKIP_DIRS`: Comma separated list of directory names to skip in all commands (eg. `archived,playground`). Whitespace around entries is ignored; an entry containing spaces (eg. `a b`) is an error (exit 2) in both keys.
    - `MIGRATE_CMDS`: Only for `jef migrate`. `<repository directory name>:<command>` entries separated by `;` (eg. `MIGRATE_CMDS="order-service:docker exec order-app php artisan migrate --force; user-service:docker exec user-app npm run migrate"`). A `;` inside single or double quotes belongs to the command (eg. `api:docker exec api-app sh -c "php artisan migrate --force; php artisan db:seed --force"`); otherwise use `&&`.
    - `.env` is read as plain `KEY=VALUE` lines (blank lines and `#` comments are ignored, one pair of surrounding quotes is removed). It is never executed as shell code. Only a leading `~` (alone or followed by `/`), `$HOME` or `${HOME}` in a value is expanded, to the value of `HOME` (eg. `TARGET_DIR=~/code`); `$OTHER_VAR`, `~user`, `$(...)` and `$HOME` in the middle of a value are kept literally.
- Run `./install.sh`. It copies only `commands/`, `lib/` and your `.env` (if present in the clone) to `~/.jef`, and makes `jef` and `jef-*` available as commands.
- `~/.jef/commands` is added to your `PATH` in `~/.zshrc` (zsh), `~/.bash_profile` (bash on macOS) or `~/.bashrc` (bash on Linux). For any other shell (for example fish) nothing is written: the installer prints the exact `export PATH=...` line for you to add yourself.
- Re-running `./install.sh` is safe. If your clone has no `.env`, the installed `~/.jef/.env` is kept. If both exist, the clone's `.env` is installed and the old one is saved as `~/.jef.env.bak`.
- Open a new terminal (or source your rc file), then run `jef help`.

## Uninstalling
Run `./uninstall.sh`. It lists what it will remove (`~/.jef` and the `export PATH=...` line containing `/.jef/commands` in your shell rc files) and asks for confirmation; use `-y`/`--yes` to skip the prompt (required when there is no terminal). Each rc file it edits is first backed up as `<file>.jef-uninstall.bak`, and your `~/.jef/.env` is saved to `~/.jef.env.bak`.

## Migrating from scrippy
jef was previously called scrippy. If you installed scrippy before, the old install is still in `~/.scrippy` and its `PATH` line is still in your shell rc file. To switch over:

1. Re-run `./install.sh` from your clone of this repository. This installs jef to `~/.jef`.
2. Remove the old scrippy install with `./uninstall-scrippy.sh`. It lists what it will remove and asks for confirmation (use `-y` to skip the prompt). Each shell rc file it edits is backed up as `<file>.scrippy-uninstall.bak`.
   Or do it by hand: run `rm -rf ~/.scrippy`, and delete the `export PATH=...~/.scrippy/commands` line from your shell rc file (for example `~/.zshrc`).
3. Open a new terminal (or source your rc file) so the change takes effect.

Your `.env` lives in the repository clone, so no `.env` migration is needed.

## Usage
- Run `jef help` (or `jef`, `jef -h`, `jef --help`) to list the commands, `jef help <command>` or `jef <command> --help` to see a command's options. An unknown command exits with `127`.
- Run `jef checkout <branch_name>` to checkout to a specific branch. Run `jef checkout -b <new_branch> <base>` to create `<new_branch>` from `<base>` (a branch, tag or commit; a branch that exists only on `origin` is used as `origin/<base>`) and check it out in the repositories you pick: a checkbox list is shown (Up/Down or `k`/`j` move, Space ticks, `a` ticks all, Enter confirms, `q` or Esc cancels; repositories that already have the branch or lack the base are listed but cannot be ticked; if none can, nothing is shown to pick and the command exits `1`). Add `-m`/`--repo alpha,beta` to name the repositories instead (required when there is no terminal)
- Run `jef delete <branch_name>` to delete a branch locally. Add `-r` before the `<branch_name>` to delete the branch from remote. It first prints what will be deleted in each repository (local, remote or both) and asks for confirmation; add `-y` to skip the question (required when there is no terminal, e.g. in scripts). Example:

  ```
  Will delete branch 'feat':
    alpha: local and remote (origin)
    beta: local
    gamma: remote (origin)

  Delete branch 'feat' in 3 repositories? [y/N]
  ```
- Run `jef fetch` to do a fetch. Add `-c`/`--clear-proxy` to unset proxy variables first.
- Run `jef find <branch_name>` to find a branch in local and remote.
- Run `jef merge <source_branch> <destination_branch>` to merge a branch into another in every repository that has both locally. A branch that exists in no repository is an error (`Branch '<name>' does not exist in any repository`, exit `2`, nothing changed); a repository lacking one of them is skipped. Run `jef merge --abort` to run `git merge --abort` in every repository where a merge is in progress (no branch arguments; the other repositories are skipped, and when none has a merge in progress it prints `No merge in progress` and exits `0`).
- Run `jef merged` to list, per repository, the local and remote branches already merged into `DEFAULT_BRANCH` (ancestors of it, or squash/rebase-merged: merging them would change nothing). Every repository is fetched first. Use `-l`/`-r` for local or remote only, `-m alpha,beta` (repeatable) for specific repositories, and `-D` to delete the listed branches after confirmation (`-n` to preview, `-y` to skip the question). Example:

  ```
  Total: 4 branches in 2 repositories

  alpha (3)
    local (2)
      - feat-a
      - feat-b (checked out, kept)
    remote (1)
      - origin/feat-a

  beta (1)
    remote (1)
      - origin/feat-c
  ```

  The number next to a repository and next to `local`/`remote` is how many branches are listed there (including ones noted as kept); `Total: N branches in M repositories` comes first (in the `-D` lists, 2 spaces indented under the header). Repositories that only show a problem get no count and are not in the total. With `-D`, the lists are indented by 2.

  Colours (only on a terminal, never with `NO_COLOR`): repository green, `local`/`remote` magenta, branches cyan, the `(checked out, kept)` note yellow. `-D` shows the same list under "Will delete these merged branches:" before asking, and again under "Deleted merged branches:" afterwards, with branches that could not be deleted marked `(could not delete)` in red; `-D -n` shows it under "Would delete these merged branches:".

  What is kept (never deleted, even with `-y`): branches matching `PROTECTED_BRANCHES` (not listed at all); branches checked out in any worktree (`(checked out, kept)`); branches with no commits of their own, i.e. whose tip is on the default branch's first-parent history (`(no commits, kept)`, eg. a fresh branch from `main`; a branch merged by fast-forward looks the same, which is the safe side; `--include-empty` deletes them too); and branches that moved since the scan (`(changed since scan, kept)`): deletion is a compare-and-delete (`git update-ref -d <ref> <sha>` locally, `git push --delete --force-with-lease=<ref>:<sha>` on origin), so a branch someone pushed to after the listing survives. The confirmation count excludes kept branches.
- Run `jef rebase <branch> <onto_branch>` to rebase a branch onto another in every repository that has both locally (a branch that exists in no repository is an error: `Branch '<name>' does not exist in any repository`, exit `2`, before any plan or question; it checks out `<branch>` and runs `git rebase <onto_branch>`; nothing is fetched). The plan lists the commits to replay per repository (`alpha: 3 commits`, `beta: already up to date`) and asks for confirmation (`-y` skips it, `-n` previews). A conflict or a dirty working tree fails that repository (an in-progress rebase is aborted, nothing is left half done) and the run continues. `-p`/`--push` then force-pushes the rebased branch with `--force-with-lease` to `origin`, only where commits were rewritten.
- Run `jef migrate` to run, in every repository that has an entry in `MIGRATE_CMDS`, that entry's command from inside the repository (as `bash -c "<command>"`, so `&&`, redirects and quotes work; a `;` outside quotes separates entries). Repositories without an entry are skipped silently; an entry naming a repository that is not in the target directory only prints a warning; an unset `MIGRATE_CMDS` exits `1` and a malformed or duplicate entry exits `2`. A failing command does not stop the run (the repository counts as failed). `-b <branch>` only migrates repositories that have that branch checked out (others print `on <current>, not <branch>. skipping...`). The commands run non-interactively: in a non-interactive bash (your shell's rc files are not loaded: set up tools such as nvm inside the command) with no terminal input, so a command that asks a question fails instead of waiting. For Docker, use `docker exec <container> <command>` without `-it` (no TTY is available, so `-it` fails with "the input device is not a TTY"). It addresses the running container by name, so it works wherever the repository's compose file lives; the container must be running, otherwise the command fails and the repository counts as failed (`docker ps` shows the names; set `container_name:` in the compose file for a stable one). Pass your tool's non-interactive flag (eg. `php artisan migrate --force`). (`docker compose exec -T <service>` also works, but needs `-f <path to compose file>` when the file is not in the repository root.) There is no confirmation question; use `-n` to preview.
- Run `jef pull <branch_name>` to pull a branch. The pull will always happen in the same branch. Each repository is fetched once, and repositories whose `origin` has no such branch are skipped silently.
- Run `jef push <branch_name>` to push a branch. Each repository is checked against origin first and only pushed when there is something to push (`Nothing to push` otherwise, `Pushing N commits` when ahead); the branch is checked out only when pushing.
- Run `jef stash` to run `git stash push` in every repository that has uncommitted changes to tracked files (`-u`/`--include-untracked` also stashes untracked files; `-n` previews). Repositories with nothing to stash are skipped. `--clear` runs `git stash clear` in every repository that has stashes: it lists them first (`alpha: 2 stashes`) and asks `Clear N stashes in M repositories? [y/N]` (`-y` skips it, `-n` previews; stashes cleared this way cannot be recovered). `--pop` runs `git stash pop` (the latest stash) in every repository that has one (`-n` previews; on a conflict git keeps the stash and leaves the conflict in the working tree, and the repository counts as failed). `--list` lists each repository's stashes (changes nothing), for example:

  ```
  Total: 2 stashes in 1 repository

  alpha (2)
    - stash@{0} (2026-11-23 17:59) WIP on feat: 3f2a1b4 add login
    - stash@{1} (2026-11-23 17:40) WIP on main: 9c1d0e2 init
  ```

  Only one of `--clear`, `--pop`, `--list` at a time; `-u` goes with none of them, `-y` only with `--clear`, `-n` not with `--list`.
- Run `jef sync` to bring every local branch up to date with `DEFAULT_BRANCH` (required, else exit `1`), in all repositories at once (or the ones named with `-m alpha,beta`, repeatable). Per repository, in parallel (`-j N` caps the number running at once; the default is all of them): it refuses a repository with uncommitted changes to tracked files (untracked files are fine), fetches `origin`, pulls the local default branch (fast-forward only), then for every other local branch (protected ones included), alphabetically: pulls it from `origin` when it exists there, merges the local default branch into it (`-r`/`--rebase` rebases it onto the default branch instead) and pushes it, only when there is something to push (`--force-with-lease` with `--rebase`). A branch that is not on `origin` is synced locally and never pushed. The first conflict or failure aborts the merge or rebase in progress (git is never left half done), stops that repository (its remaining branches are `not attempted`) and the other repositories carry on; each repository ends on the branch it started on. The plan is printed first, as a bulleted list like `jef merged`, and the question `Sync N branches in M repositories by merging <default>? [y/N]` is always asked (`-y` skips it, `-n` only prints the plan under "Would sync these branches (...)"). While it runs nothing is printed (git's output is kept and only the relevant lines of a failing step, `CONFLICT` lines first, are shown), then the result is listed per repository, the default branch first, with the outcome of each branch in parentheses. Example:

  ```
  Synced branches:
    Total: 2 synced, 1 up to date, 1 failed, 1 not attempted in 2 repositories

    alpha (5)
      - main (pulled)
      - feat-a (merged 3 commits from main, pushed)
      - feat-b (up to date)
      - feat-c (conflict while merging main; merge aborted, stopped)
          CONFLICT (content): Merge conflict in app.php
      - feat-d (not attempted)

    beta (2)
      - main (up to date)
      - local-x (local only, merged 1 commit from main)
  ```

  The `Total` line counts branches (not the default branch); the number next to a repository is how many lines it lists. Colours (only on a terminal, never with `NO_COLOR`): repository green, branches cyan, the note in parentheses green when synced, yellow when up to date or local only, red when failed and dim when not attempted. The usual `Summary: X done, Y failed, Z skipped` line ends the run.
- Run `jef which` to list the branches that are currently checked out

Commands and flags (all accept `-d`/`--directory <dir>` to override `TARGET_DIR` and `-h`/`--help`; options go before the arguments):

| Command | Arguments | Extra flags |
| --- | --- | --- |
| `jef checkout` | `<branch>`, or `-b <new_branch> <base>` | `-b`/`--new`, `-m`/`--repo REPOS` (only with `-b`) |
| `jef delete` | `<branch>` | `-c`/`--clear-proxy`, `-r`/`--delete-remote-branch`, `-n`/`--dry-run`, `-y`/`--yes` |
| `jef fetch` | | `-c`/`--clear-proxy`, `-j`/`--jobs N` |
| `jef find` | `<branch>` | `-c`/`--clear-proxy`, `-j`/`--jobs N` |
| `jef merge` | `<source_branch> <destination_branch>` | `-c`/`--clear-proxy`, `-n`/`--dry-run`, `--abort` |
| `jef merged` | | `-c`/`--clear-proxy`, `-l`/`--local`, `-r`/`--remote`, `-m`/`--repo REPOS`, `-D`/`--delete`, `-n`/`--dry-run`, `-y`/`--yes`, `--include-empty` |
| `jef migrate` | | `-n`/`--dry-run`, `-j`/`--jobs N`, `-b`/`--branch BRANCH` |
| `jef pull` | `<branch>` | `-c`/`--clear-proxy` |
| `jef push` | `<branch>` | `-c`/`--clear-proxy`, `-n`/`--dry-run` |
| `jef rebase` | `<branch> <onto_branch>` | `-c`/`--clear-proxy`, `-p`/`--push`, `-n`/`--dry-run`, `-y`/`--yes` |
| `jef stash` | | `-u`/`--include-untracked`, `--clear`, `--pop`, `--list`, `-n`/`--dry-run`, `-y`/`--yes` (with `--clear`) |
| `jef sync` | | `-c`/`--clear-proxy`, `-r`/`--rebase`, `-m`/`--repo REPOS`, `-j`/`--jobs N`, `-n`/`--dry-run`, `-y`/`--yes` |
| `jef which` | | |

Notes:
- Every first level directory that contains a `.git` directory or file is included, so git worktrees and submodules count as repositories. Paths and directory names containing spaces work.
- Branch names starting with `-` are rejected.
- Output: colours are used only when stdout is a terminal and the `NO_COLOR` environment variable is unset or empty (see https://no-color.org); piped or redirected output (including `jef find` and `jef which` tables) is plain text without escape codes or spinner characters.
- Exit codes (useful in scripts): `0` success, `1` target directory not set or not a valid directory, `MIGRATE_CMDS` not set for `jef migrate`, `DEFAULT_BRANCH` not set for `jef sync`, or `jef delete`/`jef merged -D`/`jef rebase`/`jef sync`/`jef stash --clear` aborted at the confirmation prompt, `2` usage error (wrong number of arguments, unknown option, invalid branch name, a named branch that exists in no repository (`merge`, `rebase`), unknown `-m` repository or malformed `MIGRATE_CMDS` entry; `--help` exits `0`) or `jef delete`/`jef merged -D`/`jef rebase`/`jef sync`/`jef stash --clear` without a terminal and without `--yes`, `3` at least one repository failed (a git command failed or the branch could not be checked out; `checkout`, `delete`, `fetch`, `merge` (`--abort`: a failed abort too), `merged`, `migrate`, `pull`, `push`, `rebase`, `stash` (`--pop`: a failed pop too) and `sync` only; for `merged` also a failed fetch or deletion, for `rebase` also a failed rebase or push, for `sync` a conflict, an uncommitted change, a default branch that cannot fast-forward or a failed push, for `migrate` a command that exited non-zero), `127` unknown `jef` command.
- Summary: `checkout`, `delete`, `fetch`, `merge`, `merged`, `migrate`, `pull`, `push`, `rebase`, `stash` and `sync` end with `Summary: X done, Y failed, Z skipped` (`stash --list` prints no summary) (skipped = the repository was visited but the operation does not apply, e.g. it lacks the branch).
- `-n`/`--dry-run` (`delete`, `merge`, `merged -D`, `migrate`, `push`, `rebase`, `stash`, `sync`) prints what would happen ("Would delete local branch X" (`jef merged -D -n` instead prints its usual bulleted list under "Would delete these merged branches:"), "Would run: <command>", "Would merge A into B", "Would abort the merge" (`merge --abort`), "Would stash", "Would pop stash@{0}: <subject>", "Would push X to origin" (or "Nothing to push"), "Would rebase A onto B (N commits)", "Would pull <default>" and "Would sync <branch>: ..." for `sync`) without running any command that changes a repository; would-be actions count as done.
- `-y`/`--yes` (`delete`, `merged -D`, `rebase`, `stash --clear`, `sync`) skips the confirmation question (the plan is still printed). Without it `jef delete` asks `Delete branch '<b>' in N repositories? [y/N]`; any answer but `y`/`yes` prints "Aborted. Nothing was deleted." and exits `1`. With no terminal on stdin it prints "Not running in a terminal. Re-run with --yes to delete. Nothing was deleted." and exits `2`. No question is asked when nothing can be deleted or with `--dry-run` (which wins over `--yes`). `jef merged -D` asks `Delete N branches in M repositories? [y/N]` with the same answers and exit codes. `jef rebase` asks `Rebase '<b>' onto '<o>' in N repositories? [y/N]` and words its messages "Nothing was rebased." / "Re-run with --yes to rebase.". `jef sync` always asks (also with nothing to merge, since it pulls) and words its messages "Nothing was synced." / "Re-run with --yes to sync.". `jef stash --clear` asks `Clear N stashes in M repositories? [y/N]` (any answer but `y`/`yes` prints "Aborted. Nothing was cleared." and exits `1`; with no terminal it prints "Not running in a terminal. Re-run with --yes to clear. Nothing was cleared." and exits `2`).
- `-j N`/`--jobs N` (`fetch`, `find`, `migrate`) processes up to N repositories at once (positive integer, default 1; anything else exits `2`). Output stays in the normal repository order, so it matches `-j 1`; `fetch` and `migrate` print each repository's output when all are done.

## Development
Checks are run by a single script:

```bash
./scripts/check.sh
```

It runs `bash -n` on every shell file, [shellcheck](https://www.shellcheck.net/) and the [bats-core](https://github.com/bats-core/bats-core) test suite in `tests/`, and exits non-zero if any of them fails. The test files run in parallel (`xargs -P`, bounded by the CPU count; no GNU parallel needed) and each file's output is printed in file order.

While iterating, `./scripts/check.sh --quick tests/which.bats` runs the syntax and shellcheck gates plus only the given test files (with no files, only those affected by uncommitted changes). `./scripts/check.sh --both` runs the suite under both `bash` and `/bin/bash` (the macOS bash 3.2) concurrently. Install the prerequisites with `brew install bats-core shellcheck` (macOS) or `sudo apt-get install bats shellcheck` (Debian/Ubuntu).

Things worth knowing:
- Commands share `lib/cli.sh` (option parsing, `--help`), `lib/repos.sh` (`for_each_repo`) and `lib/common.sh` (library loading). A new command declares its name, description and flags, then calls `parse_options`; keep the dispatcher list in `commands/jef.sh` in sync (a test checks it).
- Tests are hermetic and offline: each test file builds a fixture workspace of git repos cloned from local bare "origin" repos once (`build_fixture_template` in `setup_file`), and each test gets its own copy of it (with its clones' origin URLs repointed at the copy's origins) and a temporary `HOME`. A test needing a non-standard workspace can call `build_workspace_from_scratch` instead. Your real repositories, `.env` and `~/.jef` are never touched (the tests run a copy of `commands/` and `lib/` with their own `.env`).
- jef must work on macOS (bash 3.2, BSD tools) and Linux. Set `JEF_BASH` to choose the interpreter the tests run the scripts with, e.g. `JEF_BASH=/bin/bash ./scripts/check.sh` to test against the macOS system bash.
- GitHub Actions (`.github/workflows/ci.yml`) runs `./scripts/check.sh` on Ubuntu and macOS (with `/bin/bash` 3.2) for every push and pull request.

## Example output
<br>**jef which :**
<br><b>Description:</b>
Displays the current branch that each directory (cool) is checked out to. This is particularly useful for keeping track of the branch status across multiple repositories.

<b>Output Example Explanation:</b>
A table is shown with directories and the branches currently checked out in each directory. This helps you quickly understand the state of your microservices.

    +---------------------+----------------------------------------+
    | Directory           | Current Branch                         |
    +---------------------+----------------------------------------+
    | Target directory    | /home/users/Documents/application/dev  |
    | cool                | master                                 |
    | amazing             | develop                                |
    | awesome             | develop                                |
    +---------------------+----------------------------------------+


<br>**jef find <branch_name> :**
<br><b>Description:</b>
Searches for a specific branch across all microservices. It indicates whether the branch exists locally, remotely, or not at all.

<b>Output Example Explanation:</b>
The command highlights whether the specified branch (develop in this case) exists locally and/or remotely for each microservice directory.

    Target directory           : /home/users/Documents/application/dev
    Branch to find             : develop
    Clear proxy                : false


    +---------------------+-------+--------+
    | Directory           | Local | Remote |
    +---------------------+-------+--------+
    | cool                |   ✔   |   ✘    |
    | amazing             |   ✔   |   ✔    |
    | awesome             |   ✔   |   ✔    |
    +---------------------+-------+--------+
    ✔ (Green): The branch exists locally and/or remotely.
    ✘ (Red): The branch does not exist locally or remotely.
