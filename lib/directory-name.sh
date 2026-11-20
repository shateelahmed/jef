# Get the name of a directory from its path.
#
# Args:
#   $1 (string): Directory path.
#
# Returns:
#   Directory name.
get_directory_name() {
    # $1 is the first argument passed to the function
    local directory_path="$1"
    basename "${directory_path%/*}"
}
