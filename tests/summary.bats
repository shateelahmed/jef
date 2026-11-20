#!/usr/bin/env bats
# End-of-run summary and exit status 3 on repository failures.

load test_helper

setup_file() { build_fixture_template; }

setup() { setup_workspace; }

@test "summary: checkout counts done and skipped" {
    add_local_branch alpha feat
    run_cmd checkout -d "$WS" feat
    assert_status 0
    assert_contains "Summary: 1 done, 0 failed, 2 skipped"
}

@test "summary: checkout blocked by an untracked file fails and exits 3" {
    add_local_branch beta feat
    g beta checkout -q feat
    commit_on beta x.txt
    g beta checkout -q main
    echo local > "$WS/beta/x.txt"
    add_local_branch alpha feat
    run_cmd checkout -d "$WS" feat
    assert_status 3
    assert_contains "Could not checkout"
    assert_contains "Summary: 1 done, 1 failed, 1 skipped"
}

@test "summary: fetch counts done, and a failing fetch exits 3" {
    run_cmd fetch -d "$WS"
    assert_status 0
    assert_contains "Summary: 3 done, 0 failed, 0 skipped"
    g alpha remote set-url origin "$T/does-not-exist.git"
    run_cmd fetch -d "$WS"
    assert_status 3
    assert_contains "Summary: 2 done, 1 failed, 0 skipped"
}

@test "summary: pull counts done and skipped, a failing fetch exits 3" {
    add_remote_branch alpha feat
    g alpha branch -q --set-upstream-to=origin/feat feat
    run_cmd pull -d "$WS" feat
    assert_status 0
    assert_contains "Summary: 1 done, 0 failed, 2 skipped"
    g beta remote set-url origin "$T/does-not-exist.git"
    run_cmd pull -d "$WS" feat
    assert_status 3
    assert_contains "Summary: 1 done, 1 failed, 1 skipped"
}

@test "summary: merge counts done and skipped" {
    add_local_branch alpha dst
    add_local_branch alpha src
    run_cmd merge -d "$WS" src dst
    assert_status 0
    assert_contains "Summary: 1 done, 0 failed, 2 skipped"
}

@test "summary: a merge conflict fails the repo and exits 3" {
    add_local_branch alpha dst
    add_local_branch alpha src
    g alpha checkout -q src
    commit_on alpha c.txt
    g alpha checkout -q dst
    commit_on alpha c.txt
    add_local_branch beta dst
    add_local_branch beta src
    run_cmd merge -d "$WS" src dst
    assert_status 3
    assert_contains "Summary: 1 done, 1 failed, 1 skipped"
}

@test "summary: push counts done and skipped" {
    add_local_branch alpha feat
    run_cmd push -d "$WS" feat
    assert_status 0
    assert_contains "Summary: 1 done, 0 failed, 2 skipped"
}

@test "summary: a push rejected by origin fails the repo and exits 3" {
    add_remote_branch alpha feat
    remote_commit alpha feat r.txt
    g alpha checkout -q feat
    commit_on alpha l.txt
    add_local_branch beta feat
    run_cmd push -d "$WS" feat
    assert_status 3
    assert_contains "Summary: 1 done, 1 failed, 1 skipped"
    origin_has_branch beta feat
}

@test "summary: delete counts done and skipped; not-found message is kept" {
    add_local_branch alpha feat
    run_cmd delete -d "$WS" feat
    assert_status 0
    assert_contains "Summary: 1 done, 0 failed, 2 skipped"
    run_cmd delete -d "$WS" nope
    assert_status 0
    assert_contains "Branch not found in any repository"
    assert_contains "Summary: 0 done, 0 failed, 3 skipped"
}

@test "summary: delete that cannot leave the branch exits 3" {
    run_cmd delete -d "$WS" main
    assert_status 3
    assert_contains "Summary: 0 done, 3 failed, 0 skipped"
}

@test "summary: a remote that refuses the deletion fails the repo and exits 3" {
    add_remote_branch alpha feat
    add_remote_branch beta feat
    printf '#!/bin/sh\nexit 1\n' > "$ORIGINS/alpha.git/hooks/pre-receive"
    chmod +x "$ORIGINS/alpha.git/hooks/pre-receive"
    run_cmd delete -r -d "$WS" feat
    assert_status 3
    assert_contains "Summary: 1 done, 1 failed, 1 skipped"
    origin_has_branch alpha feat
    refute origin_has_branch beta feat
}

@test "summary: the line is plain text when not a terminal" {
    run_cmd fetch -d "$WS"
    case "$output" in
    *$'\033'*) echo "escape code found"; return 1 ;;
    esac
}
