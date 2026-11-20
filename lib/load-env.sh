# Load variables from the .env file in the installation root.
#
# The file is parsed as data and never executed: one KEY=VALUE per line, blank
# lines and lines starting with # are ignored, surrounding whitespace is trimmed,
# one pair of surrounding single or double quotes is removed from the value, and
# only keys that are valid variable names are exported. A leading ~, $HOME or
# ${HOME} in a value is replaced by HOME; nothing else is expanded.
load_env_file() {
    local env_file="$1" line key value first last
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}" # tolerate CRLF line endings
        line="${line#"${line%%[![:space:]]*}"}" # trim leading whitespace
        case "$line" in
        "" | "#"*) continue ;;
        *=*) ;;
        *) continue ;;
        esac
        key="${line%%=*}"
        value="${line#*=}"
        key="${key%"${key##*[![:space:]]}"}" # trim trailing whitespace of the key
        value="${value#"${value%%[![:space:]]*}"}" # trim leading whitespace of the value
        value="${value%"${value##*[![:space:]]}"}" # trim trailing whitespace of the value
        case "$key" in
        "" | [0-9]* | *[!A-Za-z0-9_]*) continue ;; # not a valid variable name
        esac
        if [ ${#value} -ge 2 ]; then
            first="${value:0:1}"
            last="${value:${#value}-1:1}"
            if { [ "$first" = '"' ] || [ "$first" = "'" ]; } && [ "$first" = "$last" ]; then
                value="${value:1:${#value}-2}"
            fi
        fi
        if [ -n "${HOME:-}" ]; then # expand a leading ~, $HOME or ${HOME} (nothing else)
            # shellcheck disable=SC2088 # a literal ~ is matched on purpose
            case "$value" in
            "~" | "~/"*) value="$HOME${value:1}" ;;
            '$HOME' | '$HOME/'*) value="$HOME${value:5}" ;;
            '${HOME}' | '${HOME}/'*) value="$HOME${value:7}" ;;
            esac
        fi
        export "$key=$value"
    done < "$env_file"
}

# shellcheck disable=SC2154 # script_location is set by the sourcing command
env_file_location="$script_location/.env"
if [ -f "$env_file_location" ]; then # set ENV variables from .env file if it exists
    load_env_file "$env_file_location"
fi
