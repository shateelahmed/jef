# Iteration over the first-level git repositories of the target directory.
# shellcheck disable=SC2154 # target_directory and the colour variables are set by the sourcing command

# Call a callback for every non-skipped first-level git repository.
#
# The callback runs in the current shell (so it can fill arrays or set flags)
# and receives the child directory path (with trailing slash). It decides what to
# print; use `return` (not `continue`) to skip a repository.
#
# Args:
#   $1 (string): Name of the callback function.
for_each_repo() {
    local callback="$1" child_directory
    repos_done=0
    repos_failed=0
    repos_skipped=0
    for child_directory in "$target_directory"/*/; do
        is_target_repo "$child_directory" || continue
        "$callback" "$child_directory"
    done
}

# Succeed when $1 is a first-level directory that is a git repo and not in SKIP_DIRS.
is_target_repo() {
    [ -d "$1" ] || return 1
    if is_skipped_directory "$1"; then # skip directories listed in SKIP_DIRS
        return 1
    fi
    is_git_repo "$1"
}

# Fill the repo_list array with the repositories for_each_repo would visit, in order.
list_repos() {
    local child_directory
    repo_list=()
    for child_directory in "$target_directory"/*/; do
        if is_target_repo "$child_directory"; then
            repo_list+=("$child_directory")
        fi
    done
}

# Run a worker for every repository, at most $2 at a time (bash 3.2 safe: no wait -n).
#
# The worker runs in a background subshell, receives the child directory path, writes
# its output to stdout/stderr and returns 0 (done), 1 (failed) or 2 (skipped).
# When this returns, repo_list holds the repositories and, for repository number i,
# $parallel_dir/$i.out holds its output and $parallel_dir/$i.rc its exit status.
# The temp dir is removed (and unfinished jobs are killed) by an EXIT trap, which
# does not interfere with the INT/TERM traps of lib/spinner.sh.
#
# Args:
#   $1 (string): Name of the worker function.
#   $2 (integer): Maximum number of concurrent jobs.
parallel_run() {
    local worker="$1" max_jobs="$2" i j n active still
    repos_done=0
    repos_failed=0
    repos_skipped=0
    list_repos
    n=${#repo_list[@]}
    parallel_dir="$(mktemp -d "${TMPDIR:-/tmp}/jef.XXXXXX")" || exit 1
    parallel_pids=()
    trap '_parallel_cleanup' EXIT
    active=()
    for ((i = 0; i < n; i++)); do
        # wait for a free slot: a job is finished once its .rc file exists
        while true; do
            still=()
            for j in "${active[@]}"; do
                [ -e "$parallel_dir/$j.rc" ] || still+=("$j")
            done
            active=("${still[@]}")
            [ "${#active[@]}" -lt "$max_jobs" ] && break
            sleep 0.05
        done
        (
            "$worker" "${repo_list[$i]}" > "$parallel_dir/$i.out" 2>&1
            echo $? > "$parallel_dir/$i.rc"
        ) &
        parallel_pids[i]=$!
        active+=("$i")
    done
    for ((i = 0; i < n; i++)); do
        wait "${parallel_pids[$i]}" # only our own jobs: a bare wait would also wait for the spinner
    done
}

# Print the PIDs of all descendants of $1 (pgrep -P exists on macOS and Linux).
_descendant_pids() {
    local child
    for child in $(pgrep -P "$1" 2> /dev/null); do
        echo "$child"
        _descendant_pids "$child"
    done
}

_parallel_cleanup() {
    local i pid victims
    for i in "${!parallel_pids[@]}"; do
        pid="${parallel_pids[$i]}"
        if [ ! -e "$parallel_dir/$i.rc" ]; then
            victims="$(_descendant_pids "$pid")" # collect before killing: orphans lose their parent link
            kill "$pid" $victims 2> /dev/null
        fi
    done
    [ -n "${parallel_dir:-}" ] && rm -rf "$parallel_dir"
    return 0
}

# After parallel_run: print every repository's output in order and count its outcome.
parallel_apply_outcomes() {
    local i n=${#repo_list[@]} rc
    for ((i = 0; i < n; i++)); do
        cat "$parallel_dir/$i.out"
        rc="$(cat "$parallel_dir/$i.rc")"
        case "$rc" in
        0) mark_repo_done ;;
        2) mark_repo_skipped ;;
        *) mark_repo_failed ;;
        esac
    done
}

# Print the "Working directory" header for a repository.
#
# Args:
#   $1 (string): Child directory path.
#   $2 (string): Optional text appended to the label (fetch passes ":").
print_repo_header() {
    echo -e "\nWorking directory$2 ${green}$(get_directory_name "$1")${reset}"
}

# Per-repository outcome tracking for the end-of-run summary. A callback calls
# exactly one of these before returning:
#   mark_repo_done     the operation succeeded (in --dry-run: it would be performed)
#   mark_repo_failed   a git command failed or the repository could not be prepared
#   mark_repo_skipped  the repository was visited but the operation does not apply
# A repository for which no mark is made is not counted.
mark_repo_done() { repos_done=$((repos_done + 1)); }
mark_repo_failed() { repos_failed=$((repos_failed + 1)); }
mark_repo_skipped() { repos_skipped=$((repos_skipped + 1)); }

# Print "Summary: X done, Y failed, Z skipped" and exit 3 if any repository failed
# (otherwise return, so the command exits 0). Call after for_each_repo.
finish_run() {
    local failed_colour=""
    if [ "$repos_failed" -gt 0 ]; then
        failed_colour="$red"
    fi
    echo -e "\nSummary: ${green}$repos_done done${reset}, ${failed_colour}$repos_failed failed${reset}, ${yellow}$repos_skipped skipped${reset}"
    if [ "$repos_failed" -gt 0 ]; then
        exit 3
    fi
    return 0
}
