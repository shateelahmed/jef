# jef

jef runs git commands across every first-level git repository in a directory. It is especially helpful when you work on a project made of multiple microservices, each in its own repository.

## Use case
Checkout the following scenario. You have a project `amazing` that contains 10 microservices and currently you are working on features `awesome` and `cool`. `awesome` resides in 3 microservices and `cool` is in 5. The features also have 2 microservices in common. You need to constantly switch between these features for development. This is where jef comes in handy. jef can find, checkout to, pull or delete a specific git branch in multiple first level directories.

## Features
- Find a branch locally and on the remote (`jef find`)
- Check out, pull, push or merge a branch everywhere it exists (`jef checkout`, `jef pull`, `jef push`, `jef merge`)
- Delete a branch locally and optionally on the remote (`jef delete`)
- Fetch and prune every repository (`jef fetch`)
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
    - `SKIP_DIRS`: Comma and/or space separated list of directory names to skip in all commands (eg. `archived, playground`).
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
- Run `jef checkout <branch_name>` to checkout to a specific branch
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
- Run `jef merge <source_branch> <destination_branch>` to merge a branch into another.
- Run `jef pull <branch_name>` to pull a branch. The pull will always happen in the same branch. Each repository is fetched once, and repositories whose `origin` has no such branch are skipped silently.
- Run `jef push <branch_name>` to push a branch. The push will always happen in the same branch.
- Run `jef which` to list the branches that are currently checked out

Commands and flags (all accept `-d`/`--directory <dir>` to override `TARGET_DIR` and `-h`/`--help`; options go before the arguments):

| Command | Arguments | Extra flags |
| --- | --- | --- |
| `jef checkout` | `<branch>` | |
| `jef delete` | `<branch>` | `-c`/`--clear-proxy`, `-r`/`--delete-remote-branch`, `-n`/`--dry-run`, `-y`/`--yes` |
| `jef fetch` | | `-c`/`--clear-proxy`, `-j`/`--jobs N` |
| `jef find` | `<branch>` | `-c`/`--clear-proxy`, `-j`/`--jobs N` |
| `jef merge` | `<source_branch> <destination_branch>` | `-c`/`--clear-proxy`, `-n`/`--dry-run` |
| `jef pull` | `<branch>` | `-c`/`--clear-proxy` |
| `jef push` | `<branch>` | `-c`/`--clear-proxy`, `-n`/`--dry-run` |
| `jef which` | | |

Notes:
- Every first level directory that contains a `.git` directory or file is included, so git worktrees and submodules count as repositories. Paths and directory names containing spaces work.
- Branch names starting with `-` are rejected.
- Output: colours are used only when stdout is a terminal and the `NO_COLOR` environment variable is unset or empty (see https://no-color.org); piped or redirected output (including `jef find` and `jef which` tables) is plain text without escape codes or spinner characters.
- Exit codes (useful in scripts): `0` success, `1` target directory not set or not a valid directory, or `jef delete` aborted at the confirmation prompt, `2` usage error (wrong number of arguments, unknown option or invalid branch name; `--help` exits `0`) or `jef delete` without a terminal and without `--yes`, `3` at least one repository failed (a git command failed or the branch could not be checked out; `checkout`, `delete`, `fetch`, `merge`, `pull` and `push` only), `127` unknown `jef` command.
- Summary: `checkout`, `delete`, `fetch`, `merge`, `pull` and `push` end with `Summary: X done, Y failed, Z skipped` (skipped = the repository was visited but the operation does not apply, e.g. it lacks the branch).
- `-n`/`--dry-run` (`delete`, `merge`, `push`) prints what would happen ("Would delete local branch X", "Would merge A into B", "Would push X to origin") without running any command that changes a repository; would-be actions count as done.
- `-y`/`--yes` (`delete`) skips the confirmation question (the plan is still printed). Without it `jef delete` asks `Delete branch '<b>' in N repositories? [y/N]`; any answer but `y`/`yes` prints "Aborted. Nothing was deleted." and exits `1`. With no terminal on stdin it prints "Not running in a terminal. Re-run with --yes to delete. Nothing was deleted." and exits `2`. No question is asked when nothing can be deleted or with `--dry-run` (which wins over `--yes`).
- `-j N`/`--jobs N` (`fetch`, `find`) processes up to N repositories at once (positive integer, default 1; anything else exits `2`). Output stays in the normal repository order, so it matches `-j 1`; `fetch` prints each repository's output when all are done.


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
