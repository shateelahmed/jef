#!/bin/bash
# shellcheck disable=SC2154,SC2034 # colour variables come from lib/terminal-color-codes.sh; cli_* are read by lib/cli.sh

# Run 'git fetch --all --prune' in every repository

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

cli_name="fetch"
cli_description="Run 'git fetch --all --prune' in every repository"
cli_positionals=""
cli_accepts_proxy=true
cli_value_flags=(
    "m|repo|repo_filter|REPOS||list|Only these repositories: -m a,b or -m \"a b\" or -m a -m b (also --repo a, --repo=a,b)"
    "j|jobs|parallel_jobs|N|1|posint|Fetch up to N repositories at once (default 1)")
parse_options "$@"

source "$script_location/lib/common.sh"

echo "Target directory: ${green}$target_directory${reset}"
echo "Repositories: ${green}${repo_filter:-all}${reset}"
echo "Clear proxy: ${green}$clear_proxy${reset}"

source "$script_location/lib/clear-proxy.sh"

fetch_repo() {
    local child_directory="$1"
    print_repo_header "$child_directory" ":"
    if git -C "$child_directory" fetch --all --prune; then
        mark_repo_done
    else
        mark_repo_failed
    fi
}

# Worker for parallel runs: output to stdout, status 0 (done) or 1 (failed)
fetch_repo_job() {
    print_repo_header "$1" ":"
    if git -C "$1" fetch --all --prune; then
        return 0
    fi
    return 1
}

if [ "$parallel_jobs" -gt 1 ]; then
    parallel_run fetch_repo_job "$parallel_jobs"
    parallel_apply_outcomes
else
    for_each_repo fetch_repo
fi
finish_run
