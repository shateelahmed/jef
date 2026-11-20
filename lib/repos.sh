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
    for child_directory in "$target_directory"/*/; do
        [ -d "$child_directory" ] || continue
        if is_skipped_directory "$child_directory"; then # skip directories listed in SKIP_DIRS
            continue
        fi
        if ! is_git_repo "$child_directory"; then
            continue
        fi
        "$callback" "$child_directory"
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
