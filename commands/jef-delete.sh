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
cli_extra_flags=(
    "r|delete-remote-branch|delete_remote_branch|Also delete the branch on the remote"
    "n|dry-run|dry_run|Show what would happen without changing anything"
    "y|yes|assume_yes|Delete without asking for confirmation"
)
parse_options "$@"
require_args 1

source "$script_location/lib/common.sh"
source "$script_location/lib/confirm.sh"

branch_to_delete="${cli_positional[0]}"

if ! is_valid_branch_name "$branch_to_delete"; then
    echo "'$branch_to_delete' is not a valid branch name"
    exit 2
fi

echo "Target directory: ${green}$target_directory${reset}"
echo "Branch to delete: ${green}$branch_to_delete${reset}"
echo "Clear proxy: ${green}$clear_proxy${reset}"
echo "Delete remote branch: ${green}$delete_remote_branch${reset}"
echo "Dry run: ${green}$dry_run${reset}"

source "$script_location/lib/clear-proxy.sh"

found="" # flag to check if branch is found in any child_directory of the $target_directory

# Read-only prediction of what deleting the branch would do in one repository.
# Shared by the confirmation plan, --dry-run and the real deletion, so they cannot disagree.
# Sets: plan_local (local branch will be deleted), plan_switch (must leave it first),
# plan_remote (remote branch will be deleted), plan_exists (branch exists locally or on
# origin), plan_failed (the repository will fail), plan_local_note / plan_remote_note
# (why a deletion is refused: the message printed) and plan_local_reason / plan_remote_reason
# (short wording for the confirmation plan).
plan_repo() {
    local child_directory="$1" current_branch exit_code default_branch_in_remote
    plan_local="" plan_switch="" plan_remote="" plan_exists="" plan_failed=""
    plan_local_note="" plan_remote_note="" plan_local_reason="" plan_remote_reason=""
    plan_local_blocked=""

    if git -C "$child_directory" show-ref --verify --quiet "refs/heads/$branch_to_delete"; then # Check if branch exists locally
        plan_exists="y"
        plan_local="y"
        current_branch=$(git -C "$child_directory" branch --show-current)
        if [ "$current_branch" == "$branch_to_delete" ]; then
            # Predict the switch without doing it: the default branch must exist and differ from the branch
            if [ "$branch_to_delete" != "${DEFAULT_BRANCH}" ] \
            && git -C "$child_directory" show-ref --verify --quiet "refs/heads/${DEFAULT_BRANCH}"; then
                plan_switch="y"
            else
                plan_local=""
                plan_local_blocked="y"
                plan_failed="y"
                plan_local_note="Could not checkout to default branch in $child_directory. skipping..."
                plan_local_reason="cannot leave the branch"
            fi
        fi
    fi

    if $delete_remote_branch && [ -z "$plan_local_blocked" ]; then
        git -C "$child_directory" ls-remote --exit-code --heads origin "$branch_to_delete" &> /dev/null # check if remote branch exists and set exit code to status variable "$?"
        exit_code="$?"
        if [ "$exit_code" == "0" ]; then # 0 = exists, 2 = does not exist
            plan_exists="y"
            # Prefer the local origin/HEAD ref (no network); fall back to asking the remote
            default_branch_in_remote=$(git -C "$child_directory" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2> /dev/null)
            default_branch_in_remote="${default_branch_in_remote#origin/}"
            if [ -z "$default_branch_in_remote" ]; then
                default_branch_in_remote=$(git -C "$child_directory" remote show origin | sed -n '/HEAD branch/s/.*: //p')
            fi
            if [ "$branch_to_delete" == "${default_branch_in_remote}" ]; then
                plan_remote_note="$branch_to_delete is the default branch in $child_directory. It cannot be deleted."
                plan_remote_reason="is the remote default branch"
            else
                plan_remote="y"
            fi
        elif [ "$exit_code" != "2" ]; then # the remote could not be queried
            plan_remote_note="Could not query origin in $child_directory"
            plan_remote_reason="could not query origin"
            plan_failed="y"
        fi
    fi
}

# Plan results per repository, kept in parallel indexed arrays (bash 3.2 has no associative
# arrays) keyed by the repository's position in repo_list, so each remote is queried once.
cached_plan_names="local switch remote exists failed local_note remote_note local_reason remote_reason"
cache_plan() { # cache_plan <index>: store the current plan_* values
    local n
    for n in $cached_plan_names; do
        eval "cached_${n}[$1]=\"\$plan_$n\""
    done
}
load_plan() { # load_plan <index>: restore the plan_* values
    local n
    for n in $cached_plan_names; do
        eval "plan_$n=\"\${cached_${n}[$1]}\""
    done
}

# True when the repository has something to delete or a message to show.
plan_is_relevant() {
    [ -n "$plan_exists$plan_local_note$plan_remote_note" ]
}

