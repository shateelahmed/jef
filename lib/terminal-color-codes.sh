# Terminal colour codes: only when stdout is a terminal and NO_COLOR is unset or
# empty (https://no-color.org). Empty strings otherwise, or when tput fails/is missing.
# shellcheck disable=SC2034 # the variables are used by the sourcing commands
green=""
yellow=""
red=""
magenta=""
cyan=""
reset=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    green=$(tput setaf 2 2> /dev/null) || green=""
    yellow=$(tput setaf 3 2> /dev/null) || yellow=""
    red=$(tput setaf 1 2> /dev/null) || red=""
    magenta=$(tput setaf 5 2> /dev/null) || magenta=""
    cyan=$(tput setaf 6 2> /dev/null) || cyan=""
    reset=$(tput sgr0 2> /dev/null) || reset=""
fi
