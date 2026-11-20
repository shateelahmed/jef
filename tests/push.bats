#!/usr/bin/env bats

load test_helper

setup() { setup_workspace; }

@test "push: pushes the branch from repos that have it locally" {
    add_local_branch alpha feat
    add_local_branch beta feat
    add_local_branch skipme feat
    run_cmd push -d "$WS" feat
    assert_status 0
    assert_contains "Branch to push: feat"
    assert_contains "Clear proxy: false"
    assert_contains "Working directory alpha"
    assert_contains "Working directory beta"
    refute_contains "Working directory gamma"
    refute_contains "Working directory skipme"
    origin_has_branch alpha feat
    origin_has_branch beta feat
    refute origin_has_branch gamma feat
    refute origin_has_branch skipme feat
    [ "$(current_branch alpha)" = feat ]
    [ "$(g alpha rev-parse --abbrev-ref feat@{upstream})" = origin/feat ]
}

@test "push: pushes new commits on an already published branch" {
    add_remote_branch alpha feat
    g alpha checkout -q feat
    commit_on alpha p.txt
    run_cmd push -d "$WS" feat
    [ "$(g alpha rev-parse feat)" = "$(git --git-dir="$ORIGINS/alpha.git" rev-parse feat)" ]
}

@test "push: requires exactly one argument" {
    run_cmd push -d "$WS"
    assert_contains "1 argument required. 0 provided"
}
