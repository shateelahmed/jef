#!/bin/bash
# shellcheck disable=SC2154,SC2034 # colour variables come from lib/terminal-color-codes.sh; cli_* are read by lib/cli.sh

# Rebase one branch onto another in every repository that has both

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

cli_name="rebase"
cli_description="Rebase one branch onto another in every repository that has both"
cli_positionals="<branch> <onto_branch>"
cli_accepts_proxy=true
cli_extra_flags=(
    "p|push|push_after|Force-push (--force-with-lease) the rebased branch to origin"
    "n|dry-run|dry_run|Show what would happen without changing anything"
    "y|yes|assume_yes|Rebase without asking for confirmation"
)
parse_options "$@"
require_args 2

source "$script_location/lib/common.sh"
source "$script_location/lib/confirm.sh"

branch_to_rebase="${cli_positional[0]}"
onto_branch="${cli_positional[1]}"

if ! is_valid_branch_name "$branch_to_rebase"; then
    echo "'$branch_to_rebase' is not a valid branch name"
    exit 2
fi
if ! is_valid_branch_name "$onto_branch"; then
    echo "'$onto_branch' is not a valid branch name"
    exit 2
fi

echo "Target directory: ${green}$target_directory${reset}"
echo "Branch: ${green}$branch_to_rebase${reset}"
echo "Onto: ${green}$onto_branch${reset}"
echo "Clear proxy: ${green}$clear_proxy${reset}"
echo "Push: ${green}$push_after${reset}"
echo "Dry run: ${green}$dry_run${reset}"

source "$script_location/lib/clear-proxy.sh"

# Plan results per repository, kept in parallel indexed arrays (bash 3.2 has no associative
# arrays) keyed by the repository's position in repo_list, so each repository is queried once.
#   plan_state  "" (lacks a branch), "uptodate" (onto is already in the branch) or "replay"
#   plan_count  commits that will be replayed (onto..branch)
plan_state=()
plan_count=()

plan_repo() { # plan_repo <index>: read-only look at repo_list[index]
    local index="$1" directory="${repo_list[$1]}"
    plan_state[index]=""
    plan_count[index]=0
    if ! git -C "$directory" show-ref --verify --quiet "refs/heads/$branch_to_rebase" \
    || ! git -C "$directory" show-ref --verify --quiet "refs/heads/$onto_branch"; then
        return 0 # either branch does not exist locally
    fi
    if git -C "$directory" merge-base --is-ancestor "$onto_branch" "$branch_to_rebase"; then
        plan_state[index]="uptodate"
        return 0
    fi
    plan_state[index]="replay"
    plan_count[index]=$(git -C "$directory" rev-list --count "$onto_branch..$branch_to_rebase")
}

commit_text() { # commit_text <count>
    if [ "$1" -eq 1 ]; then
        echo "1 commit"
    else
        echo "$1 commits"
    fi
}

# Succeeds when a rebase is in progress in the repository $1 (so it can be aborted).
rebase_in_progress() {
    local name path
    for name in rebase-merge rebase-apply; do
        path=$(git -C "$1" rev-parse --git-path "$name" 2> /dev/null) || continue
        case "$path" in
        /*) ;;
        *) path="$1/$path" ;;
        esac
        if [ -d "$path" ]; then
            return 0
        fi
    done
    return 1
}

rebase_repo() { # rebase_repo <index>
    local index="$1" directory="${repo_list[$1]}" current_branch
    local count="${plan_count[$1]}"

    case "${plan_state[$index]}" in
    "")
        mark_repo_skipped
        return 0 # branch or onto_branch does not exist locally
        ;;
    uptodate)
        print_repo_header "$directory"
        echo "$branch_to_rebase is already up to date with $onto_branch"
        mark_repo_skipped
        return 0
        ;;
    esac

    print_repo_header "$directory"

    if $dry_run; then
        echo "Would rebase $branch_to_rebase onto $onto_branch ($(commit_text "$count"))"
        if $push_after; then
            echo "Would force-push $branch_to_rebase to origin"
        fi
        mark_repo_done
        return 0
    fi

    current_branch=$(git -C "$directory" branch --show-current)
    if [ "$current_branch" != "$branch_to_rebase" ]; then
        git -C "$directory" checkout "$branch_to_rebase" -- || true
        current_branch=$(git -C "$directory" branch --show-current)
    fi
    if [ "$current_branch" != "$branch_to_rebase" ]; then
        echo "Could not checkout to $branch_to_rebase. skipping..."
        mark_repo_failed
        return 0
    fi

    if ! git -C "$directory" rebase "$onto_branch"; then
        if rebase_in_progress "$directory"; then
            git -C "$directory" rebase --abort || true
        fi
        echo "${red}Rebase of $branch_to_rebase onto $onto_branch failed in $(get_directory_name "$directory"); aborted, nothing changed${reset}"
        mark_repo_failed
        return 0
    fi

    if $push_after && ! git -C "$directory" push --force-with-lease origin "$branch_to_rebase"; then
        echo "${red}Could not force-push $branch_to_rebase to origin in $(get_directory_name "$directory")${reset}"
        mark_repo_failed
        return 0
    fi
    mark_repo_done
}

# Plan phase: the only place that queries the repositories (read-only), once each.
list_repos
require_branches_somewhere "$branch_to_rebase" "$onto_branch"
repos_done=0
repos_failed=0
repos_skipped=0
replay_count=0
for ((i = 0; i < ${#repo_list[@]}; i++)); do
    plan_repo "$i"
    if [ "${plan_state[$i]}" == "replay" ]; then
        replay_count=$((replay_count + 1))
    fi
done

# Confirmation: a dry run never asks; with nothing to rebase there is nothing to ask about.
if ! $dry_run && [ "$replay_count" -gt 0 ]; then
    echo
    if $push_after; then
        echo "Will rebase '$branch_to_rebase' onto '$onto_branch' and force-push it to origin (--force-with-lease):"
    else
        echo "Will rebase '$branch_to_rebase' onto '$onto_branch':"
    fi
    for ((i = 0; i < ${#repo_list[@]}; i++)); do
        case "${plan_state[$i]}" in
        replay) echo "  $(get_directory_name "${repo_list[$i]}"): $(commit_text "${plan_count[$i]}")" ;;
        uptodate) echo "  $(get_directory_name "${repo_list[$i]}"): already up to date" ;;
        esac
    done
    echo
    repo_noun="repositories"
    if [ "$replay_count" -eq 1 ]; then
        repo_noun="repository"
    fi
    confirm_or_exit "Rebase '$branch_to_rebase' onto '$onto_branch' in $replay_count $repo_noun?" rebase rebased
fi

for ((i = 0; i < ${#repo_list[@]}; i++)); do
    rebase_repo "$i"
done

finish_run
