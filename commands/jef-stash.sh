#!/bin/bash
# shellcheck disable=SC2154,SC2034 # colour variables come from lib/terminal-color-codes.sh; cli_* are read by lib/cli.sh

# Run 'git stash push' in every repository that has local changes (-u also stashes untracked files).
# --clear, --pop and --list act on the existing stashes instead (one at a time).

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

cli_name="stash"
cli_description="Run 'git stash push' in every repository that has local changes"
cli_positionals=""
cli_extra_flags=(
    "u|include-untracked|include_untracked|Also stash untracked files"
    "n|dry-run|dry_run|Show what would happen without changing anything"
    "|clear|clear_stashes|Run 'git stash clear' in every repository that has stashes (asks first)"
    "y|yes|assume_yes|With --clear: clear without asking for confirmation"
    "|pop|pop_stash|Run 'git stash pop' (the latest stash) in every repository that has one"
    "|list|list_stashes|List the stashes of every repository (changes nothing)"
)
cli_value_flags=(
    "m|repo|repo_filter|REPOS||list|Only these repositories: -m a,b or -m \"a b\" or -m a -m b (also --repo a, --repo=a,b)"
)
parse_options "$@"
require_args 0

action_count=0
action="stash"
if $clear_stashes; then
    action="clear"
    action_count=$((action_count + 1))
fi
if $pop_stash; then
    action="pop"
    action_count=$((action_count + 1))
fi
if $list_stashes; then
    action="list"
    action_count=$((action_count + 1))
fi
if [ "$action_count" -gt 1 ]; then
    usage_error "options --clear, --pop and --list cannot be combined"
fi
if [ "$action_count" -eq 1 ] && $include_untracked; then
    usage_error "option '-u/--include-untracked' cannot be used with --clear, --pop or --list"
fi
if ! $clear_stashes && $assume_yes; then
    usage_error "option '-y/--yes' can only be used with --clear"
fi
if $list_stashes && $dry_run; then
    usage_error "option '-n/--dry-run' cannot be used with --list"
fi

source "$script_location/lib/common.sh"
source "$script_location/lib/confirm.sh"

echo "Target directory: ${green}$target_directory${reset}"
echo "Repositories: ${green}${repo_filter:-all}${reset}"
echo "Action: ${green}$action${reset}"
if [ "$action" = stash ]; then
    echo "Include untracked: ${green}$include_untracked${reset}"
fi
if [ "$action" != list ]; then
    echo "Dry run: ${green}$dry_run${reset}"
fi

# "1 stash" or "N stashes"
stash_count_text() {
    if [ "$1" -eq 1 ]; then
        echo "1 stash"
    else
        echo "$1 stashes"
    fi
}

# Number of stash entries in repository $1
stash_count() {
    git -C "$1" stash list | wc -l | tr -d ' '
}

if $clear_stashes; then
    repos_done=0
    repos_failed=0
    repos_skipped=0
    clear_dirs=()
    clear_counts=()
    clear_total=0
    list_repos
    for child_directory in "${repo_list[@]}"; do
        count=$(stash_count "$child_directory")
        if [ "$count" -gt 0 ]; then
            clear_dirs+=("$child_directory")
            clear_counts+=("$count")
            clear_total=$((clear_total + count))
        else
            mark_repo_skipped
        fi
    done
    if [ "${#clear_dirs[@]}" -eq 0 ]; then
        echo
        echo "No stashes to clear"
        exit 0
    fi

    echo
    if $dry_run; then
        echo "Would clear these stashes:"
    else
        echo "Will clear these stashes:"
    fi
    for ((i = 0; i < ${#clear_dirs[@]}; i++)); do
        echo "  $(get_directory_name "${clear_dirs[$i]}"): $(stash_count_text "${clear_counts[$i]}")"
    done
    echo

    if $dry_run; then
        for ((i = 0; i < ${#clear_dirs[@]}; i++)); do
            mark_repo_done
        done
        finish_run
        exit 0
    fi

    repo_noun="repositories"
    if [ "${#clear_dirs[@]}" -eq 1 ]; then
        repo_noun="repository"
    fi
    confirm_or_exit "Clear $(stash_count_text "$clear_total") in ${#clear_dirs[@]} $repo_noun?" clear cleared

    for ((i = 0; i < ${#clear_dirs[@]}; i++)); do
        print_repo_header "${clear_dirs[$i]}"
        if git -C "${clear_dirs[$i]}" stash clear; then
            echo "Cleared $(stash_count_text "${clear_counts[$i]}")"
            mark_repo_done
        else
            echo "Could not clear"
            mark_repo_failed
        fi
    done
    finish_run
    exit 0
fi

if $pop_stash; then
    pop_repo() {
        local child_directory="$1" subject
        if [ "$(stash_count "$child_directory")" -eq 0 ]; then
            mark_repo_skipped
            return # nothing to pop
        fi

        print_repo_header "$child_directory"
        subject=$(git -C "$child_directory" stash list -1 --format=%gs)

        if $dry_run; then
            echo "Would pop stash@{0}: $subject"
            mark_repo_done
            return
        fi

        if git -C "$child_directory" stash pop; then
            echo "Popped stash@{0}: $subject"
            mark_repo_done
        else
            echo "Could not pop (the stash is kept)"
            mark_repo_failed
        fi
    }

    for_each_repo pop_repo
    finish_run
    exit 0
fi

if $list_stashes; then
    list_dirs=()
    list_counts=()
    list_total=0
    list_repos
    for child_directory in "${repo_list[@]}"; do
        count=$(stash_count "$child_directory")
        if [ "$count" -gt 0 ]; then
            list_dirs+=("$child_directory")
            list_counts+=("$count")
            list_total=$((list_total + count))
        fi
    done
    if [ "${#list_dirs[@]}" -eq 0 ]; then
        echo
        echo "No stashes"
        exit 0
    fi

    repo_noun="repositories"
    if [ "${#list_dirs[@]}" -eq 1 ]; then
        repo_noun="repository"
    fi
    echo
    echo "Total: $(stash_count_text "$list_total") in ${#list_dirs[@]} $repo_noun"
    for ((i = 0; i < ${#list_dirs[@]}; i++)); do
        echo
        echo "${green}$(get_directory_name "${list_dirs[$i]}") (${list_counts[$i]})${reset}"
        index=0
        while IFS='|' read -r when subject; do
            echo "  - ${cyan}stash@{$index}${reset} (${when:0:16}) $subject"
            index=$((index + 1))
        done <<< "$(git -C "${list_dirs[$i]}" stash list --date=iso --format='%cd|%gs')"
    done
    exit 0
fi

stash_repo() {
    local child_directory="$1" changes stash_flags=()

    if $include_untracked; then
        changes=$(git -C "$child_directory" status --porcelain)
        stash_flags+=(--include-untracked)
    else
        changes=$(git -C "$child_directory" status --porcelain --untracked-files=no)
    fi
    if [ -z "$changes" ]; then
        mark_repo_skipped
        return # nothing to stash
    fi

    print_repo_header "$child_directory"

    if $dry_run; then
        echo "Would stash"
        mark_repo_done
        return
    fi

    if git -C "$child_directory" stash push "${stash_flags[@]}"; then
        echo "Stashed"
        mark_repo_done
    else
        echo "Could not stash"
        mark_repo_failed
    fi
}

for_each_repo stash_repo
finish_run
