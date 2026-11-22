# SKIP_DIRS (.env) is a comma separated list of directory names to exclude from every
# command. It is validated once, when this file is loaded: an entry containing spaces
# (the old space separated form) is a configuration error and exits 2 before any repository is touched.
skip_directory_entries=()
# shellcheck disable=SC2154 # env_list_items is set by parse_env_list
if parse_env_list SKIP_DIRS "$SKIP_DIRS"; then
    skip_directory_entries=("${env_list_items[@]}")
else
    exit 2
fi

# Determine whether a directory should be skipped.
#
# Args:
#   $1 (string): Directory path.
#
# Returns:
#   0 if the directory should be skipped, 1 otherwise.
is_skipped_directory() {
    local directory_path="$1" directory_name skip_entry
    [ "${#skip_directory_entries[@]}" -gt 0 ] || return 1

    directory_name="$(basename "${directory_path%/*}")"

    for skip_entry in "${skip_directory_entries[@]}"; do
        if [ "$directory_name" == "$skip_entry" ]; then
            return 0
        fi
    done

    return 1
}
