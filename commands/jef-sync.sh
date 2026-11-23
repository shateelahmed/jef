#!/bin/bash
# shellcheck disable=SC2154,SC2034 # colour variables come from lib/terminal-color-codes.sh; cli_* are read by lib/cli.sh

# Pull the default branch, then bring it into every other local branch and push them, in every repository

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

cli_name="sync"
cli_description="Pull the default branch and bring it into every other local branch, in every repository"
cli_positionals=""
cli_accepts_proxy=true
cli_extra_flags=(
    "r|rebase|use_rebase|Rebase the branches onto the default branch and force-push them (default: merge)"
    "n|dry-run|dry_run|Show what would happen without changing anything"
    "y|yes|assume_yes|Sync without asking for confirmation"
)
cli_value_flags=(
    "m|repo|repo_filter|REPOS||list|Only these repositories (comma or space separated, repeatable)"
    "j|jobs|parallel_jobs|N||posint|Sync up to N repositories at once (default: all of them)"
)
parse_options "$@"
require_args 0

source "$script_location/lib/common.sh"
source "$script_location/lib/confirm.sh"

if [ -z "${DEFAULT_BRANCH:-}" ]; then
    echo "DEFAULT_BRANCH is not set. Set it in the .env file, e.g. DEFAULT_BRANCH=main"
    exit 1
fi

if $use_rebase; then
    mode_text="rebase"
else
    mode_text="merge"
fi

echo "Target directory: ${green}$target_directory${reset}"
echo "Default branch: ${green}$DEFAULT_BRANCH${reset}"
echo "Mode: ${green}$mode_text${reset}"
echo "Repositories: ${green}${repo_filter:-all}${reset}"
echo "Jobs: ${green}${parallel_jobs:-all}${reset}"
echo "Clear proxy: ${green}$clear_proxy${reset}"
echo "Dry run: ${green}$dry_run${reset}"

source "$script_location/lib/clear-proxy.sh"

# Repositories to sync: all of them, or the ones named with -m (in the usual order)
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
parallel_use_repo_list=true # parallel_run must run exactly these repositories

