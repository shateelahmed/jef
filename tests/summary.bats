#!/usr/bin/env bats
# End-of-run summary, exit status 3 on repository failures, and --dry-run.

load test_helper

setup_file() { build_fixture_template; }

setup() { setup_workspace; }

# snapshot: every ref and HEAD of every workspace repo and origin, for before/after comparison.
snapshot() {
    local d
    for d in "$WS"/alpha "$WS"/beta "$WS"/gamma; do
        git -C "$d" symbolic-ref HEAD
        git -C "$d" for-each-ref
    done
    for d in "$ORIGINS"/*.git; do
        git --git-dir="$d" for-each-ref
    done
}

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

@test "dry-run: delete -r reports and changes nothing" {
    add_remote_branch alpha feat
    add_local_branch beta feat
    remote_only_branch gamma feat
    g alpha checkout -q feat
    local before after
    before=$(snapshot)
    run_cmd delete -n -r -d "$WS" feat
    assert_status 0
    assert_contains "Dry run: true"
    assert_contains "Would switch to main"
    assert_contains "Would delete local branch feat"
    assert_contains "Would delete remote branch feat"
    refute_contains "deleted:"
    assert_contains "Summary: 3 done, 0 failed, 0 skipped"
    after=$(snapshot)
    [ "$before" = "$after" ]
}

@test "dry-run: delete still reports a branch that cannot be left" {
    run_cmd delete --dry-run -d "$WS" main
    assert_status 3
    assert_contains "Could not checkout to default branch"
}

@test "dry-run: merge reports and changes nothing" {
    add_local_branch alpha dst
    add_local_branch alpha src
    g alpha checkout -q src
    commit_on alpha s.txt
    local before after
    before=$(snapshot)
    run_cmd merge --dry-run -d "$WS" src dst
    assert_status 0
    assert_contains "Dry run: true"
    assert_contains "Would merge src into dst"
    assert_contains "Summary: 1 done, 0 failed, 2 skipped"
    after=$(snapshot)
    [ "$before" = "$after" ]
}

@test "dry-run: push reports and changes nothing" {
    add_local_branch alpha feat
    local before after
    before=$(snapshot)
    run_cmd push -n -d "$WS" feat
    assert_status 0
    assert_contains "Dry run: true"
    assert_contains "Would push feat to origin"
    assert_contains "Summary: 1 done, 0 failed, 2 skipped"
    after=$(snapshot)
    [ "$before" = "$after" ]
    refute origin_has_branch alpha feat
}

@test "dry-run: off by default" {
    add_local_branch alpha feat
    run_cmd push -d "$WS" feat
    assert_contains "Dry run: false"
    refute_contains "Would push"
}

@test "dry-run: --help lists it for delete, merge and push only" {
    local cmd
    for cmd in delete merge push; do
        run_cmd "$cmd" --help
        assert_contains "-n, --dry-run"
    done
    for cmd in checkout fetch find pull which; do
        run_cmd "$cmd" --help
        refute_contains "--dry-run"
    done
}
