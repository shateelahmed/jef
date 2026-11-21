#!/bin/bash
# shellcheck disable=SC2154,SC2034 # colour variables come from lib/terminal-color-codes.sh; cli_* are read by lib/cli.sh

# Run each repository's own command (MIGRATE_CMDS in .env), e.g. its database migration

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

cli_name="migrate"
cli_description="Run each repository's command from MIGRATE_CMDS (e.g. its database migration)"
cli_positionals=""
cli_extra_flags=("n|dry-run|dry_run|Show the commands that would run without running them")
cli_value_flags=(
    "j|jobs|parallel_jobs|N|1|posint|Run up to N migrations at once (default 1)"
    "b|branch|branch_filter|BRANCH||string|Only repositories that have BRANCH checked out"
)
parse_options "$@"
require_args 0

source "$script_location/lib/common.sh"

if [ -n "$branch_filter" ] && ! is_valid_branch_name "$branch_filter"; then
    echo "'$branch_filter' is not a valid branch name"
    exit 2
fi

# Trim leading and trailing whitespace of $1 into trimmed_text.
trim_text() {
    trimmed_text="${1#"${1%%[![:space:]]*}"}"
    trimmed_text="${trimmed_text%"${trimmed_text##*[![:space:]]}"}"
}

# Split $1 on ';' outside single or double quotes into the migrate_entries array, so a
# command such as  docker compose exec -T app sh -c "a; b"  stays one entry.
# Fails (status 1) on an unterminated quote.
split_entries() {
    local text="$1" entry="" quote="" char index
    migrate_entries=()
    for ((index = 0; index < ${#text}; index++)); do
        char="${text:index:1}"
        if [ -n "$quote" ]; then
            [ "$char" == "$quote" ] && quote=""
        elif [ "$char" == "'" ] || [ "$char" == '"' ]; then
            quote="$char"
        elif [ "$char" == ";" ]; then
            migrate_entries+=("$entry")
            entry=""
            continue
        fi
        entry+="$char"
    done
    migrate_entries+=("$entry")
    [ -z "$quote" ]
}

# MIGRATE_CMDS="name:command; name2:command2" becomes two parallel indexed arrays (bash 3.2 has
# no associative arrays). Entries are split on ';' outside quotes, the name is the text before
# the first ':'.
migrate_names=()
migrate_commands=()
if ! split_entries "${MIGRATE_CMDS:-}"; then
    echo "Invalid MIGRATE_CMDS: unterminated quote in '${MIGRATE_CMDS}'"
    exit 2
fi
for migrate_entry in "${migrate_entries[@]}"; do
    trim_text "$migrate_entry"
    migrate_entry="$trimmed_text"
    [ -n "$migrate_entry" ] || continue # tolerate a trailing or doubled ';'
    case "$migrate_entry" in
    *:*) ;;
    *)
        echo "Invalid MIGRATE_CMDS entry '$migrate_entry': expected <repository>:<command>"
        exit 2
        ;;
    esac
    trim_text "${migrate_entry%%:*}"
    entry_name="$trimmed_text"
    trim_text "${migrate_entry#*:}"
    entry_command="$trimmed_text"
    if [ -z "$entry_name" ] || [ -z "$entry_command" ]; then
        echo "Invalid MIGRATE_CMDS entry '$migrate_entry': expected <repository>:<command>"
        exit 2
    fi
    for ((i = 0; i < ${#migrate_names[@]}; i++)); do
        if [ "${migrate_names[$i]}" == "$entry_name" ]; then
            echo "Invalid MIGRATE_CMDS entry '$migrate_entry': '$entry_name' is listed more than once"
            exit 2
        fi
    done
    migrate_names+=("$entry_name")
    migrate_commands+=("$entry_command")
done

if [ "${#migrate_names[@]}" -eq 0 ]; then
    echo "MIGRATE_CMDS is not set. Set it in the .env file, e.g. MIGRATE_CMDS=\"order-service:php artisan migrate --force; user-service:npm run migrate\""
    exit 1
fi

# Sets found_command to the command of the repository named $1; fails when it has none.
lookup_command() {
    local i
    for ((i = 0; i < ${#migrate_names[@]}; i++)); do
        if [ "${migrate_names[$i]}" == "$1" ]; then
            found_command="${migrate_commands[$i]}"
            return 0
        fi
    done
    return 1
}

echo "Target directory: ${green}$target_directory${reset}"
echo "Branch filter: ${green}${branch_filter:-any}${reset}"
echo "Jobs: ${green}$parallel_jobs${reset}"
echo "Dry run: ${green}$dry_run${reset}"

# Entries naming a repository that is not in the target directory are reported, not fatal
# (the same .env may be used with different -d targets).
list_repos
for name in "${migrate_names[@]}"; do
    known=""
    for child_directory in "${repo_list[@]}"; do
        if [ "$(get_directory_name "$child_directory")" == "$name" ]; then
            known="y"
        fi
    done
    if [ -z "$known" ]; then
        echo "${yellow}Warning: MIGRATE_CMDS names '$name', which is not a git repository in the target directory (or is listed in SKIP_DIRS). ignoring...${reset}"
    fi
done

# Runs the command of one repository; output to stdout, status 0 (done), 1 (failed) or 2 (skipped).
# Commands never read terminal input (stdin is /dev/null), so they run non-interactively, e.g.
# docker compose exec -T, and a command that would prompt fails instead of hanging.
migrate_repo_core() {
    local directory_name current_branch exit_code
    directory_name=$(get_directory_name "$1")
    lookup_command "$directory_name" || return 2 # no entry: silently skipped
    print_repo_header "$1"
    if [ -n "$branch_filter" ]; then
        current_branch=$(git -C "$1" branch --show-current)
        if [ "$current_branch" != "$branch_filter" ]; then
            echo "on ${current_branch:-a detached HEAD}, not $branch_filter. skipping..."
            return 2
        fi
    fi
    if $dry_run; then
        echo "Would run: $found_command"
        return 0
    fi
    echo "Running: $found_command"
    (cd "$1" && bash -c "$found_command") < /dev/null
    exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
        echo "${red}Migration failed in $directory_name (exit $exit_code)${reset}"
        return 1
    fi
    return 0
}

migrate_repo() {
    local outcome=0
    migrate_repo_core "$1" || outcome=$?
    case "$outcome" in
    0) mark_repo_done ;;
    2) mark_repo_skipped ;;
    *) mark_repo_failed ;;
    esac
}

# Worker for parallel runs
migrate_repo_job() {
    migrate_repo_core "$1"
}

if [ "$parallel_jobs" -gt 1 ]; then
    parallel_run migrate_repo_job "$parallel_jobs"
    parallel_apply_outcomes
else
    for_each_repo migrate_repo
fi
finish_run
