# Shared confirmation prompt for commands that change or delete things.
# shellcheck disable=SC2154 # assume_yes is set by the sourcing command (a --yes flag)

# Ask "<question> [y/N]" and return only on a yes. Succeeds at once when assume_yes is
# true. Exits 2 when stdin is not a terminal (and --yes was not given) and exits 1
# ("Aborted. Nothing was <past>.") on any answer but y, Y or yes.
#
# Args:
#   $1 (string): The question, without the "[y/N]" suffix.
#   $2 (string): Optional verb for the messages (default "delete").
#   $3 (string): Optional past participle of the verb (default "deleted").
confirm_or_exit() {
    local answer="" verb="${2:-delete}" past="${3:-deleted}"
    if ${assume_yes:-false}; then
        return 0
    fi
    if [ ! -t 0 ]; then
        echo "Not running in a terminal. Re-run with --yes to $verb. Nothing was $past."
        exit 2
    fi
    printf "%s [y/N] " "$1"
    read -r answer || true
    case "$answer" in
    y | Y | [Yy][Ee][Ss]) return 0 ;;
    esac
    echo "Aborted. Nothing was $past."
    exit 1
}