# Every repository at once unless -j caps it
if [ -z "$parallel_jobs" ]; then
    parallel_jobs=${#repo_list[@]}
    if [ "$parallel_jobs" -lt 1 ]; then
        parallel_jobs=1
    fi
fi

# Plan results per repository, kept in parallel indexed arrays (bash 3.2 has no associative
# arrays) keyed by the repository's position in repo_list. Only local refs are read here.
#   plan_state     "nodefault" (no local default branch) or "ready"
#   plan_branches  the local branches other than the default one, alphabetical, space separated
#                  (branch names cannot contain spaces)
#   plan_count     how many of them
plan_state=()
plan_branches=()
plan_count=()

plan_repo() { # plan_repo <index>: read-only look at repo_list[index]
    local index="$1" directory="${repo_list[$1]}" ref name
    plan_state[index]="ready"
    plan_branches[index]=""
    plan_count[index]=0
    if ! git -C "$directory" show-ref --verify --quiet "refs/heads/$DEFAULT_BRANCH"; then
        plan_state[index]="nodefault"
        return 0
    fi
    while read -r ref; do
        name="${ref#refs/heads/}"
        if [ -z "$name" ] || [ "$name" == "$DEFAULT_BRANCH" ]; then
            continue
        fi
        plan_branches[index]+="$name "
        plan_count[index]=$((plan_count[index] + 1))
    done <<< "$(git -C "$directory" for-each-ref --format='%(refname)' refs/heads)"
}

commit_text() { # commit_text <count>
    if [ "$1" -eq 1 ]; then
        echo "1 commit"
    else
        echo "$1 commits"
    fi
}

# plural_text <count> <singular> <plural>: "1 branch", "4 branches"
plural_text() {
    if [ "$1" -eq 1 ]; then
        echo "1 $2"
    else
        echo "$1 $3"
    fi
}

# Plan phase: the only place that reads the repositories before the run (no network).
repos_done=0
repos_failed=0
repos_skipped=0
ready_repos=0
ready_branches=0
for ((i = 0; i < ${#repo_list[@]}; i++)); do
    plan_repo "$i"
    if [ "${plan_state[$i]}" == "ready" ]; then
        ready_repos=$((ready_repos + 1))
        ready_branches=$((ready_branches + plan_count[i]))
    fi
done

# Plan tree: "<indent>Total: N branches in M repositories", a blank line, then one block per repository
# (name and branch count, one "- branch" line per branch), separated by blank lines. A repository
# without the local default branch shows a note and is not counted.
print_sync_plan() { # print_sync_plan <indent>
    local indent="$1" i branch_name total=0 repos=0
    for ((i = 0; i < ${#repo_list[@]}; i++)); do
        if [ "${plan_state[$i]}" == "ready" ] && [ "${plan_count[$i]}" -gt 0 ]; then
            total=$((total + plan_count[i]))
            repos=$((repos + 1))
        fi
    done
    echo "$indent""Total: $(plural_text "$total" branch branches) in $(plural_text "$repos" repository repositories)"
    for ((i = 0; i < ${#repo_list[@]}; i++)); do
        echo
        if [ "${plan_state[$i]}" == "nodefault" ]; then
            echo "$indent${green}$(get_directory_name "${repo_list[$i]}")${reset}"
            echo "$indent  ${yellow}no $DEFAULT_BRANCH, skipped${reset}"
        elif [ "${plan_count[$i]}" -eq 0 ]; then
            echo "$indent${green}$(get_directory_name "${repo_list[$i]}")${reset}"
            echo "$indent  ${yellow}no other branches${reset}"
        else
            echo "$indent${green}$(get_directory_name "${repo_list[$i]}") (${plan_count[$i]})${reset}"
            for branch_name in ${plan_branches[$i]}; do
                echo "$indent  - ${cyan}$branch_name${reset}"
            done
        fi
    done
}

if $use_rebase; then
    plan_title="rebase onto $DEFAULT_BRANCH, then force-push where on origin"
else
    plan_title="merge $DEFAULT_BRANCH into each, then push where on origin"
fi

if $dry_run; then
    echo
    echo "Would sync these branches ($plan_title):"
    print_sync_plan "  "
    for ((i = 0; i < ${#repo_list[@]}; i++)); do
        if [ "${plan_state[$i]}" == "nodefault" ]; then
            mark_repo_skipped
        else
            mark_repo_done
        fi
    done
    finish_run
    exit 0
fi

# Plan and confirmation: always asked (--yes skips it); with nothing to sync there is nothing to ask about.
if [ "$ready_repos" -gt 0 ]; then
    echo
    echo "Will sync these branches ($plan_title):"
    print_sync_plan "  "
    echo
    if $use_rebase; then
        sync_question="Sync $(plural_text "$ready_branches" branch branches) in $(plural_text "$ready_repos" repository repositories) by rebasing onto $DEFAULT_BRANCH and force-pushing them (--force-with-lease)?"
    else
        sync_question="Sync $(plural_text "$ready_branches" branch branches) in $(plural_text "$ready_repos" repository repositories) by merging $DEFAULT_BRANCH?"
    fi
    confirm_or_exit "$sync_question" sync synced
fi

# Appends one line to the repository's summary file: "<status>|<branch>|<text>" with the status
# ok or local (synced), uptodate, fail, skipped (not attempted), detail (a line of git output shown
# under the failed branch) or warn. $sync_summary_file is set by the job.
sync_note() {
    printf '%s|%s|%s\n' "$1" "$2" "$3" >> "$sync_summary_file"
}

# Runs git in the directory $1 with the other arguments; nothing is printed, the output (stdout and
# stderr) is kept in sync_git_output and shown, in part, only when the step fails.
sync_git() {
    sync_git_output=$(git -C "$1" "${@:2}" 2>&1)
}

# Sets sync_detail to up to 5 relevant lines of the git output $1: the CONFLICT lines, or else its
# last lines.
sync_set_detail() {
    sync_detail=$(printf '%s\n' "$1" | grep '^CONFLICT' | head -n 5)
    if [ -z "$sync_detail" ]; then
        sync_detail=$(printf '%s\n' "$1" | grep -v '^[[:space:]]*$' | tail -n 5)
    fi
}

# Notes a failure of the branch (or default branch) $1 with the text $2 and the lines of sync_detail.
sync_note_failure() {
    local line
    sync_note fail "$1" "$2"
    if [ -n "$sync_detail" ]; then
        while IFS= read -r line; do
            sync_note detail - "$line"
        done <<< "$sync_detail"
    fi
}

# Sets sync_aborted to "merge" or "rebase" after aborting whichever is in progress in the
# repository $1 (empty when there was none), so git is never left half done.
sync_abort_in_progress() {
    sync_aborted=""
    if rebase_in_progress "$1"; then
        git -C "$1" rebase --abort > /dev/null 2>&1 || true
        sync_aborted="rebase"
    fi
    if git -C "$1" rev-parse -q --verify MERGE_HEAD > /dev/null 2>&1; then
        git -C "$1" merge --abort > /dev/null 2>&1 || git -C "$1" reset --merge > /dev/null 2>&1 || true
        sync_aborted="merge"
    fi
}

# The tail of a failure note: "; merge aborted, stopped" or "; stopped"
sync_stop_text() {
    if [ -n "$sync_aborted" ]; then
        echo "; $sync_aborted aborted, stopped"
    else
        echo "; stopped"
    fi
}

# sync_branch <directory> <branch>: pull the branch from origin when it is there, bring the default
# branch in and push it. Returns 0, or 1 when it had to stop; either way sync_status and sync_text
# describe the outcome (see sync_note), and sync_detail holds the lines of git output of a failure.
sync_branch() {
    local directory="$1" branch="$2" before after count=0 on_origin=false pulled=false pushed=false
    local local_sha remote_sha step_ok
    sync_aborted=""
    sync_detail=""
    if ! sync_git "$directory" checkout -q "$branch" --; then
        sync_set_detail "$sync_git_output"
        sync_status="fail"
        sync_text="could not check out; stopped"
        return 1
    fi
    if git -C "$directory" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        on_origin=true
    fi

    before=$(git -C "$directory" rev-parse HEAD)
    if $on_origin; then
        step_ok=true
        if $use_rebase; then
            sync_git "$directory" pull --rebase origin "$branch" || step_ok=false
        else
            sync_git "$directory" pull --no-rebase --no-edit origin "$branch" || step_ok=false
        fi
        if ! $step_ok; then
            sync_set_detail "$sync_git_output"
            sync_abort_in_progress "$directory"
            sync_status="fail"
            if [ -n "$sync_aborted" ]; then
                sync_text="conflict while pulling origin/$branch$(sync_stop_text)"
            else
                sync_text="could not pull origin/$branch$(sync_stop_text)"
            fi
            return 1
        fi
        after=$(git -C "$directory" rev-parse HEAD)
        if [ "$after" != "$before" ]; then
            pulled=true
        fi
    fi

    if ! git -C "$directory" merge-base --is-ancestor "$DEFAULT_BRANCH" HEAD; then
        count=$(git -C "$directory" rev-list --count "HEAD..$DEFAULT_BRANCH")
        step_ok=true
        if $use_rebase; then
            sync_git "$directory" rebase "$DEFAULT_BRANCH" || step_ok=false
        else
            sync_git "$directory" merge --no-edit "$DEFAULT_BRANCH" || step_ok=false
        fi
        if ! $step_ok; then
            sync_set_detail "$sync_git_output"
            sync_abort_in_progress "$directory"
            sync_status="fail"
            if $use_rebase; then
                sync_text="conflict while rebasing onto $DEFAULT_BRANCH$(sync_stop_text)"
            else
                sync_text="conflict while merging $DEFAULT_BRANCH$(sync_stop_text)"
            fi
            return 1
        fi
    fi

    if $on_origin; then
        local_sha=$(git -C "$directory" rev-parse HEAD)
        remote_sha=$(git -C "$directory" rev-parse "refs/remotes/origin/$branch")
        if [ "$local_sha" != "$remote_sha" ]; then
            step_ok=true
            if $use_rebase; then
                sync_git "$directory" push --force-with-lease origin "$branch" || step_ok=false
            else
                sync_git "$directory" push origin "$branch" || step_ok=false
            fi
            if ! $step_ok; then
                sync_set_detail "$sync_git_output"
                sync_status="fail"
                sync_text="could not push to origin; stopped"
                return 1
            fi
            pushed=true
        fi
    fi

    sync_text=""
    if [ "$count" -gt 0 ]; then
        if $use_rebase; then
            sync_text="rebased onto $DEFAULT_BRANCH ($(plural_text "$count" "new commit" "new commits"))"
        else
            sync_text="merged $(commit_text "$count") from $DEFAULT_BRANCH"
        fi
    elif $pulled; then
        sync_text="pulled"
    fi
    if ! $on_origin; then
        if [ -z "$sync_text" ]; then
            sync_status="uptodate"
            sync_text="local only, up to date"
        else
            sync_status="local"
            sync_text="local only, $sync_text"
        fi
    elif [ -z "$sync_text" ] && ! $pushed; then
        sync_status="uptodate"
        sync_text="up to date"
    else
        sync_status="ok"
        if $pushed; then
            sync_text="${sync_text:+$sync_text, }pushed"
        fi
    fi
    return 0
}

# Records every branch of the list $2 from position $1 on as not attempted.
sync_not_attempted() {
    local names position="$1" i
    read -ra names <<< "$2"
    for ((i = position; i < ${#names[@]}; i++)); do
        sync_note skipped "${names[$i]}" "not attempted"
    done
}

# Worker for parallel_run: runs the whole sync of one repository and stops at the first failure.
# It prints nothing: the outcomes go to $parallel_dir/<index>.summary for the result at the end.
# Status 0 (done), 1 (failed) or 2 (nothing to do).
sync_repo_job() {
    local directory="$1" index=0 i name branches names original original_sha dirty
    local default_before default_after changed=false failed=false position=0
    for ((i = 0; i < ${#repo_list[@]}; i++)); do
        if [ "${repo_list[$i]}" == "$directory" ]; then
            index=$i
        fi
    done
    sync_summary_file="$parallel_dir/$index.summary"
    : > "$sync_summary_file"
    name="$(get_directory_name "$directory")"
    branches="${plan_branches[$index]}"
    sync_detail=""
    if [ "${plan_state[$index]}" == "nodefault" ]; then
        return 2
    fi

    dirty=$(git -C "$directory" status --porcelain --untracked-files=no) # untracked files do not block a sync
    if [ -n "$dirty" ]; then
        sync_note_failure "$DEFAULT_BRANCH" "uncommitted changes; nothing was changed, stopped"
        sync_not_attempted 0 "$branches"
        return 1
    fi

    original=$(git -C "$directory" branch --show-current)
    original_sha=$(git -C "$directory" rev-parse HEAD)

    if ! sync_git "$directory" fetch --prune origin; then
        sync_set_detail "$sync_git_output"
        sync_note_failure "$DEFAULT_BRANCH" "could not fetch origin; stopped"
        sync_not_attempted 0 "$branches"
        return 1
    fi

    if ! sync_git "$directory" checkout -q "$DEFAULT_BRANCH" --; then
        sync_set_detail "$sync_git_output"
        sync_note_failure "$DEFAULT_BRANCH" "could not check out; stopped"
        sync_not_attempted 0 "$branches"
        failed=true
    else
        default_before=$(git -C "$directory" rev-parse HEAD)
        if git -C "$directory" show-ref --verify --quiet "refs/remotes/origin/$DEFAULT_BRANCH"; then
            if ! sync_git "$directory" pull --ff-only origin "$DEFAULT_BRANCH"; then
                sync_set_detail "$sync_git_output"
                sync_note_failure "$DEFAULT_BRANCH" "diverged from origin/$DEFAULT_BRANCH; stopped"
                sync_not_attempted 0 "$branches"
                failed=true
            fi
        fi
        if ! $failed; then
            default_after=$(git -C "$directory" rev-parse HEAD)
            if [ "$default_after" != "$default_before" ]; then
                changed=true
                sync_note ok "$DEFAULT_BRANCH" "pulled"
            else
                sync_note uptodate "$DEFAULT_BRANCH" "up to date"
            fi
            read -ra names <<< "$branches"
            for ((position = 0; position < ${#names[@]}; position++)); do
                if sync_branch "$directory" "${names[$position]}"; then
                    sync_note "$sync_status" "${names[$position]}" "$sync_text"
                    case "$sync_status" in
                    ok | local) changed=true ;;
                    esac
                else
                    sync_note_failure "${names[$position]}" "$sync_text"
                    sync_not_attempted $((position + 1)) "$branches"
                    failed=true
                    break
                fi
            done
        fi
    fi

    # Back to where the run started, whatever happened
    if [ -n "$original" ]; then
        sync_git "$directory" checkout -q "$original" -- || sync_note warn - "could not return to $original"
    else
        sync_git "$directory" checkout -q --detach "$original_sha" || sync_note warn - "could not return to the detached HEAD"
    fi

    if $failed; then
        return 1
    fi
    if $changed; then
        return 0
    fi
    return 2
}

parallel_run sync_repo_job "$parallel_jobs"
parallel_apply_outcomes # the jobs print nothing; this only counts the outcomes

# Result: totals, then one block per repository with one line per branch (the default branch first),
# its outcome in parentheses coloured by status.
n_synced=0
n_uptodate=0
n_failed=0
n_skipped=0
for ((i = 0; i < ${#repo_list[@]}; i++)); do
    [ "${plan_state[$i]}" == "ready" ] || continue
    while IFS='|' read -r line_status line_branch line_text; do
        case "$line_status" in
        ok | local) [ "$line_branch" == "$DEFAULT_BRANCH" ] || n_synced=$((n_synced + 1)) ;;
        uptodate) [ "$line_branch" == "$DEFAULT_BRANCH" ] || n_uptodate=$((n_uptodate + 1)) ;;
        fail) n_failed=$((n_failed + 1)) ;;
        skipped) n_skipped=$((n_skipped + 1)) ;;
        esac
    done < "$parallel_dir/$i.summary"
done
# The plan ends with a blank line, which a question (or the plan without one) leaves in place
if ! { [ "$ready_repos" -gt 0 ] && $assume_yes; }; then
    echo
fi
echo "Synced branches:"
echo "  Total: $n_synced synced, $n_uptodate up to date, $n_failed failed, $n_skipped not attempted in $(plural_text "$ready_repos" repository repositories)"
for ((i = 0; i < ${#repo_list[@]}; i++)); do
    echo # a blank line after the Total line and between repositories, as in the plan
    name="$(get_directory_name "${repo_list[$i]}")"
    if [ "${plan_state[$i]}" == "nodefault" ]; then
        echo "  ${green}$name${reset}"
        echo "    ${yellow}no $DEFAULT_BRANCH, skipped${reset}"
        continue
    fi
    line_count=$(grep -c '^[a-z]*|[^-]' "$parallel_dir/$i.summary")
    echo "  ${green}$name ($line_count)${reset}"
    while IFS='|' read -r line_status line_branch line_text; do
        case "$line_status" in
        ok) line_colour="$green" ;;
        uptodate | local) line_colour="$yellow" ;;
        fail) line_colour="$red" ;;
        warn) line_colour="$yellow" ;;
        *) line_colour="$dim" ;;
        esac
        case "$line_status" in
        detail) echo "        $line_text" ;;
        warn) echo "    ${yellow}$line_text${reset}" ;;
        *) echo "    - ${cyan}$line_branch${reset} ($line_colour$line_text${reset})" ;;
        esac
    done < "$parallel_dir/$i.summary"
done

finish_run
