#!/bin/bash
# shellcheck disable=SC2154,SC2034 # colour variables come from lib/terminal-color-codes.sh; cli_* are read by lib/cli.sh

# Check out a local branch in every repository that has it, or create a new branch from a base
# in the repositories the user picks (-b)

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

cli_name="checkout"
cli_description="Check out a local branch in every repository that has it"
cli_positionals="<branch> | -b <new_branch> <base>"
cli_extra_flags=(
    "b|new|create_new|Create <new_branch> from <base> and check it out in the repositories you pick"
)
cli_value_flags=(
    "m|repo|repo_filter|REPOS||list|With -b: create in these repositories instead of showing the picker (comma or space separated, repeatable)"
)
# Options may also follow the positionals (jef checkout -b feat main -m alpha): move them first,
# since getopts stops at the first positional argument.
leading_args=()
trailing_args=()
while [ $# -gt 0 ]; do
    case "$1" in
    -d | --directory | -m | --repo) # these take the next argument as their value
        leading_args+=("$1")
        if [ $# -gt 1 ]; then
            leading_args+=("$2")
            shift
        fi
        ;;
    -?*) leading_args+=("$1") ;;
    *) trailing_args+=("$1") ;;
    esac
    shift
done
set -- "${leading_args[@]}" "${trailing_args[@]}"

parse_options "$@"
if ! $create_new && [ -n "$repo_filter" ]; then
    usage_error "option '-m/--repo' can only be used with -b"
fi
if $create_new; then
    require_args 2
else
    require_args 1
fi

source "$script_location/lib/common.sh"

branch_to_checkout="${cli_positional[0]}"

if ! is_valid_branch_name "$branch_to_checkout"; then
    echo "'$branch_to_checkout' is not a valid branch name"
    exit 2
fi

if $create_new; then
    new_branch="$branch_to_checkout"
    base_ref="${cli_positional[1]}"
    if ! git check-ref-format --branch "$new_branch" > /dev/null 2>&1; then
        echo "'$new_branch' is not a valid branch name"
        exit 2
    fi
    case "$base_ref" in
    "" | -*)
        echo "'$base_ref' is not a valid base"
        exit 2
        ;;
    esac

    source "$script_location/lib/select.sh"

    echo "Target directory: ${green}$target_directory${reset}"
    echo "New branch: ${green}$new_branch${reset}"
    echo "Base: ${green}$base_ref${reset}"

    # Sets examined_reason (why repository $1 cannot get the new branch; empty when it can) and
    # examined_ref (what to branch from: the base, else origin/<base> when only that exists)
    examine_repo() {
        examined_reason=""
        examined_ref="$base_ref"
        if git -C "$1" show-ref --verify --quiet "refs/heads/$new_branch"; then
            examined_reason="branch exists"
        elif git -C "$1" rev-parse --verify --quiet "$base_ref^{commit}" > /dev/null; then
            :
        elif git -C "$1" rev-parse --verify --quiet "origin/$base_ref^{commit}" > /dev/null; then
            examined_ref="origin/$base_ref"
        else
            examined_reason="no $base_ref"
        fi
    }

    list_repos
    select_labels=()
    select_reasons=()
    select_refs=()
    any_available=false
    for child_directory in "${repo_list[@]}"; do
        examine_repo "$child_directory"
        select_labels+=("$(get_directory_name "$child_directory")")
        select_reasons+=("$examined_reason")
        select_refs+=("$examined_ref")
        [ -z "$examined_reason" ] && any_available=true
    done

    chosen_indexes=()
    if [ -n "$repo_filter" ]; then
        # Repositories named with -m, by directory name (unknown names exit 2, as in jef merged)
        set -f # the names are split on spaces below and must not be glob-expanded
        requested_names=${repo_filter//,/ }
        for requested_name in $requested_names; do
            requested_found=""
            for label in "${select_labels[@]}"; do
                if [ "$label" == "$requested_name" ]; then
                    requested_found="y"
                fi
            done
            if [ -z "$requested_found" ]; then
                set +f
                usage_error "unknown repository '$requested_name' (not a git repository in the target directory, or listed in SKIP_DIRS)"
            fi
        done
        for ((i = 0; i < ${#select_labels[@]}; i++)); do
            for requested_name in $requested_names; do
                if [ "${select_labels[$i]}" == "$requested_name" ]; then
                    chosen_indexes+=("$i")
                    break
                fi
            done
        done
        set +f
    elif [ -t 0 ] && [ -t 1 ]; then
        if ! $any_available; then
            for ((i = 0; i < ${#select_labels[@]}; i++)); do
                print_repo_header "${repo_list[$i]}"
                echo "Skipped: ${select_reasons[$i]}"
            done
            echo -e "\nNo repository can get $new_branch. Nothing was created."
            exit 1
        fi
        select_title="Select repositories to create $new_branch in:"
        echo
        if select_repos; then
            chosen_indexes=("${select_chosen[@]}")
        else
            echo "Aborted. Nothing was created."
            exit 1
        fi
    else
        echo "Not running in a terminal. Re-run with --repo to choose repositories. Nothing was created."
        exit 2
    fi

    create_repo() {
        local child_directory="$1" from_ref="$2" from_text=""
        print_repo_header "$child_directory"
        [ "$from_ref" != "$base_ref" ] && from_text=" from $from_ref" # the origin/<base> fallback
        # --no-track: never track the base (origin/main as upstream would send pushes to main)
        if git -C "$child_directory" checkout --no-track -b "$new_branch" "$from_ref" --; then
            echo "Created$from_text and checked out"
            mark_repo_done
        else
            echo "Could not create"
            mark_repo_failed
        fi
    }

    repos_done=0
    repos_failed=0
    repos_skipped=0
    for i in "${chosen_indexes[@]}"; do
        if [ -n "${select_reasons[$i]}" ]; then
            print_repo_header "${repo_list[$i]}"
            echo "Skipped: ${select_reasons[$i]}"
            mark_repo_skipped
        else
            create_repo "${repo_list[$i]}" "${select_refs[$i]}"
        fi
    done
    finish_run
    exit 0
fi

echo "Target directory: ${green}$target_directory${reset}"
echo "Branch to checkout: ${green}$branch_to_checkout${reset}"

checkout_repo() {
    local child_directory="$1" current_branch

    if ! git -C "$child_directory" show-ref --verify --quiet "refs/heads/$branch_to_checkout"; then
        mark_repo_skipped
        return # branch_to_checkout does not exist locally
    fi

    print_repo_header "$child_directory"

    current_branch=$(git -C "$child_directory" branch --show-current)
    if [ "$current_branch" != "$branch_to_checkout" ]; then  # if the current git branch is not "$branch_to_checkout"
        git -C "$child_directory" checkout "$branch_to_checkout" -- || true
        current_branch=$(git -C "$child_directory" branch --show-current)
    fi
    if [ "$current_branch" != "$branch_to_checkout" ]; then  # if the current git branch is not "$branch_to_checkout"
        echo "Could not checkout"
        mark_repo_failed
        return
    fi

    echo "Checked out"
    mark_repo_done
}

for_each_repo checkout_repo
finish_run
