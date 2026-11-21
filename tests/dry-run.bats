#!/usr/bin/env bats
# --dry-run for the commands that change things.

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

@test "dry-run: --help lists it for delete, merge, migrate, push and rebase only" {
    local cmd
    for cmd in delete merge migrate push rebase; do
        run_cmd "$cmd" --help
        assert_contains "-n, --dry-run"
    done
    for cmd in checkout fetch find pull which; do
        run_cmd "$cmd" --help
        refute_contains "--dry-run"
    done
}
