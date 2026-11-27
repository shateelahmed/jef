#!/usr/bin/env bats

load test_helper

setup_file() { build_fixture_template; }

setup() { setup_workspace; }

# change_tracked <repo>: modify the tracked file.txt of a repository
change_tracked() { echo "changed $RANDOM" >> "$WS/$1/file.txt"; }

@test "stash: stashes a modified tracked file and prints Stashed" {
    change_tracked alpha
    run_cmd stash -d "$WS"
    assert_status 0
    assert_contains "Working directory alpha"
    assert_contains "Stashed"
    assert_contains "1 done, 0 failed, 2 skipped"
    [ "$(g alpha stash list | wc -l | tr -d ' ')" = 1 ]
    [ -z "$(g alpha status --porcelain)" ]
}

@test "stash: repositories without changes print nothing" {
    change_tracked alpha
    run_cmd stash -d "$WS"
    assert_status 0
    refute_contains "Working directory beta"
    refute_contains "Working directory gamma"
    refute_contains "Working directory plain"
}

@test "stash: untracked-only repository is skipped without -u and stashed with -u" {
    echo new > "$WS/beta/new.txt"
    run_cmd stash -d "$WS"
    assert_status 0
    refute_contains "Working directory beta"
    [ -f "$WS/beta/new.txt" ]
    run_cmd stash -u -d "$WS"
    assert_status 0
    assert_contains "Include untracked: true"
    assert_contains "Working directory beta"
    assert_contains "Stashed"
    [ ! -e "$WS/beta/new.txt" ]
    [ -z "$(g beta status --porcelain)" ]
}

@test "stash: dry run prints Would stash and leaves the change" {
    change_tracked alpha
    run_cmd stash -n -d "$WS"
    assert_status 0
    assert_contains "Dry run: true"
    assert_contains "Would stash"
    assert_contains "1 done, 0 failed, 2 skipped"
    refute_contains "Stashed"
    [ -n "$(g alpha status --porcelain)" ]
    [ -z "$(g alpha stash list)" ]
}

@test "stash: repositories in SKIP_DIRS are not touched" {
    change_tracked skipme
    run_cmd stash -d "$WS"
    assert_status 0
    refute_contains "Working directory skipme"
    [ -n "$(g skipme status --porcelain)" ]
}

@test "stash: takes no arguments" {
    run_cmd stash -d "$WS" extra
    assert_status 2
    assert_contains "0 arguments required. 1 provided"
    refute_contains "Working directory"
}

@test "stash: a failing git stash is reported, the others are still stashed, exit 3" {
    change_tracked alpha
    change_tracked beta
    # A stale index.lock makes git stash push fail (it cannot write the index);
    # git status still reads the repository.
    touch "$WS/alpha/.git/index.lock"
    run_cmd stash -d "$WS"
    assert_status 3
    assert_contains "Working directory alpha"
    assert_contains "Could not stash"
    assert_contains "Working directory beta"
    assert_contains "1 done, 1 failed, 1 skipped"
    [ -n "$(g alpha status --porcelain)" ]
    [ -z "$(g beta status --porcelain)" ]
}

# make_stash <repo>: one stash entry in the repository (a changed tracked file, stashed)
make_stash() {
    change_tracked "$1"
    g "$1" stash push -q
}

# stash_count <repo>: the number of stash entries in the repository
stash_count() { g "$1" stash list | wc -l | tr -d ' '; }

# stash_tty <input> <args...>: run jef stash on a fake terminal that answers the prompt with <input>
stash_tty() {
    local input="$1"
    shift
    run_tty "$input" "$JEF_BASH" "$JEF_HOME/commands/jef-stash.sh" "$@"
}

@test "stash --clear -y: clears the stashes of the repositories that have some" {
    make_stash alpha
    make_stash alpha
    run_cmd stash --clear -y -d "$WS"
    assert_status 0
    assert_contains "Action: clear"
    assert_contains "Will clear these stashes:"
    assert_contains "  alpha: 2 stashes"
    assert_contains "Working directory alpha"
    assert_contains "Cleared 2 stashes"
    assert_contains "1 done, 0 failed, 2 skipped"
    refute_contains "Working directory beta"
    refute_contains "beta:"
    [ "$(stash_count alpha)" = 0 ]
}

@test "stash --clear: no stashes anywhere prints No stashes to clear and asks nothing" {
    run_cmd stash --clear -d "$WS"
    assert_status 0
    assert_contains "No stashes to clear"
    refute_contains "[y/N]"
    refute_contains "Will clear"
}

@test "stash --clear: no terminal and no -y exits 2 and keeps the stashes" {
    make_stash alpha
    run_cmd stash --clear -d "$WS"
    assert_status 2
    assert_contains "Not running in a terminal. Re-run with --yes to clear. Nothing was cleared."
    [ "$(stash_count alpha)" = 1 ]
}

@test "stash --clear: answering n aborts with exit 1 and keeps the stashes" {
    make_stash alpha
    make_stash alpha
    stash_tty n --clear -d "$WS"
    assert_status 1
    assert_contains "Clear 2 stashes in 1 repository? [y/N]"
    assert_contains "Aborted. Nothing was cleared."
    [ "$(stash_count alpha)" = 2 ]
}

