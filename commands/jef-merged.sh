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
    "|include-empty|include_empty|With --delete: also delete branches that have no commits of their own"
)
cli_value_flags=(
    "m|repo|repo_filter|REPOS||list|Only these repositories: -m a,b or -m \"a b\" or -m a -m b (also --repo a, --repo=a,b)"
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

# Protected branches: PROTECTED_BRANCHES (comma separated names or glob patterns) are never
# listed or deleted; the default branch and origin's HEAD branch always are protected.
# An entry containing spaces (the old space separated form) is an error: exit 2 before any work.
parse_env_list PROTECTED_BRANCHES "$PROTECTED_BRANCHES" || exit 2
protected_patterns=("${env_list_items[@]}")
protected_text="default branch only"
if [ "${#protected_patterns[@]}" -gt 0 ]; then
    protected_text="$(IFS=,; echo "${protected_patterns[*]}" | sed 's/,/, /g')"
fi

# --include-empty only matters when deleting
empties_deleted=false
if $delete_branches && $include_empty; then
    empties_deleted=true
fi

# Repositories: all of them, or only those named with -m (narrowed by list_repos)
list_repos

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
echo "Protected: ${green}$protected_text${reset}"

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
# or merging it would change nothing (what a squash or rebase merge leaves behind). Sets
# merged_by_ancestor to true or false (only meaningful when it succeeds).
is_merged() {
    local merge_result
    merged_by_ancestor=false
    if git -C "$scan_directory" merge-base --is-ancestor "$1" "$merge_base_ref" 2> /dev/null; then
        merged_by_ancestor=true
        return 0
    fi
    $merge_tree_supported || return 1
    merge_result=$(git -C "$scan_directory" merge-tree --write-tree "$merge_base_ref" "$1" 2> /dev/null) || return 1
    [ "${merge_result%%$'\n'*}" == "$merge_base_tree" ]
}

# Succeeds when the branch name $1 matches one of the PROTECTED_BRANCHES patterns.
is_protected() {
    local pattern
    [ "${#protected_patterns[@]}" -gt 0 ] || return 1
    for pattern in "${protected_patterns[@]}"; do
        # shellcheck disable=SC2254 # the pattern is meant to be a glob
        case "$1" in $pattern) return 0 ;; esac
    done
    return 1
}

# Temp file holding the first-parent history of the base ref (one sha per line), made on first
# use per repository. A branch whose tip is in it has no commits of its own. Removed after each
# scan and by the EXIT trap (merged does not use parallel_run, so the trap is not taken).
first_parent_file=""
cleanup_first_parent_file() {
    if [ -n "$first_parent_file" ]; then
        rm -f "$first_parent_file"
        first_parent_file=""
    fi
}
trap cleanup_first_parent_file EXIT

# Succeeds when the commit $1 is on the first-parent history of the base ref.
is_empty_tip() {
    if [ -z "$first_parent_file" ]; then
        first_parent_file=$(mktemp "${TMPDIR:-/tmp}/jef.XXXXXX") || exit 1
        git -C "$scan_directory" rev-list --first-parent "$merge_base_ref" > "$first_parent_file" 2> /dev/null
    fi
    grep -qxF -- "$1" "$first_parent_file"
}

# Scan results per repository, kept in parallel indexed arrays (bash 3.2 has no associative
# arrays) keyed by the repository's position in repo_list, so each repository is scanned once.
# Branch names cannot contain spaces, so the lists are space-separated; the "padded" lists
# start and end with a space so that " name " can be searched for.
#   scan_state         ok, or nobase (neither origin/DEFAULT_BRANCH nor DEFAULT_BRANCH exists)
#   scan_fetch_failed  "y" when git fetch failed (remote branches are then not examined)
#   scan_local         merged local branches that are not protected (including kept ones)
#   scan_local_shas    their commits at scan time, in the same order
#   scan_del_local     the ones that can be deleted (not checked out in a worktree, and not
#                      empty unless --include-empty)
#   scan_remote        merged branches on origin (names without the "origin/" prefix)
#   scan_remote_shas   their commits at scan time, in the same order
#   scan_del_remote    the ones that can be deleted (empty ones only with --include-empty)
#   scan_busy          padded: local branches checked out in any worktree
#   scan_kept_empty_local / scan_kept_empty_remote  padded: no-commit branches that are kept
scan_state=()
scan_fetch_failed=()
scan_local=()
scan_local_shas=()
scan_del_local=()
scan_remote=()
scan_remote_shas=()
scan_del_remote=()
scan_busy=()
scan_kept_empty_local=()
scan_kept_empty_remote=()

