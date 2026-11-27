#!/bin/bash
# shellcheck disable=SC2154,SC2034 # colour variables come from lib/terminal-color-codes.sh; cli_* are read by lib/cli.sh

# Fetch and pull a branch in every repository whose remote has it

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

cli_name="pull"
cli_description="Fetch and pull a branch in every repository whose remote has it"
cli_positionals="<branch>"
cli_accepts_proxy=true
cli_value_flags=(
    "m|repo|repo_filter|REPOS||list|Only these repositories: -m a,b or -m \"a b\" or -m a -m b (also --repo a, --repo=a,b)"
)
parse_options "$@"
require_args 1

source "$script_location/lib/common.sh"

branch_to_pull="${cli_positional[0]}"

if ! is_valid_branch_name "$branch_to_pull"; then
    echo "'$branch_to_pull' is not a valid branch name"
    exit 2
fi

echo "Target directory: ${green}$target_directory${reset}"
echo "Repositories: ${green}${repo_filter:-all}${reset}"
echo "Branch to pull: ${green}$branch_to_pull${reset}"
echo "Clear proxy: ${green}$clear_proxy${reset}"

source "$script_location/lib/clear-proxy.sh"

pull_repo() {
    local child_directory="$1" fetch_output current_branch

    # Fetch once (output held back), then check the remote-tracking ref locally
    local fetch_failed=""
    fetch_output=$(git -C "$child_directory" fetch --all --prune 2>&1) || fetch_failed="y"
    if [ -n "$fetch_failed" ]; then
        print_repo_header "$child_directory"
        echo "$fetch_output"
        mark_repo_failed
        return
    fi
    if ! git -C "$child_directory" show-ref --verify --quiet "refs/remotes/origin/$branch_to_pull"; then
        mark_repo_skipped
        return # the remote does not have the branch: skip silently
    fi

    print_repo_header "$child_directory"

    if [ -n "$fetch_output" ]; then
        echo "$fetch_output"
    fi

    current_branch=$(git -C "$child_directory" branch --show-current)
    if [ "$current_branch" != "$branch_to_pull" ]; then  # if the current git branch is not "$branch_to_pull"
        git -C "$child_directory" checkout "$branch_to_pull" -- || true
        current_branch=$(git -C "$child_directory" branch --show-current)
    fi
    if [ "$current_branch" != "$branch_to_pull" ]; then  # if the current git branch is not "$branch_to_pull"
        echo "Could not checkout to $branch_to_pull. skipping..."
        mark_repo_failed
        return # could not checkout to "$branch_to_pull"
    fi

    if git -C "$child_directory" pull; then
        mark_repo_done
    else
        mark_repo_failed
    fi
}

for_each_repo pull_repo
finish_run
