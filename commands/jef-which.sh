#!/bin/bash
# shellcheck disable=SC2154,SC2034 # colour variables come from lib/terminal-color-codes.sh; cli_* are read by lib/cli.sh

# Show the currently checked out branch of each repository

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

cli_name="which"
cli_description="Show the currently checked out branch of each repository"
cli_positionals=""
cli_value_flags=(
    "m|repo|repo_filter|REPOS||list|Only these repositories: -m a,b or -m \"a b\" or -m a -m b (also --repo a, --repo=a,b)"
)
parse_options "$@"

source "$script_location/lib/common.sh"
source "$script_location/lib/spinner.sh"

# Define table headers
column1="Directory"
column2="Current Branch"

# Initialize arrays for dynamic width calculation
directories=()
branches=()

# Collect the directory name and current branch of one repository
collect_branch() {
    local child_directory="$1"
    directories+=("$(get_directory_name "$child_directory")")
    branches+=("$(git -C "$child_directory" branch --show-current)")
}

spin &
# shellcheck disable=SC2034 # read by endspin in lib/spinner.sh
SPINNER_PID=$!

# Add Target Directory as the first row
directories+=("Target directory")
branches+=("$target_directory")

# Collect data for directories and branches
for_each_repo collect_branch

endspin

# Determine dynamic column widths
col1_width=$(max_length "$column1" "${directories[@]}")
col2_width=$(max_length "$column2" "${branches[@]}")

# Define table borders dynamically
border_top="+$(printf -- '-%.0s' $(seq $((col1_width + 2))))+$(printf -- '-%.0s' $(seq $((col2_width + 2))))+"
echo -e "\n"

# Print the table header with borders
printf "%s\n" "$border_top"
printf "| %-*s | %-*s |\n" "$col1_width" "$column1" "$col2_width" "$column2"
printf "%s\n" "$border_top"

# Print the rows dynamically with color for the target directory
for i in "${!directories[@]}"; do
    dir_name="${directories[$i]}"
    branch_name="${branches[$i]}"
    if [ "$i" -eq 0 ]; then
        printf "| ${yellow}%-*s${reset} | ${green}%-*s${reset} |\n" "$col1_width" "$dir_name" "$col2_width" "$branch_name"
    else
        printf "| %-*s | ${green}%-*s${reset} |\n" "$col1_width" "$dir_name" "$col2_width" "$branch_name"
    fi
done

# Print the bottom border
printf "%s\n" "$border_top"
