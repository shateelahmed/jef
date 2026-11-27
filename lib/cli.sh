# Shared option parsing and usage for the jef commands.
# shellcheck disable=SC2154,SC2034 # cli_* are declared by the sourcing command; the results are read by it
#
# A command declares, before calling parse_options:
#   cli_name           command name without the "jef-" prefix, e.g. "delete"
#   cli_description    one-line description
#   cli_positionals    usage placeholder for positional arguments, e.g. "<branch>" (may be empty)
#   cli_accepts_proxy  "true" if the command takes -c/--clear-proxy (default: false)
#   cli_extra_flags    optional array of "short|long|variable|description" entries,
#                      e.g. "r|delete-remote-branch|delete_remote_branch|Also delete the remote branch"
#                      (leave the short letter empty for a long-only flag: "|include-empty|include_empty|...")
#
#   cli_value_flags    optional array of "short|long|variable|METAVAR|default|type|description" entries for
#                      flags that take a value (-j N, --jobs N, --jobs=N), e.g.
#                      "j|jobs|parallel_jobs|N|1|posint|Process up to N repositories at once"
#                      type "posint" requires a positive integer (else usage error, exit 2)
#                      type "list" accumulates: repeating the flag appends to the value (space-joined),
#                      e.g. "m|repo|repo_filter|REPOS||list|Only these repositories"
#                      (the command splits the value itself; plain type is a free-form string)
#
#   cli_pass_through   "true" for a command whose trailing words are its own command line (jef exec). Scanning from the
#                      start, the jef words (-d/--directory and the value flags, their values, and the boolean flags,
#                      short, clustered short, long or long-only) are parsed as usual; the first word that is not one
#                      of these (or the word after "--", which is dropped) starts the command: it and every word after
#                      it go to cli_positional untouched, so their -h, -n, -- and -1 are not jef's. An unknown option
#                      before the command is still "unknown option" (exit 2). Default false: every word is parsed.
#
# (declare "n|dry-run|dry_run|..." for commands that support --dry-run; see lib/repos.sh finish_run)
# parse_options "$@" then sets: target_directory (only when -d is given),
# clear_proxy, each extra-flag variable (true/false) and the cli_positional array.

# Print the command's usage (synopsis, description, options).
print_usage() {
    local flag short long var desc meta default type
    echo "Usage: jef $cli_name [options]${cli_positionals:+ $cli_positionals}"
    echo
    echo "$cli_description"
    echo
    echo "Options:"
    printf "  %-28s %s\n" "-d, --directory DIR" "Target directory (overrides TARGET_DIR)"
    if [ "${cli_accepts_proxy:-false}" = true ]; then
        printf "  %-28s %s\n" "-c, --clear-proxy" "Unset proxy variables before contacting remotes"
    fi
    for flag in "${cli_extra_flags[@]}"; do
        IFS='|' read -r short long var desc <<< "$flag"
        if [ -z "$short" ]; then
            printf "  %-28s %s\n" "    --$long" "$desc"
        else
            printf "  %-28s %s\n" "-$short, --$long" "$desc"
        fi
    done
    for flag in "${cli_value_flags[@]}"; do
        IFS='|' read -r short long var meta default type desc <<< "$flag"
        printf "  %-28s %s\n" "-$short, --$long $meta" "$desc"
    done
    printf "  %-28s %s\n" "-h, --help" "Show this help and exit"
}

# Print an error and the usage to stderr, then exit 2.
usage_error() {
    {
        echo "jef $cli_name: $1"
        echo
        print_usage
    } >&2
    exit 2
}

# Succeed when the long option $1 (without the dashes) takes a value: directory or a value flag.
_is_value_long() {
    local flag short long var meta default type desc
    if [ "$1" = directory ]; then
        return 0
    fi
    for flag in "${cli_value_flags[@]}"; do
        IFS='|' read -r short long var meta default type desc <<< "$flag"
        if [ "$1" = "$long" ]; then
            return 0
        fi
    done
    return 1
}

# Succeed when the short option $1 (one letter) takes a value: d or a value flag.
_is_value_short() {
    local flag short long var meta default type desc
    if [ "$1" = d ]; then
        return 0
    fi
    for flag in "${cli_value_flags[@]}"; do
        IFS='|' read -r short long var meta default type desc <<< "$flag"
        if [ "$1" = "$short" ]; then
            return 0
        fi
    done
    return 1
}

# cli_pass_through only: split "$@" into _jef_words (the words before the command, as given) and
# cli_command_words (the command: from its first word on, after a "--" that is dropped).
_split_pass_through() {
    local word letters i ch name
    local take_value=false in_command=false
    _jef_words=()
    cli_command_words=()
    for word in "$@"; do
        if $in_command; then
            cli_command_words+=("$word")
        elif $take_value; then
            _jef_words+=("$word")
            take_value=false
        else
            case "$word" in
            --) in_command=true ;;
            --*)
                _jef_words+=("$word")
                name="${word#--}"
                case "$name" in
                *=*) ;;
                *)
                    if _is_value_long "$name"; then
                        take_value=true
                    fi
                    ;;
                esac
                ;;
            -?*)
                _jef_words+=("$word")
                letters="${word#-}"
                i=0
                while [ "$i" -lt "${#letters}" ]; do
                    ch="${letters:i:1}"
                    if _is_value_short "$ch"; then
                        # the rest of the cluster is the value, or else the next word
                        if [ $((i + 1)) -eq "${#letters}" ]; then
                            take_value=true
                        fi
                        break
                    fi
                    i=$((i + 1))
                done
                ;;
            *)
                in_command=true
                cli_command_words+=("$word")
                ;;
            esac
        fi
    done
}

