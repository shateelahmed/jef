#!/bin/bash
# shellcheck disable=SC2154,SC2034 # colour variables come from lib/terminal-color-codes.sh; cli_* are read by lib/cli.sh

# Show each repository's branch, origin position, local changes, stashes and operation in progress

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

cli_name="status"
cli_description="Show each repository's branch, origin position, local changes, stashes and operation in progress"
cli_positionals=""
cli_accepts_proxy=true
cli_extra_flags=(
    "f|fetch|do_fetch|Run 'git fetch --prune origin' in every repository first (default: no network)"
)
cli_value_flags=(
    "m|repo|repo_filter|REPOS||list|Only these repositories: -m a,b or -m \"a b\" or -m a -m b (also --repo a, --repo=a,b)"
)
parse_options "$@"
require_args 0

source "$script_location/lib/common.sh"

echo "Target directory: ${green}$target_directory${reset}"
echo "Repositories: ${green}${repo_filter:-all}${reset}"
echo "Fetch: ${green}$do_fetch${reset}"
echo "Clear proxy: ${green}$clear_proxy${reset}"

source "$script_location/lib/clear-proxy.sh"

# Repositories: all of them, or only those named with -m (narrowed by list_repos)
list_repos

# origin_text <ahead> <behind>: the Origin column for a branch that exists on origin
origin_text() {
    if [ "$1" -gt 0 ] && [ "$2" -gt 0 ]; then
        echo "ahead $1, behind $2"
    elif [ "$1" -gt 0 ]; then
        echo "ahead $1"
    elif [ "$2" -gt 0 ]; then
        echo "behind $2"
    else
        echo "up to date"
    fi
}

# status_worker <directory>: the row of one repository as one tab-separated line on stdout
# (name, branch, origin, changes, stashes, state; plain text, the table adds the colours).
# Returns 1 when the fetch (-f) failed, 0 otherwise. Nothing here changes the repository: the
# only remote contact is the fetch, and only with -f. Git's own errors are kept off the output.
status_worker() {
    local directory="$1" name branch origin="" changes="" stashes="-" state="" sha counts ahead behind
    local conflicted=0 changed=0 untracked=0 code line stash_count status_rc=0
    name="$(get_directory_name "$directory")"
    if [ "$do_fetch" = true ]; then
        if ! GIT_TERMINAL_PROMPT=0 git -C "$directory" fetch --prune --quiet origin > /dev/null 2>&1; then
            status_rc=1
        fi
    fi

    branch="$(git -C "$directory" symbolic-ref -q --short HEAD 2> /dev/null)" || branch=""
    if [ -z "$branch" ]; then
        sha="$(git -C "$directory" rev-parse --short HEAD 2> /dev/null)" || sha="?"
        branch="(detached $sha)"
        origin="-"
    elif ! git -C "$directory" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        origin="not on origin"
    elif counts="$(git -C "$directory" rev-list --left-right --count "refs/heads/$branch...refs/remotes/origin/$branch" 2> /dev/null)"; then
        read -r ahead behind <<< "$counts"
        origin="$(origin_text "$ahead" "$behind")"
    else
        origin="-"
    fi
    if [ "$status_rc" -ne 0 ]; then
        origin="fetch failed"
    fi

    while IFS= read -r line; do
        [ -n "$line" ] || continue
        code="${line:0:2}"
        case "$code" in
        DD | AU | UD | UA | DU | AA | UU) conflicted=$((conflicted + 1)) ;;
        "??") untracked=$((untracked + 1)) ;;
        *) changed=$((changed + 1)) ;;
        esac
    done <<< "$(git -C "$directory" status --porcelain 2> /dev/null)"
    if [ "$conflicted" -gt 0 ]; then changes="$conflicted conflicted"; fi
    if [ "$changed" -gt 0 ]; then changes="${changes:+$changes, }$changed changed"; fi
    if [ "$untracked" -gt 0 ]; then changes="${changes:+$changes, }$untracked untracked"; fi
    changes="${changes:-clean}"

    stash_count="$(git -C "$directory" stash list 2> /dev/null | wc -l | tr -d ' ')"
    if [ -n "$stash_count" ] && [ "$stash_count" -gt 0 ]; then
        stashes="$stash_count"
    fi

    if git -C "$directory" rev-parse -q --verify MERGE_HEAD > /dev/null 2>&1; then
        state="merging"
    elif rebase_in_progress "$directory"; then
        state="rebasing"
    elif git -C "$directory" rev-parse -q --verify CHERRY_PICK_HEAD > /dev/null 2>&1; then
        state="cherry-picking"
    elif git -C "$directory" rev-parse -q --verify REVERT_HEAD > /dev/null 2>&1; then
        state="reverting"
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$branch" "$origin" "$changes" "$stashes" "$state"
    return "$status_rc"
}

