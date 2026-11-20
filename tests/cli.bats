#!/usr/bin/env bats

load test_helper

setup_file() { build_fixture_template; }

setup() { setup_workspace; }

COMMANDS="checkout delete fetch find merge pull push which"

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
    for cmd in fetch find merge pull push delete; do
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
