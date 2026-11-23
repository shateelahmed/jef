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

@test "merge: a branch that exists in no repository exits 2 and changes nothing" {
    add_local_branch alpha src
    run_cmd merge -d "$WS" src nosuch
    assert_status 2
    assert_contains "Branch 'nosuch' does not exist in any repository"
    refute_contains "Branch 'src' does not exist"
    refute_contains "Working directory"
    [ "$(current_branch alpha)" = main ]
    run_cmd merge -d "$WS" nosuch src
    assert_status 2
    assert_contains "Branch 'nosuch' does not exist in any repository"
    [ "$(current_branch alpha)" = main ]
}

@test "merge: both branches missing everywhere print both lines" {
    run_cmd merge -d "$WS" nosuch1 nosuch2
    assert_status 2
    assert_contains "Branch 'nosuch1' does not exist in any repository"
    assert_contains "Branch 'nosuch2' does not exist in any repository"
}

@test "merge: --dry-run also exits 2 for a branch that exists nowhere" {
    add_local_branch alpha src
    run_cmd merge -n -d "$WS" src nosuch
    assert_status 2
    assert_contains "Branch 'nosuch' does not exist in any repository"
    refute_contains "Would merge"
}

@test "merge: a branch present in only some repositories is not an error" {
    add_local_branch alpha src
    add_local_branch beta dst
    run_cmd merge -d "$WS" src dst
    assert_status 0
    assert_contains "Summary: 0 done, 0 failed, 3 skipped"
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