# One worker per repository, all at once (at least one slot)
parallel_use_repo_list=true # parallel_run must run exactly these repositories
parallel_jobs=${#repo_list[@]}
if [ "$parallel_jobs" -lt 1 ]; then
    parallel_jobs=1
fi
parallel_run status_worker "$parallel_jobs"

# Rows, kept in parallel indexed arrays (bash 3.2 has no associative arrays)
rows_name=()
rows_branch=()
rows_origin=()
rows_changes=()
rows_stashes=()
rows_state=()
fetch_failed=false
for ((i = 0; i < ${#repo_list[@]}; i++)); do
    line="$(tail -n 1 "$parallel_dir/$i.out" 2> /dev/null)"
    if [ -z "$line" ]; then # a worker that printed nothing still gets a row
        line="$(printf '%s\t-\t-\t-\t-\t' "$(get_directory_name "${repo_list[$i]}")")"
    fi
    if [ "$(cat "$parallel_dir/$i.rc" 2> /dev/null)" != 0 ]; then
        fetch_failed=true
    fi
    IFS=$'\t' read -r row_name row_branch row_origin row_changes row_stashes row_state <<< "$line"
    rows_name[i]="$row_name"
    rows_branch[i]="$row_branch"
    rows_origin[i]="$row_origin"
    rows_changes[i]="$row_changes"
    rows_stashes[i]="$row_stashes"
    rows_state[i]="$row_state"
done

# colour_text <colour> <text>: the text in the colour (nothing for empty text, plain without a colour)
colour_text() {
    [ -n "$2" ] || return 0
    if [ -n "$1" ]; then
        printf '%s%s%s' "$1" "$2" "$reset"
    else
        printf '%s' "$2"
    fi
}

# origin_colour <origin>: green when up to date, red for a failed fetch, yellow otherwise
origin_colour() {
    case "$1" in
    "up to date") echo "$green" ;;
    "fetch failed") echo "$red" ;;
    "-") echo "" ;;
    *) echo "$yellow" ;;
    esac
}

# changes_text <changes>: clean green; conflicted counts red, the others yellow
changes_text() {
    local first rest
    case "$1" in
    clean) colour_text "$green" "$1" ;;
    *conflicted*)
        first="${1%%,*}"
        rest="${1#"$first"}"
        printf '%s%s%s%s%s' "$red" "$first" "$reset$yellow" "$rest" "$reset"
        ;;
    *) colour_text "$yellow" "$1" ;;
    esac
}

headers=(Repository Branch Origin Changes Stashes State)

# set_row_cells <index>: the six cells of row <index>, plain (cell_plain) and coloured (cell_text)
set_row_cells() {
    local i="$1" stash_text
    if [ "${rows_stashes[i]}" = "-" ]; then
        stash_text="-"
    else
        stash_text="$(colour_text "$yellow" "${rows_stashes[i]}")"
    fi
    cell_plain=("${rows_name[i]}" "${rows_branch[i]}" "${rows_origin[i]}" "${rows_changes[i]}" "${rows_stashes[i]}" "${rows_state[i]}")
    cell_text=(
        "${rows_name[i]}"
        "${rows_branch[i]}"
        "$(colour_text "$(origin_colour "${rows_origin[i]}")" "${rows_origin[i]}")"
        "$(changes_text "${rows_changes[i]}")"
        "$stash_text"
        "$(colour_text "$red" "${rows_state[i]}")"
    )
}

# print_table_line: the cells of cell_text, each padded on its plain text (cell_plain) to col_width
print_table_line() {
    local c line="" pad trailing
    for ((c = 0; c < 6; c++)); do
        pad=$((col_width[c] - ${#cell_plain[c]}))
        line+="${cell_text[c]}"
        if [ "$c" -lt 5 ]; then
            line+="$(printf '%*s' $((pad + 2)) '')"
        fi
    done
    trailing="${line##*[![:space:]]}" # padding after the last cell (none when State is empty)
    line="${line%"$trailing"}"
    echo "$line"
}

# Column widths: the widest plain value of each column, header included
col_width=()
for ((c = 0; c < 6; c++)); do
    col_width[c]=${#headers[c]}
done
for ((i = 0; i < ${#repo_list[@]}; i++)); do
    set_row_cells "$i"
    for ((c = 0; c < 6; c++)); do
        if [ "${#cell_plain[c]}" -gt "${col_width[c]}" ]; then
            col_width[c]=${#cell_plain[c]}
        fi
    done
done

echo
cell_plain=("${headers[@]}")
cell_text=("${headers[@]}")
print_table_line
for ((i = 0; i < ${#repo_list[@]}; i++)); do
    set_row_cells "$i"
    print_table_line
done

total=${#repo_list[@]}
with_changes=0
not_up_to_date=0
in_progress=0
for ((i = 0; i < total; i++)); do
    if [ "${rows_changes[i]}" != clean ]; then with_changes=$((with_changes + 1)); fi
    if [ "${rows_origin[i]}" != "up to date" ]; then not_up_to_date=$((not_up_to_date + 1)); fi
    if [ -n "${rows_state[i]}" ]; then in_progress=$((in_progress + 1)); fi
done
echo
repo_noun="repositories"
[ "$total" -eq 1 ] && repo_noun="repository"
echo "Total: $total $repo_noun, $with_changes with changes, $not_up_to_date not up to date, $in_progress in progress"

if [ "$fetch_failed" = true ]; then
    exit 3
fi
exit 0