# Records one plan line per relevant repository (from the current plan_* values) and
# counts the repositories where something will be deleted.
plan_lines=()
plan_deletable=0
add_plan_line() {
    local what="" note="" colour="$green" name
    plan_is_relevant || return 0
    name=$(get_directory_name "$1")
    if [ -n "$plan_local" ] && [ -n "$plan_remote" ]; then
        what="local and remote (origin)"
    elif [ -n "$plan_local" ]; then
        what="local"
    elif [ -n "$plan_remote" ]; then
        what="remote (origin)"
    fi
    note="${plan_local_reason:-$plan_remote_reason}"
    if [ -n "$what" ]; then
        plan_deletable=$((plan_deletable + 1))
        if [ -n "$note" ]; then
            what="$what; remote skipped: $note"
            colour="$yellow"
        fi
    elif [ -n "$plan_failed" ]; then
        what="will fail: $note"
        colour="$red"
    else
        what="skipped: $note"
        colour="$yellow"
    fi
    plan_lines+=("  $name: $colour$what$reset")
}

# Print the plan and, unless --yes, ask for confirmation. Exits 1 (declined) or 2 (no terminal).
confirm_deletion() {
    local line noun="repositories"
    echo
    if $delete_remote_branch; then
        echo "Will delete branch '$branch_to_delete':"
    else
        echo "Will delete branch '$branch_to_delete' (local only; add -r to also delete on origin):"
    fi
    for line in "${plan_lines[@]}"; do
        echo -e "$line"
    done
    echo
    if [ "$plan_deletable" -eq 1 ]; then
        noun="repository"
    fi
    confirm_or_exit "Delete branch '$branch_to_delete' in $plan_deletable $noun?"
}

delete_in_repo() {
    local child_directory="$1" child_directory_name deleted repo_failed local_failed current_branch

    child_directory_name=$(get_directory_name "$child_directory")
    if ! plan_is_relevant; then # branch absent: nothing to do and nothing to say
        mark_repo_skipped
        return 0
    fi
    print_repo_header "$child_directory"

    deleted="" # what was (or, in a dry run, would be) deleted: local and/or remote
    local_failed=""
    repo_failed="$plan_failed"
    if [ -n "$plan_exists" ]; then
        found="y"
    fi

    if [ -n "$plan_local_note" ]; then
        echo "$plan_local_note"
        local_failed="y"
    elif [ -n "$plan_local" ]; then
        if $dry_run; then
            if [ -n "$plan_switch" ]; then
                echo "Would switch to ${DEFAULT_BRANCH}"
            fi
            echo "Would delete local branch $branch_to_delete"
            deleted+="local"
        else
            if [ -n "$plan_switch" ]; then
                git -C "$child_directory" checkout "${DEFAULT_BRANCH}" -- &> /dev/null
            fi
            current_branch=$(git -C "$child_directory" branch --show-current)
            if [ "$current_branch" == "$branch_to_delete" ]; then
                echo "Could not checkout to default branch in $child_directory. skipping..."
                local_failed="y"
            elif git -C "$child_directory" branch -D -- "$branch_to_delete"; then
                deleted+="local"
            else
                local_failed="y"
            fi
        fi
        if [ -n "$local_failed" ]; then
            repo_failed="y"
        fi
    fi

    if [ -z "$local_failed" ]; then
        if [ -n "$plan_remote_note" ]; then
            echo "$plan_remote_note"
        elif [ -n "$plan_remote" ]; then
            if $dry_run; then
                echo "Would delete remote branch $branch_to_delete"
            elif ! git -C "$child_directory" push origin --delete "$branch_to_delete"; then
                repo_failed="y"
                plan_remote=""
            fi
            if [ -n "$plan_remote" ]; then
                if [ -n "$deleted" ]; then
                    deleted+=" & "
                fi
                deleted+="remote"
            fi
        fi
    fi

    if [ -n "$deleted" ] && ! $dry_run; then
        echo "$deleted deleted: ${green}$child_directory_name${reset}" # display child_directory name
    fi

    if [ -n "$repo_failed" ]; then
        mark_repo_failed
    elif [ -n "$deleted" ]; then
        mark_repo_done
    else
        mark_repo_skipped
    fi
}

# Plan phase: the only place that queries the repositories (read-only), once each.
list_repos
repos_done=0
repos_failed=0
repos_skipped=0
for ((i = 0; i < ${#repo_list[@]}; i++)); do
    plan_repo "${repo_list[$i]}"
    cache_plan "$i"
    add_plan_line "${repo_list[$i]}"
done

# Confirmation: dry run never asks; with nothing deletable the run below only prints messages.
if ! $dry_run; then
    if [ "$plan_deletable" -gt 0 ]; then
        confirm_deletion
    fi
fi

for ((i = 0; i < ${#repo_list[@]}; i++)); do
    load_plan "$i"
    delete_in_repo "${repo_list[$i]}"
done

if [ -z "$found" ]; then
    echo "Branch not found in any repository"
fi

finish_run
