# Check if a directory is a Git repository.
#
# A `.git` directory (normal clone) or `.git` file (linked worktree, submodule)
# both count.
#
# Args:
#   $1 (string): Directory path to check.
#
# Returns:
#   0 if the directory is a Git repository, 1 otherwise.
is_git_repo() {
    local directory="$1"

    [ -e "$directory/.git" ]
}

# Check that a string can be used as a branch name argument: it must be
# non-empty and must not start with "-" (git cannot create such branches, and
# the name would be read as an option).
#
# Args:
#   $1 (string): Branch name.
#
# Returns:
#   0 if usable, 1 otherwise.
is_valid_branch_name() {
    case "$1" in
    "" | -*) return 1 ;;
    esac
    return 0
}
