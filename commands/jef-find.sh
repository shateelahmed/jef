#!/bin/bash
# shellcheck disable=SC2154,SC2034 # colour variables come from lib/terminal-color-codes.sh; cli_* are read by lib/cli.sh

# Show whether a branch exists locally and on the remote in each repository

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

cli_name="find"
cli_description="Show whether a branch exists locally and on the remote in each repository"
cli_positionals="<branch>"
cli_accepts_proxy=true
parse_options "$@"
require_args 1

source "$script_location/lib/common.sh"

branch_to_find="${cli_positional[0]}"

if ! is_valid_branch_name "$branch_to_find"; then
    echo "'$branch_to_find' is not a valid branch name"
    exit 2
fi

echo -e "Target directory           : ${green}$target_directory${reset}"
echo -e "Branch to find             : ${green}$branch_to_find${reset}"
echo -e "Clear proxy                : ${green}$clear_proxy${reset}"

source "$script_location/lib/clear-proxy.sh"
source "$script_location/lib/spinner.sh"

# Initialize dynamic arrays for the table
directories=()
local_status=()
remote_status=()

function strip_color {
    echo -e "$1" | sed -E 's/\x1B\[[0-9;]*m//g'
}

# Collect the directory name, local status and remote status of one repository
collect_branch_status() {
    local child_directory="$1"

    # Check if the branch exists locally
    if git -C "$child_directory" show-ref --verify --quiet "refs/heads/$branch_to_find"; then
        local_status+=("${green}  ✔  ${reset}")
    else
        local_status+=("${red}  ✘  ${reset}")
    fi

    # Check if the branch exists remotely
    git -C "$child_directory" ls-remote --exit-code --heads origin "$branch_to_find" &> /dev/null
    if [ "$?" == "0" ]; then
        remote_status+=("${green}  ✔   ${reset}")
    else
        remote_status+=("${red}  ✘   ${reset}")
    fi

    directories+=("$(get_directory_name "$child_directory")")
}

spin &
# shellcheck disable=SC2034 # read by endspin in lib/spinner.sh
SPINNER_PID=$!

for_each_repo collect_branch_status

# Define table headers
header1="Directory"
header2="Local"
header3="Remote"

endspin

plain_local_status=()
for status in "${local_status[@]}"; do plain_local_status+=("$(strip_color "$status")"); done
plain_remote_status=()
for status in "${remote_status[@]}"; do plain_remote_status+=("$(strip_color "$status")"); done

col1_width=$(max_length "$header1" "${directories[@]}")
col2_width=$(max_length "$header2" "${plain_local_status[@]}")
col3_width=$(max_length "$header3" "${plain_remote_status[@]}")


# Define table borders dynamically
border_top="+$(printf -- '-%.0s' $(seq $((col1_width + 2))))+$(printf -- '-%.0s' $(seq $((col2_width + 2))))+$(printf -- '-%.0s' $(seq $((col3_width + 2))))+"
echo -e "\n"

# Print the table header with borders
printf "%s\n" "$border_top"
printf "| %-*s | %-*s | %-*s |\n" "$col1_width" "$header1" "$col2_width" "$header2" "$col3_width" "$header3"
printf "%s\n" "$border_top"

# Print the rows dynamically
for i in "${!directories[@]}"; do
    dir_name="${directories[$i]}"
    local_check="${local_status[$i]}"
    remote_check="${remote_status[$i]}"
    printf "| %-*s | %-*s | %-*s |\n" "$col1_width" "$dir_name" "$col2_width" "$local_check" "$col3_width" "$remote_check"
done

# Print the bottom border
printf "%s\n" "$border_top"
