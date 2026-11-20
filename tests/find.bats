#!/usr/bin/env bats

load test_helper

setup() { setup_workspace; }

@test "find: shows local and remote status per repo" {
    add_remote_branch alpha feat      # local + remote
    add_local_branch beta feat        # local only
    remote_only_branch gamma feat     # remote only
    add_local_branch skipme feat
    run_cmd find -d "$WS" feat
    assert_status 0
    assert_contains "Target directory           : $WS"
    assert_contains "Branch to find             : feat"
    assert_contains "Clear proxy                : false"
    assert_contains "| Directory"
    assert_contains "Local"
    assert_contains "Remote"
    case "$(table_row alpha)" in *✔*✔*) ;; *) echo "$output"; return 1 ;; esac
    case "$(table_row beta)" in *✔*✘*) ;; *) echo "$output"; return 1 ;; esac
    case "$(table_row gamma)" in *✘*✔*) ;; *) echo "$output"; return 1 ;; esac
}

@test "find: omits SKIP_DIRS repos and non-repos from the table" {
    run_cmd find -d "$WS" feat
    [ -z "$(table_row skipme)" ]
    [ -z "$(table_row plain)" ]
    case "$(table_row alpha)" in *✘*✘*) ;; *) echo "$output"; return 1 ;; esac
}

@test "find -c: clears the proxy" {
    run_cmd find -c -d "$WS" feat
    assert_contains "Clear proxy                : true"
    assert_contains "Cleared proxy"
}

@test "find: requires exactly one argument" {
    run_cmd find -d "$WS"
    assert_contains "1 argument required. 0 provided"
}

@test "find: border, header and every row have the same width in all three columns" {
    run_cmd find -d "$WS" main
    assert_status 0
    local line plain width="" count=0
    while IFS= read -r line; do
        case "$line" in
        "+"* | "| "*) ;;
        *) continue ;;
        esac
        plain="${line//✔/x}"
        plain="${plain//✘/x}"
        if [ -z "$width" ]; then width=${#plain}; fi
        [ "${#plain}" -eq "$width" ] || { echo "line width ${#plain} != $width: $line"; return 1; }
        count=$((count + 1))
    done <<< "$output"
    [ "$count" -ge 6 ]
}