parse_options() {
    local OPTIND=1 opt arg flag short long var desc bad meta default type digits
    local optstring=":d:h" args
    args=()
    cli_positional=()
    clear_proxy=false

    if [ "${cli_pass_through:-false}" = true ]; then
        _split_pass_through "$@"
        if [ ${#_jef_words[@]} -gt 0 ]; then
            set -- "${_jef_words[@]}"
        else
            set --
        fi
    fi

    if [ "${cli_accepts_proxy:-false}" = true ]; then
        optstring+="c"
    fi
    for flag in "${cli_extra_flags[@]}"; do
        IFS='|' read -r short long var desc <<< "$flag"
        optstring+="$short" # empty for a long-only flag
        printf -v "$var" %s false
    done
    for flag in "${cli_value_flags[@]}"; do
        IFS='|' read -r short long var meta default type desc <<< "$flag"
        optstring+="$short:"
        printf -v "$var" %s "$default"
    done

    # --help / -h anywhere in the arguments wins
    for arg in "$@"; do
        case "$arg" in
        -h | --help)
            print_usage
            exit 0
            ;;
        esac
    done

    # Convert long options to short ones (unknown ones are left alone and rejected below)
    for arg in "$@"; do
        case "$arg" in
        --directory) args+=("-d") ;;
        --clear-proxy)
            if [ "${cli_accepts_proxy:-false}" = true ]; then args+=("-c"); else args+=("$arg"); fi
            ;;
        --*)
            bad=""
            for flag in "${cli_extra_flags[@]}"; do
                IFS='|' read -r short long var desc <<< "$flag"
                if [ "$arg" = "--$long" ]; then
                    if [ -z "$short" ]; then # long-only flag: set it here, getopts never sees it
                        printf -v "$var" %s true
                        bad="="
                    else
                        bad="$short"
                    fi
                fi
            done
            for flag in "${cli_value_flags[@]}"; do
                IFS='|' read -r short long var meta default type desc <<< "$flag"
                case "$arg" in
                "--$long") bad="$short" ;;
                "--$long="*) args+=("-$short" "${arg#*=}"); bad="=" ;;
                esac
            done
            if [ "$bad" = "=" ]; then :
            elif [ -n "$bad" ]; then args+=("-$bad"); else args+=("$arg"); fi
            ;;
        *) args+=("$arg") ;;
        esac
    done

    # With no arguments left (e.g. only a long-only flag was given), getopts must not run: given
    # no words it would parse this function's own "$@" and report "unknown option '--'".
    [ ${#args[@]} -eq 0 ] && args=("--")
    while getopts "$optstring" opt "${args[@]}"; do
        case "$opt" in
        d) target_directory="$OPTARG" ;;
        c) clear_proxy=true ;;
        :) usage_error "option '-$OPTARG' requires an argument" ;;
        \?)
            bad="-$OPTARG"
            if [ "$OPTARG" = "-" ]; then
                for arg in "${args[@]}"; do
                    case "$arg" in
                    --?*) bad="$arg"; break ;;
                    esac
                done
            fi
            usage_error "unknown option '$bad'"
            ;;
        *)
            for flag in "${cli_extra_flags[@]}"; do
                IFS='|' read -r short long var desc <<< "$flag"
                if [ "$short" = "$opt" ]; then printf -v "$var" %s true; fi
            done
            for flag in "${cli_value_flags[@]}"; do
                IFS='|' read -r short long var meta default type desc <<< "$flag"
                if [ "$short" = "$opt" ]; then
                    if [ "$type" = posint ]; then
                        digits="$OPTARG"
                        case "$digits" in
                        '' | *[!0-9]*) usage_error "option '--$long' needs a positive integer, got '$OPTARG'" ;;
                        esac
                        if [ "${#digits}" -gt 6 ] || [ "$((10#$digits))" -lt 1 ]; then
                            usage_error "option '--$long' needs a positive integer, got '$OPTARG'"
                        fi
                        OPTARG=$((10#$digits))
                    fi
                    if [ "$type" = list ]; then
                        if [ -z "$OPTARG" ]; then
                            OPTARG="${!var}"
                        elif [ -n "${!var}" ]; then
                            OPTARG="${!var} $OPTARG"
                        fi
                    fi
                    printf -v "$var" %s "$OPTARG"
                fi
            done
            ;;
        esac
    done

    cli_positional=("${args[@]:$((OPTIND - 1))}")
    if [ "${cli_pass_through:-false}" = true ] && [ ${#cli_command_words[@]} -gt 0 ]; then
        cli_positional+=("${cli_command_words[@]}")
    fi
}

# Exit 2 with the usual message unless exactly $1 positional arguments were given.
require_args() {
    local required="$1" provided=${#cli_positional[@]} noun="arguments"
    if [ "$required" -eq 1 ]; then
        noun="argument"
    fi
    if [ "$provided" -ne "$required" ]; then
        echo "$required $noun required. $provided provided"
        exit 2
    fi
}
