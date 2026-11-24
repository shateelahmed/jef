#!/bin/bash
# Dispatcher: runs "jef-<command>" with the remaining arguments.

print_commands() {
    echo "Usage: jef <command> [options]"
    echo
    echo "Commands:"
    printf "  %-10s %s\n" "checkout" "Check out a local branch in every repository that has it"
    printf "  %-10s %s\n" "delete" "Delete a branch locally (and optionally on the remote) in every repository"
    printf "  %-10s %s\n" "fetch" "Run 'git fetch --all --prune' in every repository"
    printf "  %-10s %s\n" "find" "Show whether a branch exists locally and on the remote in each repository"
    printf "  %-10s %s\n" "merge" "Merge one branch into another in every repository that has both"
    printf "  %-10s %s\n" "merged" "List (and optionally delete) branches already merged into the default branch"
    printf "  %-10s %s\n" "migrate" "Run each repository's command from MIGRATE_CMDS (e.g. its database migration)"
    printf "  %-10s %s\n" "pull" "Fetch and pull a branch in every repository whose remote has it"
    printf "  %-10s %s\n" "push" "Push a branch to origin in every repository that has it locally"
    printf "  %-10s %s\n" "rebase" "Rebase one branch onto another in every repository that has both"
    printf "  %-10s %s\n" "stash" "Run 'git stash push' in every repository that has local changes"
    printf "  %-10s %s\n" "sync" "Pull the default branch and bring it into every other local branch, in every repository"
    printf "  %-10s %s\n" "which" "Show the currently checked out branch of each repository"
    printf "  %-10s %s\n" "help" "Show this list, or 'jef help <command>' for a command's options"
    echo
    echo "Run 'jef <command> --help' for the options of a command."
}

# Succeeds if "jef-<name>" is a command we can run
is_command() {
    case "$1" in
    "" | *[!a-z0-9_-]*) return 1 ;;
    esac
    command -v "jef-$1" > /dev/null 2>&1
}

unknown_command() {
    {
        echo "jef: unknown command '$1'"
        echo
        print_commands
    } >&2
    exit 127
}

if [ $# -eq 0 ]; then
    print_commands >&2
    exit 2
fi

command="$1"
shift

case "$command" in
-h | --help)
    print_commands
    exit 0
    ;;
help)
    if [ $# -eq 0 ] || [ "$1" = "help" ]; then
        print_commands
        exit 0
    fi
    is_command "$1" || unknown_command "$1"
    "jef-$1" --help
    exit $?
    ;;
esac

is_command "$command" || unknown_command "$command"

"jef-$command" "$@"
