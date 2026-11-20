#!/usr/bin/env bats

load test_helper

setup_file() { build_fixture_template; }

setup() { setup_workspace; }

@test "checkout: switches repos that have the branch locally" {
    add_local_branch alpha feat
    add_local_branch beta feat
    add_local_branch skipme feat
    run_cmd checkout -d "$WS" feat
    assert_status 0
    assert_contains "Target directory: $WS"
    assert_contains "Branch to checkout: feat"
    assert_contains "Working directory alpha"
    assert_contains "Working directory beta"
    assert_contains "Checked out"
    refute_contains "Working directory gamma"
    refute_contains "Working directory skipme"
    refute_contains "Working directory plain"
    [ "$(current_branch alpha)" = feat ]
    [ "$(current_branch beta)" = feat ]
    [ "$(current_branch gamma)" = main ]
    [ "$(current_branch skipme)" = main ]
}

@test "checkout: no output for repos when the branch exists nowhere" {
    run_cmd checkout -d "$WS" nope
    assert_status 0
    refute_contains "Working directory"
}

@test "checkout: a branch that exists only on the remote is not checked out" {
    remote_only_branch alpha feat
    run_cmd checkout -d "$WS" feat
    refute_contains "Working directory alpha"
    [ "$(current_branch alpha)" = main ]
}

@test "checkout: already on the branch still reports Checked out" {
    add_local_branch alpha feat
    g alpha checkout -q feat
    run_cmd checkout -d "$WS" feat
    assert_contains "Working directory alpha"
    assert_contains "Checked out"
    [ "$(current_branch alpha)" = feat ]
}

@test "checkout: requires exactly one argument" {
    run_cmd checkout -d "$WS"
    assert_contains "1 argument required. 0 provided"
    run_cmd checkout -d "$WS" a b
    assert_contains "1 argument required. 2 provided"
    refute_contains "Working directory"
}
