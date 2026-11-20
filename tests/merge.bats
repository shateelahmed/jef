#!/usr/bin/env bats

load test_helper

setup_file() { build_fixture_template; }

setup() { setup_workspace; }

@test "merge: merges source into target in repos that have both branches" {
    add_local_branch alpha dst
    add_local_branch alpha src
    g alpha checkout -q src
    commit_on alpha s.txt
    add_local_branch beta src          # beta lacks dst: skipped
    run_cmd merge -d "$WS" src dst
    assert_status 0
    assert_contains "Source branch: src"
    assert_contains "Target branch: dst"
    assert_contains "Clear proxy: false"
    assert_contains "Working directory alpha"
    refute_contains "Working directory beta"
    [ "$(current_branch alpha)" = dst ]
    g alpha merge-base --is-ancestor src dst
    [ -f "$WS/alpha/s.txt" ]
}

@test "merge: skips SKIP_DIRS repos" {
    add_local_branch skipme dst
    add_local_branch skipme src
    run_cmd merge -d "$WS" src dst
    refute_contains "Working directory skipme"
}

@test "merge: requires exactly two arguments" {
    run_cmd merge -d "$WS" only-one
    assert_contains "2 arguments required. 1 provided"
    run_cmd merge -d "$WS"
    assert_contains "2 arguments required. 0 provided"
}
