#!/usr/bin/env bats

load test_helper

setup_file() { build_fixture_template; }

setup() { setup_workspace; }

COMMANDS="checkout delete fetch find merge merged migrate pull push rebase status which"

@test "--help: every command prints usage and exits 0, even with no target directory" {
    local cmd
    for cmd in $COMMANDS; do
        run_cmd "$cmd" --help
        [ "$status" -eq 0 ] || { echo "$cmd --help exited $status"; return 1; }
        assert_contains "Usage: jef $cmd"
        assert_contains "-d, --directory DIR"
        assert_contains "-h, --help"
        refute_contains "Target directory:"
    done
}

@test "-h is the short form of --help" {
    run_cmd push -h
    assert_status 0
    assert_contains "Usage: jef push [options] <branch>"
}

@test "--help lists the proxy flag only for commands that accept it" {
    local cmd
    for cmd in fetch find merge merged pull push delete rebase; do
        run_cmd "$cmd" --help
        assert_contains "--clear-proxy"
    done
    for cmd in checkout which; do
        run_cmd "$cmd" --help
        refute_contains "--clear-proxy"
    done
}

@test "delete --help documents -r" {
    run_cmd delete --help
    assert_contains "-r, --delete-remote-branch"
}

@test "unknown option: usage on stderr and exit 2 for every command" {
    local cmd
    for cmd in $COMMANDS; do
        run_cmd "$cmd" -d "$WS" -z
        [ "$status" -eq 2 ] || { echo "$cmd exited $status"; return 1; }
        assert_contains "unknown option '-z'"
        assert_contains "Usage: jef $cmd"
    done
}

@test "unknown long option is reported by name" {
    run_cmd find --bogus -d "$WS" feat
    assert_status 2
    assert_contains "unknown option '--bogus'"
    assert_contains "Usage: jef find"
}

@test "option the command does not support is unknown (checkout -c, which --clear-proxy)" {
    run_cmd checkout -c -d "$WS" feat
    assert_status 2
    assert_contains "unknown option '-c'"
    run_cmd which --clear-proxy -d "$WS"
    assert_status 2
    assert_contains "unknown option '--clear-proxy'"
}

@test "-d without a value prints usage and exits 2" {
    run_cmd which -d
    assert_status 2
    assert_contains "requires an argument"
    assert_contains "Usage: jef which"
}

@test "argument-count messages keep their wording" {
    run_cmd merge -d "$WS" onlyone
    assert_status 2
    assert_contains "2 arguments required. 1 provided"
    run_cmd push -d "$WS"
    assert_contains "1 argument required. 0 provided"
}

# value flags of type "list" (merged -m): repeated flags accumulate, space-joined

@test "list flag: repeated -m, --repo and --repo= all accumulate" {
    add_local_branch alpha feat
    add_local_branch beta feat
    add_local_branch gamma feat
    run_cmd merged -d "$WS" -m alpha --repo beta
    assert_contains "Repositories: alpha beta"
    run_cmd merged -d "$WS" --repo=beta -m gamma
    assert_contains "Repositories: beta gamma"
    refute_contains "Working directory alpha"
}

@test "list flag: a single occurrence and an empty one" {
    run_cmd merged -d "$WS" -m alpha -m ""
    assert_contains "Repositories: alpha"
    run_cmd merged -d "$WS"
    assert_contains "Repositories: all"
}

@test "list flag: missing value is a usage error" {
    run_cmd merged -d "$WS" -m
    assert_status 2
    assert_contains "requires an argument"
}

# long-only boolean flags (empty short letter): merged --include-empty

@test "long-only flag: is accepted, listed in --help without a short letter, and has no short form" {
    run_cmd merged --include-empty -d "$WS"
    assert_status 0
    run_cmd merged --help
    assert_contains "    --include-empty"
    refute_contains "-i, --include-empty"
    run_cmd merged -i -d "$WS"
    assert_status 2
    assert_contains "unknown option '-i'"
}

@test "long-only flag: sets its variable and combines with other flags" {
    g alpha branch empty
    run_cmd merged -D -n -d "$WS"
    assert_contains "empty (no commits, kept)"
    run_cmd merged -D -n --include-empty -y -d "$WS"
    assert_status 0
    refute_contains "no commits"
}

@test "long-only flag: works as the only argument (stash --clear)" {
    write_env "$WS" "skipme" "main" # no -d: --clear must be the only argument
    run_cmd stash --clear
    assert_status 0
    refute_contains "unknown option"
    assert_contains "No stashes to clear"
}

# -m/--repo (lib/repos.sh): every repository command accepts it

REPO_COMMANDS="checkout delete fetch find merge merged migrate pull push rebase stash status sync which"

# repo_positionals <command>: the positional arguments a command needs, so that only -m is checked.
repo_positionals() {
    case "$1" in
    checkout | delete | find | pull | push) echo feat ;;
    merge | rebase) echo "feat main" ;;
    *) ;;
    esac
}

@test "-m/--repo: every repository command lists it in --help" {
    local cmd
    for cmd in $REPO_COMMANDS; do
        run_cmd "$cmd" --help
        [ "$status" -eq 0 ] || { echo "$cmd --help exited $status"; return 1; }
        assert_contains "-m, --repo REPOS"
    done
}

@test "-m/--repo: an unknown name exits 2 before anything runs, for every repository command" {
    local cmd
    for cmd in $REPO_COMMANDS; do
        # shellcheck disable=SC2046 # word splitting of the positionals is intended
        run_cmd "$cmd" -d "$WS" -m nosuch $(repo_positionals "$cmd")
        [ "$status" -eq 2 ] || { echo "$cmd exited $status"; echo "$output"; return 1; }
        assert_contains "unknown repository 'nosuch' (not a git repository in the target directory, or listed in SKIP_DIRS)"
        assert_contains "Usage: jef $cmd"
        refute_contains "Target directory:"
    done
}

@test "-m/--repo: a SKIP_DIRS name and a plain directory are unknown names for every repository command" {
    local cmd
    for cmd in $REPO_COMMANDS; do
        # shellcheck disable=SC2046
        run_cmd "$cmd" -d "$WS" -m skipme $(repo_positionals "$cmd")
        [ "$status" -eq 2 ] || { echo "$cmd skipme exited $status"; return 1; }
        assert_contains "unknown repository 'skipme'"
        # shellcheck disable=SC2046
        run_cmd "$cmd" -d "$WS" --repo plain $(repo_positionals "$cmd")
        [ "$status" -eq 2 ] || { echo "$cmd plain exited $status"; return 1; }
        assert_contains "unknown repository 'plain'"
    done
}

@test "-m/--repo: a name that is only a prefix or a comma-joined pair is unknown" {
    run_cmd fetch -d "$WS" -m alp
    assert_status 2
    assert_contains "unknown repository 'alp'"
    run_cmd fetch -d "$WS" -m "alpha,nosuch"
    assert_status 2
    assert_contains "unknown repository 'nosuch'"
}
