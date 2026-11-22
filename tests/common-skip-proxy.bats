#!/usr/bin/env bats
# Cross-cutting behaviour shared by every command: SKIP_DIRS, non-repos, proxy.

load test_helper

setup_file() { build_fixture_template; }

setup() { setup_workspace; }

# "<command>:<arguments>" specs that are valid and safe to run on the workspace.
SPECS="checkout:feat delete:feat fetch: find:feat merge:main,main pull:main push:main which:"

# run_spec <spec> [extra options...]: run one spec with the options first.
run_spec() {
    local spec="$1" cmd args
    shift
    cmd="${spec%%:*}"
    args="${spec#*:}"
    # shellcheck disable=SC2086
    run_cmd "$cmd" "$@" ${args//,/ }
}

@test "SKIP_DIRS: comma separated lists, whitespace around entries and empty entries are fine" {
    local list
    for list in "skipme,gamma" "skipme, gamma" " skipme ,,gamma, " $'\tskipme\t,gamma,'; do
        write_env "" "$list" "main"
        run_cmd which -d "$WS"
        [ -z "$(table_row skipme)" ]
        [ -z "$(table_row gamma)" ]
        [ -n "$(table_row alpha)" ]
    done
}

@test "SKIP_DIRS: an entry containing spaces exits 2 before any repository is touched" {
    add_local_branch alpha feat
    add_local_branch skipme feat
    write_env "" "skipme gamma" "main"
    run_cmd delete -d "$WS" feat
    assert_status 2
    assert_contains "Invalid SKIP_DIRS: 'skipme gamma' contains spaces; separate entries with commas"
    g alpha show-ref --quiet --heads feat
    g skipme show-ref --quiet --heads feat
    refute_contains "Working directory"
    local spec
    for spec in $SPECS; do
        run_spec "$spec" -d "$WS"
        assert_status 2
    done
}

@test "SKIP_DIRS: --help still works with an invalid value" {
    write_env "" "skipme gamma" "main"
    run_cmd delete --help
    assert_status 0
    assert_contains "Usage: jef delete"
}

@test "SKIP_DIRS: empty list skips nothing and matches whole names only" {
    write_env "" "" "main"
    run_cmd which -d "$WS"
    [ -n "$(table_row skipme)" ]
    write_env "" "skip" "main"
    run_cmd which -d "$WS"
    [ -n "$(table_row skipme)" ]
}

@test "SKIP_DIRS: every command leaves the skipped repo alone" {
    add_local_branch skipme feat
    local spec
    for spec in $SPECS; do
        run_spec "$spec" -d "$WS"
        refute_contains "Working directory skipme"
        refute_contains "Working directory: skipme"
        [ -z "$(table_row skipme)" ]
    done
    [ "$(current_branch skipme)" = main ]
    g skipme show-ref --quiet --heads feat
}

@test "non-repo directories and plain files are ignored (read-only and mutating command)" {
    local spec
    for spec in which: checkout:feat; do
        run_spec "$spec" -d "$WS"
        refute_contains "plain"
        refute_contains "loose-file"
    done
}

@test "proxy: -c clears proxy variables for git, no -c leaves them" {
    setup_git_spy
    export HTTPS_PROXY=http://proxy.invalid:3128
    export http_proxy=http://proxy.invalid:3128
    local spec
    # Every network command clears the proxy with -c.
    for spec in fetch: find:feat pull:main push:main merge:main,main delete:nope; do
        : > "$JEF_SPY_LOG"
        run_spec "$spec" -c -d "$WS"
        assert_contains "Cleared proxy"
        [ -s "$JEF_SPY_LOG" ]
        refute grep -q "proxy.invalid" "$JEF_SPY_LOG"
    done
    # Without -c the variables pass through (shared code path: one command).
    : > "$JEF_SPY_LOG"
    run_spec fetch: -d "$WS"
    refute_contains "Cleared proxy"
    [ -s "$JEF_SPY_LOG" ]
    grep -q "HTTPS_PROXY=http://proxy.invalid:3128" "$JEF_SPY_LOG"
}

@test "proxy: --clear-proxy is the long form of -c" {
    run_cmd find --clear-proxy -d "$WS" feat
    assert_contains "Cleared proxy"
}
