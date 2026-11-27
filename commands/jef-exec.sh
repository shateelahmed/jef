#!/bin/bash
# shellcheck disable=SC2154,SC2034 # colour variables come from lib/terminal-color-codes.sh; cli_* are read by lib/cli.sh

# Run a command in every repository: one argument as a shell string (bash -c), several as the command and its arguments

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

cli_name="exec"
cli_description="Run a command in every repository"
cli_positionals="[--] <command...>"
cli_pass_through=true # the command's own options (-h, -n, -1, --dry-run) are not jef's
cli_extra_flags=("n|dry-run|dry_run|Show the commands that would run without running them")
cli_value_flags=(
    "m|repo|repo_filter|REPOS||list|Only these repositories: -m a,b or -m \"a b\" or -m a -m b (also --repo a, --repo=a,b)"
    "j|jobs|parallel_jobs|N|1|posint|Run up to N repositories at once (default 1)"
    "b|branch|branch_filter|BRANCH||string|Only repositories that have BRANCH checked out"
)
parse_options "$@"
if [ "${#cli_positional[@]}" -eq 0 ]; then
    usage_error "a command is required"
fi
exec_command=("${cli_positional[@]}")

source "$script_location/lib/common.sh"

if [ -n "$branch_filter" ] && ! is_valid_branch_name "$branch_filter"; then
    echo "'$branch_filter' is not a valid branch name"
    exit 2
fi

# The command as shown in the banner and "Would run:". A single argument (a shell string) is shown
# as is; with several, an argument that is empty or holds spaces or shell characters is shown in
# single quotes, so the display can be pasted back (--format='%h %s', not --format=%h %s).
display_arg() {
    local quote="'" escaped="'\\''"
    case "$1" in
    '' | *[[:space:]\'\"\$\`\\\|\&\;\<\>\(\)\*\?\[\]\{\}\~\#\!]*)
        printf "'%s'" "${1//$quote/$escaped}" ;;
    *) printf '%s' "$1" ;;
    esac
}
if [ "${#exec_command[@]}" -eq 1 ]; then
    command_display="${exec_command[0]}"
else
    command_display="$(display_arg "${exec_command[0]}")"
    for ((arg_index = 1; arg_index < ${#exec_command[@]}; arg_index++)); do
        command_display+=" $(display_arg "${exec_command[arg_index]}")"
    done
fi

echo "Target directory: ${green}$target_directory${reset}"
echo "Repositories: ${green}${repo_filter:-all}${reset}"
echo "Command: ${green}$command_display${reset}"
echo "Branch filter: ${green}${branch_filter:-any}${reset}"
echo "Jobs: ${green}$parallel_jobs${reset}"
echo "Dry run: ${green}$dry_run${reset}"

# Runs the command in one repository; output to stdout, status 0 (done), 1 (failed) or 2 (skipped).
# The command runs from inside the repository with JEF_REPO set to its directory name and stdin from
# /dev/null, so it never waits for terminal input.
exec_repo_core() {
    local directory_name current_branch exit_code
    directory_name=$(get_directory_name "$1")
    print_repo_header "$1"
    if [ -n "$branch_filter" ]; then
        current_branch=$(git -C "$1" branch --show-current)
        if [ "$current_branch" != "$branch_filter" ]; then
            echo "on ${current_branch:-a detached HEAD}, not $branch_filter. skipping..."
            return 2
        fi
    fi
    if $dry_run; then
        echo "Would run: $command_display"
        return 0
    fi
    (
        cd "$1" || exit 1
        export JEF_REPO="$directory_name"
        if [ "${#exec_command[@]}" -eq 1 ]; then
            bash -c -- "${exec_command[0]}" # -- so a command starting with a dash is not read as an option
        else
            "${exec_command[@]}"
        fi
    ) < /dev/null
    exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
        echo "${red}Exited with status $exit_code${reset}"
        return 1
    fi
    return 0
}

exec_repo() {
    local outcome=0
    exec_repo_core "$1" || outcome=$?
    case "$outcome" in
    0) mark_repo_done ;;
    2) mark_repo_skipped ;;
    *) mark_repo_failed ;;
    esac
}

# Worker for parallel runs
exec_repo_job() {
    exec_repo_core "$1"
}

if [ "$parallel_jobs" -gt 1 ]; then
    parallel_run exec_repo_job "$parallel_jobs"
    parallel_apply_outcomes
else
    for_each_repo exec_repo
fi
finish_run
