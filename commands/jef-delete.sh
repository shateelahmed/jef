#!/bin/bash
# shellcheck disable=SC2154,SC2034 # colour variables come from lib/terminal-color-codes.sh; cli_* are read by lib/cli.sh

# Delete a branch locally (and optionally on the remote) in every repository

script_path="${BASH_SOURCE[0]}"
while [ -L "$script_path" ]; do # follow symlinks using plain readlink (portable to old macOS)
    link_directory="$(cd "$(dirname "$script_path")" && pwd -P)"
    script_path="$(readlink "$script_path")"
    case "$script_path" in
    /*) ;;
    *) script_path="$link_directory/$script_path" ;;
    esac
done
script_location="$(cd "$(dirname "$script_path")/.." && pwd -P)"
unset script_path link_directory
source "$script_location/lib/cli.sh"

cli_name="delete"
cli_description="Delete a branch locally (and optionally on the remote) in every repository"
cli_positionals="<branch>"
cli_accepts_proxy=true
cli_extra_flags=("r|delete-remote-branch|delete_remote_branch|Also delete the branch on the remote")
parse_options "$@"
require_args 1

source "$script_location/lib/common.sh"

branch_to_delete="${cli_positional[0]}"

if ! is_valid_branch_name "$branch_to_delete"; then
    echo "'$branch_to_delete' is not a valid branch name"
    exit 2
fi

echo "Target directory: ${green}$target_directory${reset}"
echo "Branch to delete: ${green}$branch_to_delete${reset}"
echo "Clear proxy: ${green}$clear_proxy${reset}"
echo "Delete remote branch: ${green}$delete_remote_branch${reset}"

source "$script_location/lib/clear-proxy.sh"

found="" # flag to check if branch is found in any child_directory of the $target_directory

delete_in_repo() {
    local child_directory="$1" child_directory_name exists deleted could_not_delete_local_branch
    local current_branch exit_code default_branch_in_remote

    child_directory_name=$(get_directory_name "$child_directory")
    print_repo_header "$child_directory"

    exists="" # flag to check if branch exists locally and/or remotely
    deleted="" # flag to check if branch exists locally and/or remotely
    could_not_delete_local_branch=""
    if git -C "$child_directory" show-ref --verify --quiet "refs/heads/$branch_to_delete"; then # Check if branch exists locally
        exists+="local"

        current_branch=$(git -C "$child_directory" branch --show-current)
        if [ "$current_branch" == "$branch_to_delete" ]; then  # if the current git branch is "$branch_to_delete"
            git -C "$child_directory" checkout "${DEFAULT_BRANCH}" -- &> /dev/null
            current_branch=$(git -C "$child_directory" branch --show-current)
        fi
        if [ "$current_branch" == "$branch_to_delete" ]; then  # if the current git branch is "$branch_to_delete"
            could_not_delete_local_branch="y"
            echo "Could not checkout to default branch in $child_directory. skipping..."
        else
            git -C "$child_directory" branch -D -- "$branch_to_delete"
            deleted+="local"
        fi
    fi

    if $delete_remote_branch && [ -z "$could_not_delete_local_branch" ]; then
        git -C "$child_directory" ls-remote --exit-code --heads origin "$branch_to_delete" &> /dev/null # check if remote branch exists and set exit code to status variable "$?"
        exit_code="$?"
        if [ "$exit_code" == "0" ]; then # 0 = exists, 2 = does not exist
            if [ ! -z "$exists" ]; then
                exists+=" & "
            fi
            exists+="remote"

            # Prefer the local origin/HEAD ref (no network); fall back to asking the remote
            default_branch_in_remote=$(git -C "$child_directory" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2> /dev/null)
            default_branch_in_remote="${default_branch_in_remote#origin/}"
            if [ -z "$default_branch_in_remote" ]; then
                default_branch_in_remote=$(git -C "$child_directory" remote show origin | sed -n '/HEAD branch/s/.*: //p')
            fi
            if [ "$branch_to_delete" == "${default_branch_in_remote}" ]; then
                echo "$branch_to_delete is the default branch in $child_directory. It cannot be deleted."
            else
                git -C "$child_directory" push origin --delete "$branch_to_delete"
                if [ ! -z "$deleted" ]; then
                    deleted+=" & "
                fi
                deleted+="remote"
            fi
        fi
    fi

    if [ ! -z "$exists" ]; then
        if [ -z "$found" ]; then
            found="y"
        fi
        if [ ! -z "$deleted" ]; then
            echo "$deleted deleted: ${green}$child_directory_name${reset}" # display child_directory name
        fi
    fi
}

for_each_repo delete_in_repo

if [ -z "$found" ]; then
    echo "Branch not found in any repository"
fi
