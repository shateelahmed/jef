#!/bin/bash
# shellcheck disable=SC2154,SC2034 # colour variables come from lib/terminal-color-codes.sh; cli_* are read by lib/cli.sh

# Check out a local branch in every repository that has it

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

cli_name="checkout"
cli_description="Check out a local branch in every repository that has it"
cli_positionals="<branch>"
parse_options "$@"
require_args 1

source "$script_location/lib/common.sh"

branch_to_checkout="${cli_positional[0]}"

if ! is_valid_branch_name "$branch_to_checkout"; then
    echo "'$branch_to_checkout' is not a valid branch name"
    exit 2
fi

echo "Target directory: ${green}$target_directory${reset}"
echo "Branch to checkout: ${green}$branch_to_checkout${reset}"

checkout_repo() {
    local child_directory="$1" current_branch

    if ! git -C "$child_directory" show-ref --verify --quiet "refs/heads/$branch_to_checkout"; then
        return # branch_to_checkout does not exist locally
    fi

    print_repo_header "$child_directory"

    current_branch=$(git -C "$child_directory" branch --show-current)
    if [ "$current_branch" != "$branch_to_checkout" ]; then  # if the current git branch is not "$branch_to_checkout"
        git -C "$child_directory" checkout "$branch_to_checkout" --
        current_branch=$(git -C "$child_directory" branch --show-current)
    fi
    if [ "$current_branch" != "$branch_to_checkout" ]; then  # if the current git branch is not "$branch_to_checkout"
        echo "Could not checkout"
        return
    fi

    echo "Checked out"
}

for_each_repo checkout_repo
