#!/bin/bash
# shellcheck disable=SC2154,SC2034 # colour variables come from lib/terminal-color-codes.sh; cli_* are read by lib/cli.sh

# List (and optionally delete) local and remote branches already merged into the default branch

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

cli_name="merged"
cli_description="List (and optionally delete) branches already merged into the default branch"
cli_positionals=""
cli_accepts_proxy=true
cli_extra_flags=(
    "l|local|only_local|Only local branches (default: local and remote)"
    "r|remote|only_remote|Only remote (origin) branches"
    "D|delete|delete_branches|Delete the merged branches after confirmation"
    "n|dry-run|dry_run|With --delete: show what would be deleted without changing anything"
    "y|yes|assume_yes|With --delete: delete without asking for confirmation"
)
cli_value_flags=(
    "m|repo|repo_filter|REPOS||list|Only these repositories (comma or space separated, repeatable)"
)
parse_options "$@"
require_args 0

source "$script_location/lib/common.sh"
source "$script_location/lib/confirm.sh"

# Scope: neither -l nor -r, or both, means local and remote
want_local=true
want_remote=true
if $only_local && ! $only_remote; then
    want_remote=false
elif $only_remote && ! $only_local; then
    want_local=false
fi

# Repositories to examine: all of them, or the ones named with -m (in the usual order)
list_repos
if [ -n "$repo_filter" ]; then
    set -f # the names are split on spaces below and must not be glob-expanded
    requested_names=${repo_filter//,/ }
    for requested_name in $requested_names; do
        requested_found=""
        for child_directory in "${repo_list[@]}"; do
            if [ "$(get_directory_name "$child_directory")" == "$requested_name" ]; then
                requested_found="y"
            fi
        done
        if [ -z "$requested_found" ]; then
            set +f
            usage_error "unknown repository '$requested_name' (not a git repository in the target directory, or listed in SKIP_DIRS)"
        fi
    done
    selected_repos=()
    for child_directory in "${repo_list[@]}"; do
        for requested_name in $requested_names; do
            if [ "$(get_directory_name "$child_directory")" == "$requested_name" ]; then
                selected_repos+=("$child_directory")
                break
            fi
        done
    done
    set +f
    repo_list=("${selected_repos[@]}")
fi

if $want_local && $want_remote; then
    scope_text="local and remote"
elif $want_local; then
    scope_text="local"
else
    scope_text="remote"
fi

echo "Target directory: ${green}$target_directory${reset}"
echo "Clear proxy: ${green}$clear_proxy${reset}"
echo "Branches: ${green}$scope_text${reset}"
echo "Repositories: ${green}${repo_filter:-all}${reset}"
echo "Delete: ${green}$delete_branches${reset}"
echo "Dry run: ${green}$dry_run${reset}"

source "$script_location/lib/clear-proxy.sh"

# git merge-tree --write-tree (used to spot squash and rebase merges) needs git 2.38
merge_tree_supported=false
read -r git_major git_minor <<< "$(git --version | sed -n 's/^git version \([0-9][0-9]*\)\.\([0-9][0-9]*\).*/\1 \2/p')"
if [ -n "$git_major" ] && { [ "$git_major" -gt 2 ] || { [ "$git_major" -eq 2 ] && [ "$git_minor" -ge 38 ]; }; }; then
    merge_tree_supported=true
else
    echo "${yellow}Note: this git is older than 2.38, so squash and rebase merged branches cannot be detected; only branches that are ancestors of the default branch are listed.${reset}"
fi

# Succeeds when the ref $1 is already in the base ref $merge_base_ref: it is an ancestor of it,
# or merging it would change nothing (what a squash or rebase merge leaves behind).
is_merged() {
    local merge_result
    if git -C "$scan_directory" merge-base --is-ancestor "$1" "$merge_base_ref" 2> /dev/null; then
        return 0
    fi
    $merge_tree_supported || return 1
    merge_result=$(git -C "$scan_directory" merge-tree --write-tree "$merge_base_ref" "$1" 2> /dev/null) || return 1
    [ "${merge_result%%$'\n'*}" == "$merge_base_tree" ]
}

# Scan results per repository, kept in parallel indexed arrays (bash 3.2 has no associative
# arrays) keyed by the repository's position in repo_list, so each repository is scanned once.
# Branch names cannot contain spaces, so the lists are space-separated.
#   scan_state         ok, or nobase (neither origin/DEFAULT_BRANCH nor DEFAULT_BRANCH exists)
#   scan_fetch_failed  "y" when git fetch failed (remote branches are then not examined)
#   scan_local         merged local branches (including the checked-out one)
#   scan_del_local     merged local branches that can be deleted (the checked-out one excluded)
#   scan_remote        merged branches on origin (names without the "origin/" prefix)
#   scan_current       the checked-out branch
scan_state=()
scan_fetch_failed=()
scan_local=()
scan_del_local=()
scan_remote=()
scan_current=()

scan_repo() { # scan_repo <index>: fetch, then find the merged branches of repo_list[index]
    local index="$1" ref name origin_head refs
    local locals="" del_locals="" remotes=""
    scan_directory="${repo_list[$index]}"
    scan_state[index]="ok"
    scan_fetch_failed[index]=""
    scan_local[index]=""
    scan_del_local[index]=""
    scan_remote[index]=""
    scan_current[index]=$(git -C "$scan_directory" branch --show-current)

    if ! git -C "$scan_directory" fetch --prune origin &> /dev/null; then
        scan_fetch_failed[index]="y"
    fi

    if git -C "$scan_directory" show-ref --verify --quiet "refs/remotes/origin/${DEFAULT_BRANCH}"; then
        merge_base_ref="refs/remotes/origin/${DEFAULT_BRANCH}"
    elif git -C "$scan_directory" show-ref --verify --quiet "refs/heads/${DEFAULT_BRANCH}"; then
        merge_base_ref="refs/heads/${DEFAULT_BRANCH}"
    else
        scan_state[index]="nobase"
        return 0
    fi
    merge_base_tree=$(git -C "$scan_directory" rev-parse "$merge_base_ref^{tree}")

    # origin's own HEAD branch is never listed (local ref, no network)
    origin_head=$(git -C "$scan_directory" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2> /dev/null)
    origin_head="${origin_head#origin/}"

    if $want_local; then
        refs=$(git -C "$scan_directory" for-each-ref --format='%(refname)' refs/heads)
        while IFS= read -r ref; do
            name="${ref#refs/heads/}"
            if [ -z "$name" ] || [ "$name" == "${DEFAULT_BRANCH}" ] || [ "$name" == "$origin_head" ]; then
                continue
            fi
            if is_merged "$ref"; then
                locals+="$name "
                if [ "$name" != "${scan_current[$index]}" ]; then
                    del_locals+="$name "
                fi
            fi
        done <<< "$refs"
    fi

    if $want_remote && [ -z "${scan_fetch_failed[$index]}" ]; then
        refs=$(git -C "$scan_directory" for-each-ref --format='%(refname)' refs/remotes/origin)
        while IFS= read -r ref; do
            name="${ref#refs/remotes/origin/}"
            if [ -z "$name" ] || [ "$name" == "HEAD" ] || [ "$name" == "${DEFAULT_BRANCH}" ] || [ "$name" == "$origin_head" ]; then
                continue
            fi
            if is_merged "$ref"; then
                remotes+="$name "
            fi
        done <<< "$refs"
    fi

    scan_local[index]="${locals% }"
    scan_del_local[index]="${del_locals% }"
    scan_remote[index]="${remotes% }"
}

# Print the merged branches of repository <index> as lines starting with <indent>.
print_merged_lines() { # print_merged_lines <indent> <index>
    local indent="$1" index="$2" name text="" remote_text=""
    for name in ${scan_local[$index]}; do
        text+="${text:+, }$name"
        if [ "$name" == "${scan_current[$index]}" ]; then
            text+=" (checked out, kept)"
        fi
    done
    for name in ${scan_remote[$index]}; do
        remote_text+="${remote_text:+, }origin/$name"
    done
    if [ -n "$text" ]; then
        echo "${indent}local:  $text"
    fi
    if [ -n "$remote_text" ]; then
        echo "${indent}remote: $remote_text"
    fi
}

# True when repository <index> has merged branches (listed, even if not deletable).
has_merged() {
    [ -n "${scan_local[$1]}${scan_remote[$1]}" ]
}

# True when repository <index> has a problem to report (no base branch, failed fetch).
has_problem() {
    [ "${scan_state[$1]}" == "nobase" ] || [ -n "${scan_fetch_failed[$1]}" ]
}

# Messages for the problems of one repository (printed under its header).
print_repo_problems() { # print_repo_problems <index>
    local directory_name
    directory_name=$(get_directory_name "${repo_list[$1]}")
    if [ "${scan_state[$1]}" == "nobase" ]; then
        echo "Neither origin/${DEFAULT_BRANCH} nor ${DEFAULT_BRANCH} exists in $directory_name. skipping..."
    fi
    if [ -n "${scan_fetch_failed[$1]}" ]; then
        echo "${red}Could not fetch origin in $directory_name${reset}"
    fi
}

# Listing: one block per repository that has merged branches or a problem.
list_repo() { # list_repo <index>
    local index="$1"
    if ! has_merged "$index" && ! has_problem "$index"; then
        mark_repo_skipped
        return 0
    fi
    print_repo_header "${repo_list[$index]}"
    print_repo_problems "$index"
    if has_merged "$index"; then
        found_merged="y"
        print_merged_lines "  " "$index"
    fi
    if [ -n "${scan_fetch_failed[$index]}" ]; then
        mark_repo_failed
    elif has_merged "$index"; then
        mark_repo_done
    else
        mark_repo_skipped
    fi
}

# Deletion (or its dry run) for repository <index>, from the cached scan.
delete_repo() { # delete_repo <index>
    local index="$1" name repo_failed="" deleted="" push_output remote_refs
    local directory="${repo_list[$index]}"
    if ! has_merged "$index" && ! has_problem "$index"; then
        mark_repo_skipped
        return 0
    fi
    print_repo_header "$directory"
    print_repo_problems "$index"
    if [ -n "${scan_fetch_failed[$index]}" ]; then
        repo_failed="y"
    fi
    if has_merged "$index"; then
        found_merged="y"
    fi

    for name in ${scan_local[$index]}; do
        if [ "$name" == "${scan_current[$index]}" ]; then
            echo "Kept checked-out branch $name (merged, not deleted)"
        fi
    done
    for name in ${scan_del_local[$index]}; do
        if $dry_run; then
            echo "Would delete local branch $name"
            deleted="y"
        elif git -C "$directory" branch -D -- "$name" &> /dev/null; then
            echo "Deleted local branch $name"
            deleted="y"
        else
            echo "${red}Could not delete local branch $name${reset}"
            repo_failed="y"
        fi
    done
    if [ -n "${scan_remote[$index]}" ]; then
        if $dry_run; then
            for name in ${scan_remote[$index]}; do
                echo "Would delete remote branch $name"
            done
            deleted="y"
        else
            remote_refs=()
            for name in ${scan_remote[$index]}; do
                remote_refs+=("refs/heads/$name")
            done
            if push_output=$(git -C "$directory" push origin --delete "${remote_refs[@]}" 2>&1); then
                for name in ${scan_remote[$index]}; do
                    echo "Deleted remote branch $name"
                done
                deleted="y"
            else
                echo "$push_output"
                echo "${red}Could not delete the remote branches in $(get_directory_name "$directory")${reset}"
                repo_failed="y"
            fi
        fi
    fi

    if [ -n "$repo_failed" ]; then
        mark_repo_failed
    elif [ -n "$deleted" ]; then
        mark_repo_done
    else
        mark_repo_skipped
    fi
}

# Scan phase: the only place that queries the repositories (fetch plus read-only checks), once each.
repos_done=0
repos_failed=0
repos_skipped=0
found_merged=""
delete_branch_count=0
delete_repo_count=0
for ((i = 0; i < ${#repo_list[@]}; i++)); do
    scan_repo "$i"
    repo_deletable=0
    for branch in ${scan_del_local[$i]} ${scan_remote[$i]}; do
        repo_deletable=$((repo_deletable + 1))
    done
    delete_branch_count=$((delete_branch_count + repo_deletable))
    if [ "$repo_deletable" -gt 0 ]; then
        delete_repo_count=$((delete_repo_count + 1))
    fi
done

if ! $delete_branches; then
    for ((i = 0; i < ${#repo_list[@]}; i++)); do
        list_repo "$i"
    done
else
    # Plan and confirmation. A dry run never asks: its would-delete lines are the plan.
    if ! $dry_run && [ "$delete_branch_count" -gt 0 ]; then
        echo
        echo "Will delete these merged branches:"
        for ((i = 0; i < ${#repo_list[@]}; i++)); do
            if [ -n "${scan_del_local[$i]}${scan_remote[$i]}" ]; then
                echo "  $(get_directory_name "${repo_list[$i]}")"
                print_merged_lines "    " "$i"
            fi
        done
        echo
        branch_noun="branches"
        repo_noun="repositories"
        if [ "$delete_branch_count" -eq 1 ]; then
            branch_noun="branch"
        fi
        if [ "$delete_repo_count" -eq 1 ]; then
            repo_noun="repository"
        fi
        confirm_or_exit "Delete $delete_branch_count $branch_noun in $delete_repo_count $repo_noun?"
    fi
    for ((i = 0; i < ${#repo_list[@]}; i++)); do
        delete_repo "$i"
    done
fi

if [ -z "$found_merged" ]; then
    echo
    echo "No merged branches found"
fi

finish_run