# lookup_sha <names> <shas> <name>: the sha stored at the position of <name> in the lists.
lookup_sha() {
    local names shas i
    read -ra names <<< "$1"
    read -ra shas <<< "$2"
    for ((i = 0; i < ${#names[@]}; i++)); do
        if [ "${names[$i]}" == "$3" ]; then
            echo "${shas[$i]}"
            return 0
        fi
    done
    return 1
}

scan_repo() { # scan_repo <index>: fetch, then find the merged branches of repo_list[index]
    local index="$1" ref name sha origin_head refs line busy=" "
    local locals="" local_shas="" del_locals="" remotes="" remote_shas="" del_remotes=""
    local kept_empty_local=" " kept_empty_remote=" " tip_empty
    scan_directory="${repo_list[$index]}"
    scan_state[index]="ok"
    scan_fetch_failed[index]=""
    scan_local[index]=""
    scan_local_shas[index]=""
    scan_del_local[index]=""
    scan_remote[index]=""
    scan_remote_shas[index]=""
    scan_del_remote[index]=""
    scan_busy[index]=" "
    scan_kept_empty_local[index]=" "
    scan_kept_empty_remote[index]=" "

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
        # branches checked out in any worktree (the main one included) are never deleted
        while IFS= read -r line; do
            case "$line" in
            "branch refs/heads/"*) busy+="${line#branch refs/heads/} " ;;
            esac
        done <<< "$(git -C "$scan_directory" worktree list --porcelain 2> /dev/null)"
        refs=$(git -C "$scan_directory" for-each-ref --format='%(objectname) %(refname)' refs/heads)
        while read -r sha ref; do
            name="${ref#refs/heads/}"
            if [ -z "$name" ] || [ "$name" == "${DEFAULT_BRANCH}" ] || [ "$name" == "$origin_head" ] || is_protected "$name"; then
                continue
            fi
            if is_merged "$ref"; then
                locals+="$name "
                local_shas+="$sha "
                tip_empty=false
                if $merged_by_ancestor && is_empty_tip "$sha"; then
                    tip_empty=true
                fi
                if [[ "$busy" == *" $name "* ]]; then
                    : # checked out somewhere: kept
                elif $tip_empty && ! $empties_deleted; then
                    kept_empty_local+="$name "
                else
                    del_locals+="$name "
                fi
            fi
        done <<< "$refs"
    fi

    if $want_remote && [ -z "${scan_fetch_failed[$index]}" ]; then
        refs=$(git -C "$scan_directory" for-each-ref --format='%(objectname) %(refname)' refs/remotes/origin)
        while read -r sha ref; do
            name="${ref#refs/remotes/origin/}"
            if [ -z "$name" ] || [ "$name" == "HEAD" ] || [ "$name" == "${DEFAULT_BRANCH}" ] || [ "$name" == "$origin_head" ] || is_protected "$name"; then
                continue
            fi
            if is_merged "$ref"; then
                remotes+="$name "
                remote_shas+="$sha "
                tip_empty=false
                if $merged_by_ancestor && is_empty_tip "$sha"; then
                    tip_empty=true
                fi
                if $tip_empty && ! $empties_deleted; then
                    kept_empty_remote+="$name "
                else
                    del_remotes+="$name "
                fi
            fi
        done <<< "$refs"
    fi
    cleanup_first_parent_file

    scan_local[index]="${locals% }"
    scan_local_shas[index]="${local_shas% }"
    scan_del_local[index]="${del_locals% }"
    scan_remote[index]="${remotes% }"
    scan_remote_shas[index]="${remote_shas% }"
    scan_del_remote[index]="${del_remotes% }"
    scan_busy[index]="$busy"
    scan_kept_empty_local[index]="$kept_empty_local"
    scan_kept_empty_remote[index]="$kept_empty_remote"
}

# Results of the last delete_repo, padded lists of branch names (used by print_merged_tree):
#   res_failed_*   could not be deleted (red)
#   res_changed_*  moved since the scan, so the compare-and-delete kept them (yellow)
# res_push_output is git push's output when a remote deletion failed.
res_failed_local=" "
res_changed_local=" "
res_failed_remote=" "
res_changed_remote=" "
res_push_output=""

# The coloured note after a branch: branch_note <index> <local|remote> <name> [result]
branch_note() {
    local index="$1" kind="$2" name="$3" failed changed
    if [ -n "${4:-}" ]; then
        if [ "$kind" == "local" ]; then
            failed="$res_failed_local"
            changed="$res_changed_local"
        else
            failed="$res_failed_remote"
            changed="$res_changed_remote"
        fi
        if [[ "$failed" == *" $name "* ]]; then
            echo " ${red}(could not delete)${reset}"
            return 0
        elif [[ "$changed" == *" $name "* ]]; then
            echo " ${yellow}(changed since scan, kept)${reset}"
            return 0
        fi
    fi
    if [ "$kind" == "local" ] && [[ "${scan_busy[$index]}" == *" $name "* ]]; then
        echo " ${yellow}(checked out, kept)${reset}"
    elif [ "$kind" == "local" ] && [[ "${scan_kept_empty_local[$index]}" == *" $name "* ]]; then
        echo " ${yellow}(no commits, kept)${reset}"
    elif [ "$kind" == "remote" ] && [[ "${scan_kept_empty_remote[$index]}" == *" $name "* ]]; then
        echo " ${yellow}(no commits, kept)${reset}"
    fi
}

# Number of whitespace separated words in <list> (branch names contain no spaces).
count_words() { # count_words <list>
    local word n=0
    for word in $1; do
        n=$((n + 1))
    done
    echo "$n"
}

# Grand total line, "<indent>Total: N branches in M repositories", counting the branches shown in the
# blocks of the repositories that have merged branches (or, with a second argument, deletable ones).
# Prints nothing when there are none.
print_merged_total() { # print_merged_total <indent> [deletable only]
    local i n=0 repos=0 shown branch_noun="branches" repo_noun="repositories"
    for ((i = 0; i < ${#repo_list[@]}; i++)); do
        if [ -n "${2:-}" ] && ! has_deletable "$i"; then
            continue
        fi
        shown=$(( $(count_words "${scan_local[$i]}") + $(count_words "${scan_remote[$i]}") ))
        if [ "$shown" -gt 0 ]; then
            n=$((n + shown))
            repos=$((repos + 1))
        fi
    done
    if [ "$n" -eq 0 ]; then
        return 0 # nothing to show: no total
    fi
    if [ "$n" -eq 1 ]; then
        branch_noun="branch"
    fi
    if [ "$repos" -eq 1 ]; then
        repo_noun="repository"
    fi
    echo "$1Total: $n $branch_noun in $repos $repo_noun"
}

# Print repository <index> as a bulleted block indented by <indent>: its name, then a "local" and a
# "remote" group (each only when it has branches) with one "- branch" line per branch. With a third
# argument (any value) the repository's problems are printed under its name; with a fourth the
# outcome of the deletion (res_* lists) is shown as well.
print_merged_tree() { # print_merged_tree <indent> <index> [problems] [result]
    local indent="$1" index="$2" name count local_count remote_count
    local_count=$(count_words "${scan_local[$index]}")
    remote_count=$(count_words "${scan_remote[$index]}")
    count=""
    if [ $((local_count + remote_count)) -gt 0 ]; then
        count=" ($((local_count + remote_count)))"
    fi
    echo "${indent}${green}$(get_directory_name "${repo_list[$index]}")${count}${reset}"
    if [ -n "${3:-}" ]; then
        print_repo_problems "$index" "${indent}  "
    fi
    if [ -n "${scan_local[$index]}" ]; then
        echo "${indent}  ${magenta}local (${local_count})${reset}"
        for name in ${scan_local[$index]}; do
            echo "${indent}    - ${cyan}$name${reset}$(branch_note "$index" local "$name" "${4:-}")"
        done
    fi
    if [ -n "${scan_remote[$index]}" ]; then
        echo "${indent}  ${magenta}remote (${remote_count})${reset}"
        for name in ${scan_remote[$index]}; do
            echo "${indent}    - ${cyan}origin/$name${reset}$(branch_note "$index" remote "$name" "${4:-}")"
        done
        if [ -n "${4:-}" ] && [ -n "$res_push_output" ]; then
            while IFS= read -r name; do
                echo "${indent}      $name"
            done <<< "$res_push_output"
        fi
    fi
}

# True when repository <index> has merged branches (listed, even if not deletable).
has_merged() {
    [ -n "${scan_local[$1]}${scan_remote[$1]}" ]
}

# True when repository <index> has branches that would be deleted.
has_deletable() {
    [ -n "${scan_del_local[$1]}${scan_del_remote[$1]}" ]
}

# True when repository <index> has a problem to report (no base branch, failed fetch).
has_problem() {
    [ "${scan_state[$1]}" == "nobase" ] || [ -n "${scan_fetch_failed[$1]}" ]
}

# Messages for the problems of one repository (printed under its header or name).
print_repo_problems() { # print_repo_problems <index> [indent]
    local directory_name indent="${2:-}"
    directory_name=$(get_directory_name "${repo_list[$1]}")
    if [ "${scan_state[$1]}" == "nobase" ]; then
        echo "${indent}Neither origin/${DEFAULT_BRANCH} nor ${DEFAULT_BRANCH} exists in $directory_name. skipping..."
    fi
    if [ -n "${scan_fetch_failed[$1]}" ]; then
        echo "${indent}${red}Could not fetch origin in $directory_name${reset}"
    fi
}

# Listing: one block per repository that has merged branches or a problem, each after a blank line.
list_repo() { # list_repo <index>
    local index="$1"
    if ! has_merged "$index" && ! has_problem "$index"; then
        mark_repo_skipped
        return 0
    fi
    echo
    print_merged_tree "" "$index" problems
    if has_merged "$index"; then
        found_merged="y"
    fi
    if [ -n "${scan_fetch_failed[$index]}" ]; then
        mark_repo_failed
    elif has_merged "$index"; then
        mark_repo_done
    else
        mark_repo_skipped
    fi
}

# Dry run of the deletion for repository <index>: its block (with problems) in the plan list.
dry_run_repo() { # dry_run_repo <index> <is first block: y or "">
    local index="$1"
    if ! has_merged "$index" && ! has_problem "$index"; then
        mark_repo_skipped
        return 0
    fi
    if [ -z "$2" ]; then
        echo
    fi
    print_merged_tree "  " "$index" problems
    if has_merged "$index"; then
        found_merged="y"
    fi
    if [ -n "${scan_fetch_failed[$index]}" ]; then
        mark_repo_failed
    elif has_deletable "$index"; then
        mark_repo_done
    else
        mark_repo_skipped
    fi
}

# Deletion for repository <index>, from the cached scan, as a compare-and-delete: every branch is
# only removed if it still points at the commit recorded by the scan. Local branches use
# git update-ref -d <ref> <sha>; the remote ones go in one git push with a --force-with-lease per
# branch, then git ls-remote tells which are really gone. A branch that moved since the scan is
# kept and reported as such; one that could not be deleted is marked in red. Prints the repository
# as a bulleted block like the listing.
delete_repo() { # delete_repo <index> <is first block: y or "">
    local index="$1" name sha current remote_now lsha lref
    local repo_failed="" deleted="" push_status=0 ls_status=0
    local directory="${repo_list[$index]}" remote_state="" push_args remote_refs
    res_failed_local=" "
    res_changed_local=" "
    res_failed_remote=" "
    res_changed_remote=" "
    res_push_output=""
    if ! has_merged "$index" && ! has_problem "$index"; then
        mark_repo_skipped
        return 0
    fi
    if [ -n "${scan_fetch_failed[$index]}" ]; then
        repo_failed="y"
    fi
    if has_merged "$index"; then
        found_merged="y"
    fi

    for name in ${scan_del_local[$index]}; do
        sha=$(lookup_sha "${scan_local[$index]}" "${scan_local_shas[$index]}" "$name")
        if git -C "$directory" update-ref -d "refs/heads/$name" "$sha" &> /dev/null; then
            git -C "$directory" config --remove-section "branch.$name" &> /dev/null || true # what git branch -D also removes
            deleted="y"
        else
            current=$(git -C "$directory" rev-parse --verify --quiet "refs/heads/$name" 2> /dev/null)
            if [ -z "$current" ]; then
                deleted="y" # already gone
            elif [ "$current" != "$sha" ]; then
                res_changed_local+="$name "
            else
                res_failed_local+="$name "
                repo_failed="y"
            fi
        fi
    done

    if [ -n "${scan_del_remote[$index]}" ]; then
        push_args=()
        remote_refs=()
        for name in ${scan_del_remote[$index]}; do
            sha=$(lookup_sha "${scan_remote[$index]}" "${scan_remote_shas[$index]}" "$name")
            push_args+=("--force-with-lease=refs/heads/$name:$sha")
            remote_refs+=("refs/heads/$name")
        done
        res_push_output=$(git -C "$directory" push origin --delete "${push_args[@]}" "${remote_refs[@]}" 2>&1) || push_status=$?
        # a push can reject some branches and accept others: ask origin which are gone
        remote_state=$(git -C "$directory" ls-remote origin "${remote_refs[@]}" 2> /dev/null) || ls_status=$?
        for name in ${scan_del_remote[$index]}; do
            sha=$(lookup_sha "${scan_remote[$index]}" "${scan_remote_shas[$index]}" "$name")
            if [ "$ls_status" -ne 0 ]; then
                if [ "$push_status" -eq 0 ]; then
                    deleted="y"
                else
                    res_failed_remote+="$name "
                    repo_failed="y"
                fi
                continue
            fi
            remote_now=""
            while read -r lsha lref; do
                if [ "$lref" == "refs/heads/$name" ]; then
                    remote_now="$lsha"
                fi
            done <<< "$remote_state"
            if [ -z "$remote_now" ]; then
                deleted="y"
            elif [ "$remote_now" != "$sha" ]; then
                res_changed_remote+="$name "
            else
                res_failed_remote+="$name "
                repo_failed="y"
            fi
        done
        if [ "$res_failed_remote" == " " ]; then
            res_push_output="" # nothing failed: the push output (lease rejections) is just noise
        fi
    fi

    if [ -z "$2" ]; then
        echo
    fi
    print_merged_tree "  " "$index" problems result

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
    for branch in ${scan_del_local[$i]} ${scan_del_remote[$i]}; do
        repo_deletable=$((repo_deletable + 1))
    done
    delete_branch_count=$((delete_branch_count + repo_deletable))
    if [ "$repo_deletable" -gt 0 ]; then
        delete_repo_count=$((delete_repo_count + 1))
    fi
done

if ! $delete_branches; then
    print_merged_total ""
    for ((i = 0; i < ${#repo_list[@]}; i++)); do
        list_repo "$i"
    done
else
    if $dry_run; then
        # A dry run prints the plan as the same bulleted list and never asks.
        echo
        echo "Would delete these merged branches:"
        print_merged_total "  "
        first_block="y"
        for ((i = 0; i < ${#repo_list[@]}; i++)); do
            dry_run_repo "$i" "$first_block"
            if has_merged "$i" || has_problem "$i"; then
                first_block=""
            fi
        done
    elif [ "$delete_branch_count" -gt 0 ]; then
        # Plan and confirmation.
        echo
        echo "Will delete these merged branches:"
        print_merged_total "  " deletable
        plan_blocks=0
        for ((i = 0; i < ${#repo_list[@]}; i++)); do
            if has_deletable "$i"; then
                if [ "$plan_blocks" -gt 0 ]; then
                    echo
                fi
                print_merged_tree "  " "$i"
                plan_blocks=$((plan_blocks + 1))
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
    if ! $dry_run; then
        # The plan already ends with a blank line unless a question followed it
        if ! { [ "$delete_branch_count" -gt 0 ] && $assume_yes; }; then
            echo
        fi
        echo "Deleted merged branches:"
        print_merged_total "  "
        first_block="y"
        for ((i = 0; i < ${#repo_list[@]}; i++)); do
            delete_repo "$i" "$first_block"
            if has_merged "$i" || has_problem "$i"; then
                first_block=""
            fi
        done
    fi
fi

if [ -z "$found_merged" ]; then
    echo
    echo "No merged branches found"
fi

finish_run
