# Prints the length (in characters) of the longest of the given arguments.
# Portable replacement for GNU `wc -L`, which BSD/macOS wc may lack.
max_length() {
    local max=0 item
    for item in "$@"; do
        if [ ${#item} -gt $max ]; then
            max=${#item}
        fi
    done
    echo "$max"
}
