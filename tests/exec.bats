#!/usr/bin/env bats

load test_helper

setup_file() { build_fixture_template; }

setup() { setup_workspace; }

# The fixture has alpha, beta and gamma (skipme is in SKIP_DIRS, plain is not a repository).

@test "exec: a command runs in every repository, with its header and output" {
    g beta checkout -q -b dev
    run_cmd exec -d "$WS" -m alpha,beta git rev-parse --abbrev-ref HEAD
    assert_status 0
    assert_contains "Working directory alpha"$'\n'"main"
    assert_contains "Working directory beta"$'\n'"dev"
    assert_contains "Summary: 2 done, 0 failed, 0 skipped"
    refute_contains "Working directory gamma"
}

@test "exec: the banner shows the target, repositories, command, branch filter, jobs and dry run" {
    run_cmd exec -d "$WS" -m alpha git log -1
    assert_status 0
    assert_contains "Target directory: $WS"
    assert_contains "Repositories: alpha"
    assert_contains "Command: git log -1"
    assert_contains "Branch filter: any"
    assert_contains "Jobs: 1"
    assert_contains "Dry run: false"
}

@test "exec: a failing command is reported, the others still run, exit 3" {
    run_cmd exec -d "$WS" '[ "$JEF_REPO" != alpha ]'
    assert_status 3
    assert_contains "Working directory alpha"$'\n'"Exited with status 1"
    assert_contains "Working directory beta"
    assert_contains "Working directory gamma"
    assert_contains "Summary: 2 done, 1 failed, 0 skipped"
}

@test "exec: no command is a usage error, exit 2" {
    run_cmd exec -d "$WS"
    assert_status 2
    assert_contains "a command is required"
    assert_contains "Usage: jef exec [options] [--] <command...>"
    run_cmd exec -d "$WS" -m alpha -n
    assert_status 2
}

@test "exec: one argument is a shell string (pipe, quotes)" {
    run_cmd exec -d "$WS" -m alpha 'git log --oneline | wc -l | tr -d " "'
    assert_status 0
    assert_contains "Working directory alpha"$'\n'"1"
}

@test "exec: several arguments are the command as given, the argument is not split" {
    run_cmd exec -d "$WS" -m alpha git log -1 '--format=%h %s'
    assert_status 0
    assert_contains " init"
    refute_contains "fatal"
}

@test "exec: JEF_REPO holds the repository's directory name" {
    run_cmd exec -d "$WS" 'echo "$JEF_REPO"'
    assert_status 0
    assert_contains "Working directory alpha"$'\n'"alpha"
    assert_contains "Working directory beta"$'\n'"beta"
    assert_contains "Working directory gamma"$'\n'"gamma"
}

@test "exec: stdin is /dev/null, so a command never waits for input" {
    run_cmd exec -d "$WS" -m alpha 'read -r line; echo "got:$line"'
    assert_status 0
    assert_contains "Working directory alpha"$'\n'"got:"
}

@test "exec: options after the command belong to the command (-m alpha with --dry-run)" {
    run_cmd exec -d "$WS" -m alpha printf '%s\n' --dry-run -h
    assert_status 0
    refute_contains "Dry run: true"
    refute_contains "Would run"
    assert_contains "Working directory alpha"$'\n'"--dry-run"$'\n'"-h"
    refute_contains "Working directory beta"
}

@test "exec: -h inside the command does not print jef's usage" {
    run_cmd exec -d "$WS" -m alpha grep -h alpha file.txt
    assert_status 0
    assert_contains "Working directory alpha"$'\n'"alpha"
    refute_contains "Usage: jef exec"
}

@test "exec: -- ends jef's options, so a command starting with a dash runs" {
    run_cmd exec -d "$WS" -m alpha -- -weird-command
    assert_status 3
    assert_contains "weird-command: command not found"
    refute_contains "unknown option"
    refute_contains "Usage: jef exec"
}

@test "exec: an unknown jef option before the command is still an error" {
    run_cmd exec -d "$WS" --bogus git status
    assert_status 2
    assert_contains "unknown option '--bogus'"
}

@test "exec -n: prints what would run under each header and runs nothing" {
    run_cmd exec -n -d "$WS" touch x
    assert_status 0
    assert_contains "Dry run: true"
    assert_contains "Working directory alpha"$'\n'"Would run: touch x"
    assert_contains "Working directory gamma"$'\n'"Would run: touch x"
    assert_contains "Summary: 3 done, 0 failed, 0 skipped"
    [ ! -e "$WS/alpha/x" ]
    [ ! -e "$WS/beta/x" ]
    run_cmd exec -d "$WS" -m alpha --dry-run touch y
    assert_status 0
    assert_contains "Would run: touch y"
    [ ! -e "$WS/alpha/y" ]
}

@test "exec -n: several arguments show as the command joined with spaces" {
    run_cmd exec -n -d "$WS" -m alpha git log --oneline -1
    assert_contains "Would run: git log --oneline -1"
}

@test "exec -b: only repositories with that branch checked out run the command" {
    g beta checkout -q -b dev
    run_cmd exec -d "$WS" -b dev 'echo "$JEF_REPO"'
    assert_status 0
    assert_contains "Branch filter: dev"
    assert_contains "Working directory alpha"$'\n'"on main, not dev. skipping..."
    assert_contains "Working directory beta"$'\n'"beta"
    assert_contains "Summary: 1 done, 0 failed, 2 skipped"
    run_cmd exec -d "$WS" --branch=-x 'echo hi'
    assert_status 2
    assert_contains "not a valid branch name"
}

@test "exec -j 4: same ordered output and outcome as -j 1" {
    run_cmd exec -d "$WS" 'sleep 1; echo "$JEF_REPO"; [ "$JEF_REPO" != gamma ]'
    assert_status 3
    seq_output="$output"
    run_cmd exec -j 4 -d "$WS" 'sleep 1; echo "$JEF_REPO"; [ "$JEF_REPO" != gamma ]'
    assert_status 3
    par_output="$output"
    seq_output="${seq_output//Jobs: 1/Jobs: 4}"
    [ "$par_output" = "$seq_output" ] || { echo "--- j1 ---"; echo "$seq_output"; echo "--- j4 ---"; echo "$par_output"; return 1; }
    assert_contains "Jobs: 4"
    assert_contains "Summary: 2 done, 1 failed, 0 skipped"
}

@test "exec -j: a non-positive or non-numeric job count is a usage error" {
    run_cmd exec -j 0 -d "$WS" true
    assert_status 2
    assert_contains "needs a positive integer"
    run_cmd exec -j x -d "$WS" true
    assert_status 2
}

@test "exec: several arguments are shown quoted where needed, so the display can be pasted back" {
    run_cmd exec -d "$WS" -n git log -1 --format='%h %s' "it's" plain
    assert_status 0
    assert_contains "Command: git log -1 '--format=%h %s' 'it'\''s' plain"
    assert_contains "Would run: git log -1 '--format=%h %s' 'it'\''s' plain"
}
