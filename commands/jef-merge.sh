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
cli_extra_flags=(
    "n|dry-run|dry_run|Show what would happen without changing anything"
    "|abort|abort|Abort the merge in progress in every repository (takes no branches)"
)
parse_options "$@"
if $abort; then
    if [ "${#cli_positional[@]}" -gt 0 ]; then
        usage_error "--abort takes no branch arguments"
    fi
else
    require_args 2
fi

source "$script_location/lib/common.sh"

if $abort; then
    echo "Target directory: ${green}$target_directory${reset}"
    echo "Action: ${green}abort${reset}"
    echo "Dry run: ${green}$dry_run${reset}"

    source "$script_location/lib/clear-proxy.sh"

    list_repos
    any_merge=false
    for child_directory in "${repo_list[@]}"; do
        if git -C "$child_directory" rev-parse -q --verify MERGE_HEAD >/dev/null; then
            any_merge=true
        fi
    done
    if ! $any_merge; then
        echo
        echo "No merge in progress"
        exit 0
    fi

    abort_repo() {
        local child_directory="$1"
        if ! git -C "$child_directory" rev-parse -q --verify MERGE_HEAD >/dev/null; then
            mark_repo_skipped
            return # no merge in progress here
        fi

        print_repo_header "$child_directory"

        if $dry_run; then
            echo "Would abort the merge"
            mark_repo_done
            return
        fi

        if git -C "$child_directory" merge --abort; then
            echo "Aborted the merge"
            mark_repo_done
        else
            echo "${red}Could not abort the merge${reset}"
            mark_repo_failed
        fi
    }

    for_each_repo abort_repo
    finish_run
    exit 0
fi

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
echo "Dry run: ${green}$dry_run${reset}"

source "$script_location/lib/clear-proxy.sh"

list_repos
require_branches_somewhere "$source_branch" "$target_branch"

merge_repo() {
    local child_directory="$1" current_branch

    if ! git -C "$child_directory" show-ref --verify --quiet "refs/heads/$source_branch" \
    || ! git -C "$child_directory" show-ref --verify --quiet "refs/heads/$target_branch"; then
        mark_repo_skipped
        return # source_branch or target_branch does not exist locally
    fi

    print_repo_header "$child_directory"

    if $dry_run; then
        echo "Would merge $source_branch into $target_branch"
        mark_repo_done
        return
    fi

    current_branch=$(git -C "$child_directory" branch --show-current)
    if [ "$current_branch" != "$target_branch" ]; then  # if the current git branch is not "$target_branch"
        git -C "$child_directory" checkout "$target_branch" -- || true
        current_branch=$(git -C "$child_directory" branch --show-current)
    fi
    if [ "$current_branch" != "$target_branch" ]; then  # if the current git branch is not "$target_branch"
        echo "Could not checkout to $target_branch. skipping..."
        mark_repo_failed
        return # could not checkout to "$target_branch"
    fi

    if git -C "$child_directory" merge "$source_branch"; then
        mark_repo_done
    else
        mark_repo_failed
    fi
}

for_each_repo merge_repo
finish_run
