#!/usr/bin/env bats
# Cross-cutting behaviour shared by every command: target directory, usage errors.

load test_helper

setup_file() { build_fixture_template; }

setup() { setup_workspace; }

# "<command>:<arguments>" specs that are valid and safe to run on the workspace.
SPECS="checkout:feat delete:feat fetch: find:feat merge:main,main pull:main push:main which:"

# run_spec <spec> [extra options...]: run one spec with the options first.
run_spec() {
    local spec="$1" cmd args
    shift
    cmd="${spec%%:*}"
    args="${spec#*:}"
    # shellcheck disable=SC2086
    run_cmd "$cmd" "$@" ${args//,/ }
}

@test "-d sets the target directory and beats TARGET_DIR" {
    write_env "$T/does-not-exist" "skipme" "main"
    local spec
    for spec in $SPECS; do
        run_spec "$spec" -d "$WS"
        assert_contains "$WS"
        refute_contains "is not a valid directory"
    done
}

@test "--directory is the long form of -d" {
    write_env "$T/does-not-exist" "skipme" "main"
    run_cmd which --directory "$WS"
    assert_contains "$WS"
    refute_contains "is not a valid directory"
}

@test "-d is used even when TARGET_DIR points at another workspace" {
    mkdir "$T/other"
    make_repo otherrepo "$T/other"
    write_env "$T/other" "skipme" "main"
    run_cmd fetch -d "$WS"
    assert_contains "Target directory: $WS"
    assert_contains "Working directory: alpha"
    refute_contains "otherrepo"
}

@test "TARGET_DIR from .env is the fallback when -d is absent" {
    write_env "$WS" "skipme" "main"
    run_cmd fetch
    assert_contains "Target directory: $WS"
    assert_contains "Working directory: alpha"
    run_cmd which
    case "$(table_row alpha)" in *main*) ;; *) echo "$output"; return 1 ;; esac
}

@test "no -d and no TARGET_DIR prints a hint and exits 1" {
    local spec
    for spec in $SPECS; do
        run_spec "$spec"
        assert_contains "Target directory is not set"
        [ "$status" -eq 1 ] || { echo "$spec exited $status with no target directory"; return 1; }
    done
}

@test "a nonexistent target directory is reported and exits 1" {
    local spec
    for spec in $SPECS; do
        run_spec "$spec" -d "$T/nope"
        assert_contains "$T/nope is not a valid directory"
        [ "$status" -eq 1 ] || { echo "$spec exited $status on a bad directory"; return 1; }
    done
}

@test "exit code: a usage error exits with 2" {
    local cmd
    for cmd in checkout delete find merge pull push; do
        run_cmd "$cmd" -d "$WS"
        [ "$status" -eq 2 ] || { echo "$cmd exited $status on a usage error"; return 1; }
    done
}

@test "exit code: an unknown option exits with 2" {
    local spec
    for spec in $SPECS; do
        run_spec "$spec" -d "$WS" -z
        [ "$status" -eq 2 ] || { echo "$spec exited $status on an unknown option"; return 1; }
    done
}

@test "branch names starting with a dash are rejected with exit 2" {
    local cmd
    for cmd in checkout delete find pull push; do
        run_cmd "$cmd" -d "$WS" -- -x
        [ "$status" -eq 2 ] || { echo "$cmd exited $status"; return 1; }
        assert_contains "'-x' is not a valid branch name"
    done
    run_cmd merge -d "$WS" -- main -x
    [ "$status" -eq 2 ]
}
