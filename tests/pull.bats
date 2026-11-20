#!/usr/bin/env bats

load test_helper

setup() { setup_workspace; }

@test "pull: fetches and pulls new upstream commits" {
    remote_commit alpha main new.txt
    run_cmd pull -d "$WS" main
    assert_status 0
    assert_contains "Branch to pull: main"
    assert_contains "Clear proxy: false"
    assert_contains "Working directory alpha"
    assert_contains "Working directory beta"
    refute_contains "Working directory skipme"
    refute_contains "Working directory plain"
    [ -f "$WS/alpha/new.txt" ]
}

@test "pull: only touches repos whose remote has the branch, and checks it out" {
    remote_commit alpha develop d.txt
    run_cmd pull -d "$WS" develop
    assert_contains "Working directory alpha"
    refute_contains "Working directory beta"
    [ "$(current_branch alpha)" = develop ]
    [ -f "$WS/alpha/d.txt" ]
    [ "$(current_branch beta)" = main ]
}

@test "pull: a local-only branch is ignored" {
    add_local_branch alpha localonly
    run_cmd pull -d "$WS" localonly
    refute_contains "Working directory"
}

@test "pull: requires exactly one argument" {
    run_cmd pull -d "$WS"
    assert_contains "1 argument required. 0 provided"
}

@test "pull: does not call ls-remote and fetches each repo once" {
    mkdir "$T/spy"
    JEF_REAL_GIT="$(command -v git)"
    export JEF_REAL_GIT JEF_SPY_LOG="$T/git-args.log"
    printf '#!/bin/bash\necho "$*" >> "$JEF_SPY_LOG"\nexec "$JEF_REAL_GIT" "$@"\n' > "$T/spy/git"
    chmod +x "$T/spy/git"
    PATH="$T/spy:$PATH" run_cmd pull -d "$WS" main
    assert_status 0
    refute grep -q "ls-remote" "$JEF_SPY_LOG"
    [ "$(grep -c " fetch " "$JEF_SPY_LOG")" -eq 3 ]
}

@test "pull: a branch deleted on the remote is pruned and the repo is skipped" {
    remote_only_branch alpha gone
    run_cmd pull -d "$WS" gone
    assert_contains "Working directory alpha"
    git --git-dir="$ORIGINS/alpha.git" branch -q -D gone
    run_cmd pull -d "$WS" gone
    refute_contains "Working directory"
}
