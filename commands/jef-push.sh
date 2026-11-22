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
cli_extra_flags=("n|dry-run|dry_run|Show what would happen without changing anything")
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
echo "Dry run: ${green}$dry_run${reset}"

source "$script_location/lib/clear-proxy.sh"

push_repo() {
    local child_directory="$1" current_branch local_sha remote_output remote_sha push_count=""

    if ! git -C "$child_directory" show-ref --verify --quiet "refs/heads/$branch_to_push"; then
        mark_repo_skipped
        return # branch_to_push does not exist locally
    fi

    print_repo_header "$child_directory"

    local_sha=$(git -C "$child_directory" rev-parse "refs/heads/$branch_to_push")
    if ! remote_output=$(git -C "$child_directory" ls-remote origin "refs/heads/$branch_to_push" 2> /dev/null); then
        echo "Could not reach origin"
        mark_repo_failed
        return
    fi
    remote_sha="${remote_output%%[[:space:]]*}"

    if [ -z "$remote_sha" ]; then
        : # not on origin yet: push it
    elif [ "$remote_sha" = "$local_sha" ]; then
        echo "Nothing to push"
        if ! $dry_run; then
            set_upstream_if_missing "$child_directory"
        fi
        mark_repo_skipped
        return
    elif git -C "$child_directory" cat-file -e "$remote_sha^{commit}" 2> /dev/null; then
        if git -C "$child_directory" merge-base --is-ancestor "$remote_sha" "$local_sha"; then
            push_count=$(git -C "$child_directory" rev-list --count "$remote_sha..$local_sha")
        elif git -C "$child_directory" merge-base --is-ancestor "$local_sha" "$remote_sha"; then
            echo "Nothing to push (behind origin)"
            mark_repo_skipped
            return
        fi
    fi # otherwise diverged or unknown remote tip: let git decide

    if [ -n "$push_count" ]; then
        if [ "$push_count" = 1 ]; then
            push_count="1 commit"
        else
            push_count="$push_count commits"
        fi
    fi

    if $dry_run; then
        echo "Would push $branch_to_push to origin"
        [ -n "$push_count" ] && echo "Would push $push_count"
        mark_repo_done
        return
    fi
    [ -n "$push_count" ] && echo "Pushing $push_count"

    current_branch=$(git -C "$child_directory" branch --show-current)
    if [ "$current_branch" != "$branch_to_push" ]; then  # if the current git branch is not "$branch_to_push"
        git -C "$child_directory" checkout "$branch_to_push" -- || true
        current_branch=$(git -C "$child_directory" branch --show-current)
    fi
    if [ "$current_branch" != "$branch_to_push" ]; then  # if the current git branch is not "$branch_to_push"
        echo "Could not checkout to $branch_to_push. skipping..."
        mark_repo_failed
        return # could not checkout to "$branch_to_push"
    fi

    if git -C "$child_directory" push -u origin "$branch_to_push"; then
        mark_repo_done
    else
        mark_repo_failed
    fi
}

# Keep the old "push -u" effect when nothing needs pushing: track origin/<branch> if unset.
set_upstream_if_missing() {
    local child_directory="$1"
    if [ -z "$(git -C "$child_directory" config "branch.$branch_to_push.remote")" ] \
        && git -C "$child_directory" show-ref --verify --quiet "refs/remotes/origin/$branch_to_push"; then
        git -C "$child_directory" branch --set-upstream-to="origin/$branch_to_push" "$branch_to_push" > /dev/null 2>&1 || true
    fi
}

for_each_repo push_repo
finish_run
