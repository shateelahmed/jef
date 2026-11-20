# jef

jef helps you run a specific command in all the first level directories within a directory. This is specially helpful when you are working on a project with multiple Microservice.

## Use case
Checkout the following scenario. You have a project `amazing` that contains 10 microservices and currently you are working on features `awesome` and `cool`. `awesome` resides in 3 microservices and `cool` is in 5. The features also have 2 microservices in common. You need to constantly switch between these features for development. This is where jef comes in handy. jef can find, checkout to, pull or delete a specific git branch in multiple first level directories.

## Features
- Find a specific Git branch
- Checkout to a specific Git branch
- Pull a specific Git branch
- Delete a specific Git branch
- List all currently checked out branches

## Installation
- Clone the repository.
- Copy the `.env.example` file to same directory as `.env`.
- Update the envs to your need in the `.env` file.
    - `TARGET_DIR`: Set absolute path to the directory where you want to run jef in by default.
    - `DEFAULT_BRANCH`: Set default branch (eg. `master`, `main`) for your repository.
    - `SKIP_DIRS`: Comma and/or space separated list of directory names to skip in all commands (eg. `archived, playground`).
- Make the `install.sh` file executable (`chmod +x <filename>.sh`).
- Run `./install.sh` to install the scripts to `~/.jef` and add `~/.jef/commands` to your `PATH`.

## Migrating from scrippy
jef was previously called scrippy. If you installed scrippy before, the old install is still in `~/.scrippy` and its `PATH` line is still in your shell rc file. To switch over:

1. Re-run `./install.sh` from your clone of this repository. This installs jef to `~/.jef`.
2. Remove the old scrippy install with `./uninstall-scrippy.sh`. It lists what it will remove and asks for confirmation (use `-y` to skip the prompt). Each shell rc file it edits is backed up as `<file>.scrippy-uninstall.bak`.
   Or do it by hand: run `rm -rf ~/.scrippy`, and delete the `export PATH=...~/.scrippy/commands` line from your shell rc file (for example `~/.zshrc`).
3. Open a new terminal (or source your rc file) so the change takes effect.

Your `.env` lives in the repository clone, so no `.env` migration is needed.

## Usage
- Run `jef checkout <branch_name>` to checkout to a specific branch
- Run `jef delete <branch_name>` to delete a branch locally. Add `-r` before the `<branch_name>` to delete the branch from remote.
- Run `jef fetch` to do a fetch. Add `-c`/`--clear-proxy` to unset proxy variables first.
- Run `jef find <branch_name>` to find a branch in local and remote.
- Run `jef merge <source_branch> <destination_branch>` to merge a branch into another.
- Run `jef pull <branch_name>` to pull a branch. The pull will always happen in the same branch.
- Run `jef push <branch_name>` to push a branch. The push will always happen in the same branch.
- Run `jef which` to list the branches that are currently checked out


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
    +---------------------+----------------------------------------+```


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
