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
parse_options "$@"

source "$script_location/lib/common.sh"

echo "Target directory: ${green}$target_directory${reset}"
echo "Clear proxy: ${green}$clear_proxy${reset}"

source "$script_location/lib/clear-proxy.sh"

fetch_repo() {
    local child_directory="$1"
    print_repo_header "$child_directory" ":"
    git -C "$child_directory" fetch --all --prune
}

for_each_repo fetch_repo
