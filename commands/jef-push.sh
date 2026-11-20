#!/bin/bash
# shellcheck disable=SC2154,SC2034 # colour variables come from lib/terminal-color-codes.sh; cli_* are read by lib/cli.sh

# Push a branch to origin in every repository that has it locally

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

cli_name="push"
cli_description="Push a branch to origin in every repository that has it locally"
cli_positionals="<branch>"
cli_accepts_proxy=true
parse_options "$@"
require_args 1

source "$script_location/lib/common.sh"

branch_to_push="${cli_positional[0]}"

if ! is_valid_branch_name "$branch_to_push"; then
    echo "'$branch_to_push' is not a valid branch name"
    exit 2
fi

echo "Target directory: ${green}$target_directory${reset}"
echo "Branch to push: ${green}$branch_to_push${reset}"
echo "Clear proxy: ${green}$clear_proxy${reset}"

source "$script_location/lib/clear-proxy.sh"

push_repo() {
    local child_directory="$1" current_branch

    if ! git -C "$child_directory" show-ref --verify --quiet "refs/heads/$branch_to_push"; then
        return # branch_to_push does not exist locally
    fi

    print_repo_header "$child_directory"

    current_branch=$(git -C "$child_directory" branch --show-current)
    if [ "$current_branch" != "$branch_to_push" ]; then  # if the current git branch is not "$branch_to_push"
        git -C "$child_directory" checkout "$branch_to_push" --
        current_branch=$(git -C "$child_directory" branch --show-current)
    fi
    if [ "$current_branch" != "$branch_to_push" ]; then  # if the current git branch is not "$branch_to_push"
        echo "Could not checkout to $branch_to_push. skipping..."
        return # could not checkout to "$branch_to_push"
    fi

    git -C "$child_directory" push -u origin "$branch_to_push"
}

for_each_repo push_repo
