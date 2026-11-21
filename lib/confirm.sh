# Shared confirmation prompt for commands that delete things.
# shellcheck disable=SC2154 # assume_yes is set by the sourcing command (a --yes flag)

# Ask "<question> [y/N]" and return only on a yes. Succeeds at once when assume_yes is
# true. Exits 2 when stdin is not a terminal (and --yes was not given) and exits 1
# ("Aborted. Nothing was deleted.") on any answer but y, Y or yes.
#
# Args:
#   $1 (string): The question, without the "[y/N]" suffix.
confirm_or_exit() {
    local answer=""
    if ${assume_yes:-false}; then
        return 0
    fi
    if [ ! -t 0 ]; then
        echo "Not running in a terminal. Re-run with --yes to delete. Nothing was deleted."
        exit 2
    fi
    printf "%s [y/N] " "$1"
    read -r answer || true
    case "$answer" in
    y | Y | [Yy][Ee][Ss]) return 0 ;;
    esac
    echo "Aborted. Nothing was deleted."
    exit 1
}
