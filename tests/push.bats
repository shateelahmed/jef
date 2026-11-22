#!/usr/bin/env bats

load test_helper

setup_file() { build_fixture_template; }

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

@test "fixture isolation: clones push to this test's own origins, never the template's" {
    local tmpl="$BATS_FILE_TMPDIR/template" name
    for name in alpha beta gamma skipme; do
        [ "$(g "$name" remote get-url origin)" = "$ORIGINS/$name.git" ]
    done
    local before
    before="$(git --git-dir="$tmpl/origins/alpha.git" rev-parse main)"
    add_local_branch alpha feat
    commit_on alpha extra.txt
    run_cmd push -d "$WS" main
    assert_status 0
    [ "$(git --git-dir="$ORIGINS/alpha.git" rev-parse main)" = "$(g alpha rev-parse main)" ]
    [ "$(git --git-dir="$tmpl/origins/alpha.git" rev-parse main)" = "$before" ]
    refute git --git-dir="$tmpl/origins/alpha.git" show-ref --verify --quiet refs/heads/feat
}

setup_push_spy() {
    export JEF_REAL_GIT PUSH_LOG="$T/push.log"
    JEF_REAL_GIT="$(command -v git)"
    mkdir -p "$T/pspy"
    cat > "$T/pspy/git" <<'EOF'
#!/bin/bash
for a in "$@"; do [ "$a" = push ] && echo "push $*" >> "$PUSH_LOG"; done
exec "$JEF_REAL_GIT" "$@"
EOF
    chmod +x "$T/pspy/git"
    export PATH="$T/pspy:$PATH"
}

pushed_count() { if [ -f "$PUSH_LOG" ]; then grep -c . "$PUSH_LOG"; else echo 0; fi; }

@test "push: up to date branch is not pushed nor checked out" {
    add_remote_branch alpha feat
    setup_push_spy
    run_cmd push -d "$WS" feat
    assert_status 0
    assert_contains "Nothing to push"
    assert_contains "0 done, 0 failed, 3 skipped"
    [ "$(pushed_count)" = 0 ]
    [ "$(current_branch alpha)" = main ]
}

@test "push: up to date branch without upstream gets tracking set" {
    add_remote_branch alpha feat
    g alpha fetch -q origin
    refute g alpha rev-parse --abbrev-ref feat@{upstream}
    run_cmd push -d "$WS" feat
    assert_contains "Nothing to push"
    [ "$(g alpha rev-parse --abbrev-ref feat@{upstream})" = origin/feat ]
    [ "$(current_branch alpha)" = main ]
}

@test "push: new branch is pushed" {
    add_local_branch alpha feat
    run_cmd push -d "$WS" feat
    assert_status 0
    refute_contains "Nothing to push"
    origin_has_branch alpha feat
}

@test "push: reports the number of commits being pushed" {
    add_remote_branch alpha feat
    g alpha checkout -q feat
    commit_on alpha one.txt
    commit_on alpha two.txt
    run_cmd push -d "$WS" feat
    assert_status 0
    assert_contains "Pushing 2 commits"
    [ "$(g alpha rev-parse feat)" = "$(git --git-dir="$ORIGINS/alpha.git" rev-parse feat)" ]
    commit_on alpha three.txt
    run_cmd push -d "$WS" feat
    assert_contains "Pushing 1 commit"
    refute_contains "1 commits"
}

@test "push: a branch behind origin is not pushed" {
    add_remote_branch alpha feat
    remote_commit alpha feat r.txt
    g alpha fetch -q origin
    setup_push_spy
    run_cmd push -d "$WS" feat
    assert_status 0
    assert_contains "Nothing to push (behind origin)"
    assert_contains "0 done, 0 failed, 3 skipped"
    [ "$(pushed_count)" = 0 ]
    [ "$(current_branch alpha)" = main ]
}

@test "push: a diverged branch is attempted and fails" {
    add_remote_branch alpha feat
    g alpha checkout -q feat
    commit_on alpha mine.txt
    remote_commit alpha feat theirs.txt
    run_cmd push -d "$WS" feat
    assert_status 3
    assert_contains "1 failed"
}

@test "push: an unknown remote tip is attempted and fails" {
    add_remote_branch alpha feat
    remote_commit alpha feat r.txt
    setup_push_spy
    run_cmd push -d "$WS" feat
    assert_status 3
    [ "$(pushed_count)" = 1 ]
}

@test "push: unreachable origin fails the repo without pushing" {
    add_local_branch alpha feat
    g alpha remote set-url origin "$T/does-not-exist.git"
    setup_push_spy
    run_cmd push -d "$WS" feat
    assert_status 3
    assert_contains "Could not reach origin"
    [ "$(pushed_count)" = 0 ]
    [ "$(current_branch alpha)" = main ]
}

@test "push: dry run says nothing to push for an up to date branch" {
    add_remote_branch alpha feat
    run_cmd push -n -d "$WS" feat
    assert_status 0
    assert_contains "Nothing to push"
    refute_contains "Would push"
}

@test "push: dry run says nothing to push for a branch behind origin" {
    add_remote_branch alpha feat
    remote_commit alpha feat r.txt
    g alpha fetch -q origin
    run_cmd push -n -d "$WS" feat
    assert_contains "Nothing to push (behind origin)"
    refute_contains "Would push"
}

@test "push: dry run reports a new branch and the commit count without changing anything" {
    add_local_branch alpha feat
    add_remote_branch beta feat
    g beta checkout -q feat
    commit_on beta x.txt
    g beta checkout -q main
    run_cmd push -n -d "$WS" feat
    assert_status 0
    assert_contains "Would push feat to origin"
    assert_contains "Would push 1 commit"
    refute origin_has_branch alpha feat
    [ "$(current_branch alpha)" = main ]
    [ "$(current_branch beta)" = main ]
}
