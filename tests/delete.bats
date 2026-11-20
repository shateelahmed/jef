#!/usr/bin/env bats

load test_helper

setup() { setup_workspace; }

@test "delete: removes the local branch and leaves the remote" {
    add_remote_branch alpha feat
    add_local_branch beta feat
    run_cmd delete -d "$WS" feat
    assert_status 0
    assert_contains "Branch to delete: feat"
    assert_contains "Clear proxy: false"
    assert_contains "Delete remote branch: false"
    assert_contains "local deleted: alpha"
    assert_contains "local deleted: beta"
    refute g alpha show-ref --quiet --heads feat
    refute g beta show-ref --quiet --heads feat
    origin_has_branch alpha feat
}

@test "delete: switches to DEFAULT_BRANCH first when the branch is checked out" {
    add_local_branch alpha feat
    g alpha checkout -q feat
    run_cmd delete -d "$WS" feat
    assert_contains "local deleted: alpha"
    [ "$(current_branch alpha)" = main ]
    refute g alpha show-ref --quiet --heads feat
}

@test "delete -r: also deletes the remote branch" {
    add_remote_branch alpha feat
    add_local_branch beta feat
    remote_only_branch gamma feat
    run_cmd delete -r -d "$WS" feat
    assert_status 0
    assert_contains "Delete remote branch: true"
    assert_contains "local & remote deleted: alpha"
    assert_contains "local deleted: beta"
    assert_contains "remote deleted: gamma"
    refute origin_has_branch alpha feat
    refute origin_has_branch gamma feat
}

@test "delete --delete-remote-branch is the long form of -r" {
    add_remote_branch alpha feat
    run_cmd delete --delete-remote-branch -d "$WS" feat
    assert_contains "local & remote deleted: alpha"
    refute origin_has_branch alpha feat
}

@test "delete -r: never deletes the remote default branch" {
    add_local_branch alpha feat
    g alpha checkout -q feat
    run_cmd delete -r -d "$WS" main
    assert_contains "main is the default branch in $WS/alpha/. It cannot be deleted."
    origin_has_branch alpha main
}

@test "delete: refuses when it cannot leave the branch being deleted" {
    # alpha is on main and DEFAULT_BRANCH is main, so main cannot be left.
    run_cmd delete -d "$WS" main
    assert_contains "Could not checkout to default branch in"
    g alpha show-ref --quiet --heads main
}

@test "delete: reports when the branch is found nowhere" {
    run_cmd delete -d "$WS" nope
    assert_status 0
    assert_contains "Branch not found in any repository"
}

@test "delete: leaves SKIP_DIRS repos alone" {
    add_local_branch skipme feat
    run_cmd delete -d "$WS" feat
    assert_contains "Branch not found in any repository"
    g skipme show-ref --quiet --heads feat
}

@test "delete: requires exactly one argument" {
    run_cmd delete -d "$WS"
    assert_contains "1 argument required. 0 provided"
}

@test "delete -r: the default branch comes from the local origin/HEAD ref" {
    # origin/HEAD points at develop while the real remote HEAD is main: only the
    # local ref can make develop "the default branch".
    add_remote_branch alpha develop
    g alpha fetch -q origin
    g alpha symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/develop
    run_cmd delete -r -d "$WS" develop
    assert_contains "develop is the default branch in $WS/alpha/. It cannot be deleted."
    origin_has_branch alpha develop
}

@test "delete -r: falls back to the remote when origin/HEAD is missing" {
    add_remote_branch alpha develop
    g alpha remote set-head origin -d 2> /dev/null || true
    refute g alpha symbolic-ref --quiet refs/remotes/origin/HEAD
    run_cmd delete -r -d "$WS" develop
    refute origin_has_branch alpha develop
    g alpha checkout -q -b other
    run_cmd delete -r -d "$WS" main
    assert_contains "main is the default branch in $WS/alpha/. It cannot be deleted."
}