@test "stash --clear: answering y clears" {
    make_stash alpha
    stash_tty y --clear -d "$WS"
    assert_status 0
    assert_contains "Cleared 1 stash"
    [ "$(stash_count alpha)" = 0 ]
}

@test "stash --clear -n: prints the plan under Would clear and keeps the stashes without asking" {
    make_stash alpha
    run_cmd stash --clear -n -d "$WS"
    assert_status 0
    assert_contains "Dry run: true"
    assert_contains "Would clear these stashes:"
    assert_contains "  alpha: 1 stash"
    assert_contains "1 done, 0 failed, 2 skipped"
    refute_contains "[y/N]"
    refute_contains "Cleared"
    [ "$(stash_count alpha)" = 1 ]
}

@test "stash: --clear with -u is a usage error" {
    make_stash alpha
    run_cmd stash --clear -u -d "$WS"
    assert_status 2
    assert_contains "option '-u/--include-untracked' cannot be used with --clear"
    [ "$(stash_count alpha)" = 1 ]
}

@test "stash: -y without --clear is a usage error" {
    run_cmd stash -y -d "$WS"
    assert_status 2
    assert_contains "option '-y/--yes' can only be used with --clear"
    refute_contains "Working directory"
}

@test "stash --pop: restores the change, empties the stash list and skips repos without stashes" {
    make_stash alpha
    run_cmd stash --pop -d "$WS"
    assert_status 0
    assert_contains "Action: pop"
    assert_contains "Working directory alpha"
    assert_contains "Popped stash@{0}: WIP on main"
    assert_contains "1 done, 0 failed, 2 skipped"
    refute_contains "Working directory beta"
    refute_contains "beta:"
    [ -n "$(g alpha status --porcelain)" ]
    [ "$(stash_count alpha)" = 0 ]
}

@test "stash --pop -n: previews with Would pop and keeps the stash" {
    make_stash alpha
    run_cmd stash --pop -n -d "$WS"
    assert_status 0
    assert_contains "Dry run: true"
    assert_contains "Would pop stash@{0}: WIP on main"
    assert_contains "1 done, 0 failed, 2 skipped"
    refute_contains "Popped"
    [ -z "$(g alpha status --porcelain)" ]
    [ "$(stash_count alpha)" = 1 ]
}

@test "stash --pop: a conflicting local change fails the repo, keeps the stash and exits 3" {
    make_stash alpha
    echo "conflicting local change" > "$WS/alpha/file.txt"
    run_cmd stash --pop -d "$WS"
    assert_status 3
    assert_contains "Working directory alpha"
    assert_contains "Could not pop (the stash is kept)"
    assert_contains "0 done, 1 failed, 2 skipped"
    [ "$(stash_count alpha)" = 1 ]
}

@test "stash --pop: restores untracked files stashed with -u" {
    echo new > "$WS/beta/new.txt"
    run_cmd stash -u -d "$WS"
    assert_status 0
    [ ! -e "$WS/beta/new.txt" ]
    run_cmd stash --pop -d "$WS"
    assert_status 0
    assert_contains "Popped stash@{0}"
    [ -f "$WS/beta/new.txt" ]
    [ "$(stash_count beta)" = 0 ]
}

@test "stash --list: lists the stashes of the repositories that have some and changes nothing" {
    make_stash alpha
    make_stash alpha
    local before
    before=$(g alpha stash list)
    run_cmd stash --list -d "$WS"
    assert_status 0
    assert_contains "Action: list"
    assert_contains "Total: 2 stashes in 1 repository"
    assert_contains "alpha (2)"
    assert_contains "  - stash@{0} ("
    assert_contains "  - stash@{1} ("
    assert_contains "WIP on main: "
    refute_contains "beta"
    refute_contains "Summary"
    [ "$(g alpha stash list)" = "$before" ]
    [ -z "$(g alpha status --porcelain)" ]
}

@test "stash --list: no stashes anywhere prints No stashes" {
    run_cmd stash --list -d "$WS"
    assert_status 0
    assert_contains "No stashes"
}

@test "stash: --pop --clear is a usage error" {
    make_stash alpha
    run_cmd stash --pop --clear -d "$WS"
    assert_status 2
    assert_contains "options --clear, --pop and --list cannot be combined"
    [ "$(stash_count alpha)" = 1 ]
}

@test "stash: --list -n is a usage error" {
    run_cmd stash --list -n -d "$WS"
    assert_status 2
    assert_contains "option '-n/--dry-run' cannot be used with --list"
}

@test "stash: --pop -u is a usage error" {
    make_stash alpha
    run_cmd stash --pop -u -d "$WS"
    assert_status 2
    assert_contains "option '-u/--include-untracked' cannot be used with --clear, --pop or --list"
    [ "$(stash_count alpha)" = 1 ]
}

@test "stash: --list -y is a usage error" {
    make_stash alpha
    run_cmd stash --list -y -d "$WS"
    assert_status 2
    assert_contains "option '-y/--yes' can only be used with --clear"
    [ "$(stash_count alpha)" = 1 ]
}

@test "stash -m: stashes only the named repositories" {
    change_tracked alpha
    change_tracked beta
    run_cmd stash -d "$WS" -m alpha
    assert_status 0
    assert_contains "Repositories: alpha"
    assert_contains "Working directory alpha"
    refute_contains "Working directory beta"
    [ -z "$(g alpha status --porcelain)" ]
    [ -n "$(g beta status --porcelain)" ]
}
