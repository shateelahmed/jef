# Spinner function
# Usage: spin & SPINNER_PID=$!  ...  endspin [message...]
sp="/-\|"
sc=0
spin() {
    [ -t 1 ] || return 0 # no spinner when output is piped or redirected
    while true; do
        printf "\r%s" "${sp:sc++:1}"  # Spinner character overwrite
        ((sc == ${#sp})) && sc=0
        sleep 0.1
    done
}

endspin() {
    if [ -n "${SPINNER_PID:-}" ]; then
        kill "$SPINNER_PID" 2>/dev/null       # Stop the spinner background process
        wait "$SPINNER_PID" 2>/dev/null       # Reap it so no "Terminated" notice is printed
        SPINNER_PID=
    fi
    if [ -t 1 ]; then
        printf "\r\033[K"                  # Clear the line (remove spinner output)
    fi
    if [ $# -gt 0 ]; then
        printf "%s\n" "$@"                  # Print optional message
    fi
}

trap 'endspin; exit 130' INT
trap 'endspin; exit 143' TERM
