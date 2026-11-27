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

# make_conflict <repo>: leaves a conflicted merge of feat into main in the repository (both change file.txt)
make_conflict() {
    g "$1" checkout -q -b feat
    echo "feat $RANDOM" > "$WS/$1/file.txt"
    g "$1" commit -q -am "feat"
    g "$1" checkout -q main
    echo "main $RANDOM" > "$WS/$1/file.txt"
    g "$1" commit -q -am "main"
    g "$1" merge -q feat > /dev/null 2>&1 || true
}

@test "merge --abort: aborts the conflicted merge in alpha, leaves beta alone and exits 0" {
    make_conflict alpha
    local head_before
    head_before=$(g alpha rev-parse HEAD)
    run_cmd merge --abort -d "$WS"
    assert_status 0
    assert_contains "Action: abort"
    assert_contains "Working directory alpha"
    assert_contains "Aborted the merge"
    assert_contains "1 done, 0 failed, 2 skipped"
    refute_contains "Working directory beta"
    [ -z "$(g alpha rev-parse -q --verify MERGE_HEAD)" ]
    [ -z "$(g alpha status --porcelain)" ]
    [ "$(g alpha rev-parse HEAD)" = "$head_before" ]
    refute grep -q "<<<<<<<" "$WS/alpha/file.txt"
}

@test "merge --abort: prints No merge in progress and exits 0 when no repository has a merge" {
    run_cmd merge --abort -d "$WS"
    assert_status 0
    assert_contains "Action: abort"
    assert_contains "No merge in progress"
    refute_contains "Working directory"
}

@test "merge --abort -n: prints Would abort the merge and keeps the merge in progress" {
    make_conflict alpha
    run_cmd merge --abort -n -d "$WS"
    assert_status 0
    assert_contains "Dry run: true"
    assert_contains "Working directory alpha"
    assert_contains "Would abort the merge"
    assert_contains "1 done, 0 failed, 2 skipped"
    refute_contains "Aborted the merge"
    [ -n "$(g alpha rev-parse -q --verify MERGE_HEAD)" ]
}

@test "merge --abort: a failing abort is reported, the others are still aborted, exit 3" {
    make_conflict alpha
    make_conflict beta
    # A stale index.lock makes git merge --abort fail (it resets the index); MERGE_HEAD stays.
    touch "$WS/alpha/.git/index.lock"
    run_cmd merge --abort -d "$WS"
    assert_status 3
    assert_contains "Working directory alpha"
    assert_contains "Could not abort the merge"
    assert_contains "Working directory beta"
    assert_contains "Aborted the merge"
    assert_contains "1 done, 1 failed, 1 skipped"
    [ -n "$(g alpha rev-parse -q --verify MERGE_HEAD)" ]
    [ -z "$(g beta rev-parse -q --verify MERGE_HEAD)" ]
}

@test "merge --abort: branch arguments are a usage error (exit 2) and change nothing" {
    make_conflict alpha
    run_cmd merge --abort -d "$WS" feat main
    assert_status 2
    assert_contains "--abort takes no branch arguments"
    refute_contains "Working directory"
    [ -n "$(g alpha rev-parse -q --verify MERGE_HEAD)" ]
}

@test "merge --help lists --abort" {
    run_cmd merge --help
    assert_status 0
    assert_contains "    --abort"
}

@test "merge -m: a branch that only an unnamed repository has is not found" {
    add_local_branch beta feat
    run_cmd merge -d "$WS" -m alpha feat main
    assert_status 2
    assert_contains "Branch 'feat' does not exist in any repository"
    refute_contains "Working directory"
    [ "$(current_branch alpha)" = main ]
}

@test "merge -m: merges only in the named repositories" {
    add_local_branch alpha dst
    add_local_branch alpha src
    g alpha checkout -q src
    commit_on alpha s.txt
    add_local_branch beta dst
    add_local_branch beta src
    run_cmd merge -d "$WS" -m alpha src dst
    assert_status 0
    assert_contains "Repositories: alpha"
    assert_contains "Working directory alpha"
    refute_contains "Working directory beta"
    [ "$(current_branch alpha)" = dst ]
    g alpha merge-base --is-ancestor src dst
    [ "$(current_branch beta)" = main ]
}

@test "merge --abort -m: aborts only in the named repositories" {
    g alpha checkout -q -b feat
    commit_on alpha file.txt
    g alpha checkout -q main
    commit_on alpha file.txt
    g alpha merge feat >/dev/null 2>&1 || true
    g beta checkout -q -b feat
    commit_on beta file.txt
    g beta checkout -q main
    commit_on beta file.txt
    g beta merge feat >/dev/null 2>&1 || true
    [ -f "$WS/alpha/.git/MERGE_HEAD" ]
    [ -f "$WS/beta/.git/MERGE_HEAD" ]
    run_cmd merge --abort -d "$WS" -m alpha
    assert_status 0
    refute_contains "Working directory beta"
    [ ! -f "$WS/alpha/.git/MERGE_HEAD" ]
    [ -f "$WS/beta/.git/MERGE_HEAD" ]
}
