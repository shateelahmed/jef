#!/bin/bash
# shellcheck disable=SC2154,SC2034 # colour variables come from lib/terminal-color-codes.sh; cli_* are read by lib/cli.sh

# Merge one branch into another in every repository that has both

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

cli_name="merge"
cli_description="Merge one branch into another in every repository that has both"
cli_positionals="<source_branch> <destination_branch>"
cli_accepts_proxy=true
parse_options "$@"
require_args 2

source "$script_location/lib/common.sh"

source_branch="${cli_positional[0]}"
target_branch="${cli_positional[1]}"

if ! is_valid_branch_name "$source_branch"; then
    echo "'$source_branch' is not a valid branch name"
    exit 2
fi
if ! is_valid_branch_name "$target_branch"; then
    echo "'$target_branch' is not a valid branch name"
    exit 2
fi

echo "Target directory: ${green}$target_directory${reset}"
echo "Source branch: ${green}$source_branch${reset}"
echo "Target branch: ${green}$target_branch${reset}"
echo "Clear proxy: ${green}$clear_proxy${reset}"

source "$script_location/lib/clear-proxy.sh"

merge_repo() {
    local child_directory="$1" current_branch

    if ! git -C "$child_directory" show-ref --verify --quiet "refs/heads/$source_branch" \
    || ! git -C "$child_directory" show-ref --verify --quiet "refs/heads/$target_branch"; then
        return # source_branch or target_branch does not exist locally
    fi

    print_repo_header "$child_directory"

    current_branch=$(git -C "$child_directory" branch --show-current)
    if [ "$current_branch" != "$target_branch" ]; then  # if the current git branch is not "$target_branch"
        git -C "$child_directory" checkout "$target_branch" --
        current_branch=$(git -C "$child_directory" branch --show-current)
    fi
    if [ "$current_branch" != "$target_branch" ]; then  # if the current git branch is not "$target_branch"
        echo "Could not checkout to $target_branch. skipping..."
        return # could not checkout to "$target_branch"
    fi

    git -C "$child_directory" merge "$source_branch"
}

for_each_repo merge_repo
