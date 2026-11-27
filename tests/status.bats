#!/usr/bin/env bats

load test_helper

setup_file() { build_fixture_template; }

setup() { setup_workspace; }

# row_of <name>: the table row of repository <name> with its columns joined by "|" (the table
# pads with two or more spaces and no value contains a double space)
row_of() {
    printf '%s\n' "$output" | grep "^$1 " | sed 's/   */|/g'
}

# assert_row <name> <expected>: the row of <name> is exactly <expected> (columns joined by "|")
assert_row() {
    local got
    got="$(row_of "$1")"
    [ "$got" = "$2" ] || {
        echo "row $1: expected '$2', got '$got'"
        echo "--- output ---"
        echo "$output"
        return 1
    }
}

# repo_snapshot: everything a status run must leave alone in alpha
repo_snapshot() {
    {
        g alpha rev-parse HEAD
        g alpha branch --list
        g alpha status --porcelain
        g alpha stash list
        g alpha for-each-ref
    } 2>&1
}

@test "status: one row per repository, a clean repository is up to date and clean" {
    run_cmd status -d "$WS"
    assert_status 0
    assert_contains "Target directory: $WS"
    assert_contains "Repositories: all"
    assert_contains "Fetch: false"
    assert_contains "Clear proxy: false"
    [ "$(row_of Repository)" = "Repository|Branch|Origin|Changes|Stashes|State" ]
    assert_row alpha "alpha|main|up to date|clean|-"
    assert_row beta "beta|main|up to date|clean|-"
    assert_row gamma "gamma|main|up to date|clean|-"
}

@test "status: SKIP_DIRS and directories that are not git repositories have no row" {
    run_cmd status -d "$WS"
    assert_status 0
    refute_contains "skipme"
    refute_contains "plain"
    refute_contains "loose-file"
}

@test "status: ahead 2 and behind 1 of origin" {
    branch_with_commit alpha feat
    remote_commit alpha feat r.txt
    g alpha fetch -q origin
    g alpha checkout -q feat
    commit_on alpha a1.txt
    commit_on alpha a2.txt
    run_cmd status -d "$WS"
    assert_status 0
    assert_row alpha "alpha|feat|ahead 2, behind 1|clean|-"
}

@test "status: a branch that is not on origin shows not on origin" {
    g alpha checkout -q -b loc
    run_cmd status -d "$WS"
    assert_status 0
    assert_row alpha "alpha|loc|not on origin|clean|-"
}

@test "status: a detached HEAD shows its short sha and no origin position" {
    g alpha checkout -q --detach
    run_cmd status -d "$WS"
    assert_status 0
    local row
    row="$(row_of alpha)"
    case "$row" in
    "alpha|(detached "*")|-|clean|-") ;;
    *)
        echo "unexpected row: $row"
        return 1
        ;;
    esac
}

@test "status: modified and untracked files are counted as changed and untracked" {
    commit_on alpha a.txt
    commit_on alpha b.txt
    g alpha push -q origin main 2> /dev/null
    echo "more" >> "$WS/alpha/a.txt"
    echo "more" >> "$WS/alpha/b.txt"
    echo "new" > "$WS/alpha/c.txt"
    run_cmd status -d "$WS"
    assert_status 0
    assert_row alpha "alpha|main|up to date|2 changed, 1 untracked|-"
}

@test "status: a conflicted merge shows 1 conflicted and merging" {
    g alpha checkout -q -b side
    commit_on alpha c.txt
    g alpha checkout -q main
    commit_on alpha c.txt
    g alpha merge -q side > /dev/null 2>&1 || true
    run_cmd status -d "$WS"
    assert_status 0
    assert_row alpha "alpha|main|ahead 1|1 conflicted|-|merging"
}

@test "status: two stash entries show 2 in Stashes" {
    echo "one" >> "$WS/alpha/file.txt"
    g alpha stash push -q
    echo "two" >> "$WS/alpha/file.txt"
    g alpha stash push -q
    run_cmd status -d "$WS"
    assert_status 0
    assert_row alpha "alpha|main|up to date|clean|2"
}

@test "status: totals line counts repositories, changes, origin position and progress; exit 0" {
    echo "x" > "$WS/alpha/new.txt"
    commit_on beta extra.txt
    run_cmd status -d "$WS"
    assert_status 0
    assert_contains "Total: 3 repositories, 1 with changes, 1 not up to date, 0 in progress"
}

@test "status: without -f origin is as last fetched, with -f it is fetched first" {
    remote_commit alpha main r.txt
    run_cmd status -d "$WS"
    assert_status 0
    assert_row alpha "alpha|main|up to date|clean|-"
    run_cmd status -f -d "$WS"
    assert_status 0
    assert_row alpha "alpha|main|behind 1|clean|-"
}

@test "status -f: an unreachable origin shows fetch failed, the other rows stay and exit is 3" {
    g alpha remote set-url origin "$T/nowhere.git"
    run_cmd status -f -d "$WS"
    assert_status 3
    assert_row alpha "alpha|main|fetch failed|clean|-"
    assert_row beta "beta|main|up to date|clean|-"
    assert_contains "Total: 3 repositories"
}

@test "status -m: only the named repository, and the totals count 1" {
    run_cmd status -m alpha -d "$WS"
    assert_status 0
    assert_row alpha "alpha|main|up to date|clean|-"
    refute_contains "beta"
    refute_contains "gamma"
    assert_contains "Total: 1 repository, 0 with changes, 0 not up to date, 0 in progress"
}

@test "status -m: an unknown repository is a usage error (exit 2)" {
    run_cmd status -m nosuch -d "$WS"
    assert_status 2
    assert_contains "unknown repository 'nosuch'"
}

@test "status changes nothing: HEAD, branches, working tree, stashes and refs are untouched" {
    commit_on alpha ahead.txt
    echo "dirty" >> "$WS/alpha/file.txt"
    echo "x" > "$WS/alpha/new.txt"
    g alpha stash push -q
    before="$(repo_snapshot)"
    run_cmd status -d "$WS"
    assert_status 0
    after="$(repo_snapshot)"
    [ "$before" = "$after" ] || {
        echo "status changed the repository"
        echo "before: $before"
        echo "after: $after"
        return 1
    }
}

@test "status: a repository with no commits yet still gets a row" {
    mkdir "$WS/fresh"
    git -C "$WS/fresh" init -q -b main
    run_cmd status -d "$WS"
    assert_status 0
    assert_row fresh "fresh|main|not on origin|clean|-"
}
