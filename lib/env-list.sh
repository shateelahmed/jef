# Split a comma separated .env list value into the env_list_items array.
#
# Entries are separated by commas only; leading and trailing whitespace of each entry is trimmed
# and empty entries are ignored. Glob characters are kept as they are (no file name expansion).
# An entry that still has whitespace inside it (eg. "dev qa", the old space separated form) is a
# configuration error: silently treating it as one pattern could change what is skipped or protected.
#
# Args:
#   $1 (string): Name of the .env key, used in the error message.
#   $2 (string): The value.
#
# Returns:
#   0 on success; 1 (after printing the error to stderr) when an entry contains whitespace.
parse_env_list() {
    local key="$1" raw="$2" entry noglob=false
    local IFS=','
    env_list_items=()
    case "$-" in *f*) noglob=true ;; esac
    set -f # the entries may be glob patterns and must not be matched against files
    for entry in $raw; do
        entry="${entry#"${entry%%[![:space:]]*}"}" # trim leading whitespace
        entry="${entry%"${entry##*[![:space:]]}"}" # trim trailing whitespace
        [ -z "$entry" ] && continue
        case "$entry" in
        *[[:space:]]*)
            $noglob || set +f
            echo "Invalid $key: '$entry' contains spaces; separate entries with commas" >&2
            return 1
            ;;
        esac
        env_list_items+=("$entry")
    done
    $noglob || set +f
    return 0
}
