#!/usr/bin/env bats

load test_helper

setup_file() { build_fixture_template; }

setup() { setup_workspace; }

@test "fetch: fetches every repo and prints the header lines" {
    remote_commit alpha feat a.txt
    remote_commit beta feat b.txt
    run_cmd fetch -d "$WS"
    assert_status 0
    assert_contains "Target directory: $WS"
    assert_contains "Clear proxy: false"
    assert_contains "Working directory: alpha"
    assert_contains "Working directory: beta"
    assert_contains "Working directory: gamma"
    refute_contains "Working directory: skipme"
    refute_contains "Working directory: plain"
    g alpha show-ref --quiet refs/remotes/origin/feat
    g beta show-ref --quiet refs/remotes/origin/feat
}

@test "fetch: prunes remote-tracking refs deleted upstream" {
    add_remote_branch alpha feat
    git --git-dir="$ORIGINS/alpha.git" branch -q -D feat
    g alpha show-ref --quiet refs/remotes/origin/feat
    run_cmd fetch -d "$WS"
    refute g alpha show-ref --quiet refs/remotes/origin/feat
}

@test "fetch -c: reports clearing the proxy" {
    export HTTPS_PROXY=http://proxy.invalid:3128
    run_cmd fetch -c -d "$WS"
    assert_contains "Clear proxy: true"
    assert_contains "Cleared proxy"
}

@test "fetch --clear-proxy is the long form of -c" {
    run_cmd fetch --clear-proxy -d "$WS"
    assert_contains "Clear proxy: true"
    assert_contains "Cleared proxy"
}

@test "fetch -m: fetches only the named repositories and counts only them" {
    remote_commit alpha feat a.txt
    remote_commit beta feat b.txt
    remote_commit gamma feat c.txt
    run_cmd fetch -d "$WS" -m alpha,gamma
    assert_status 0
    assert_contains "Repositories: alpha,gamma"
    assert_contains "Working directory: alpha"
    assert_contains "Working directory: gamma"
    refute_contains "Working directory: beta"
    assert_contains "Summary: 2 done, 0 failed, 0 skipped"
    g alpha show-ref --quiet refs/remotes/origin/feat
    g gamma show-ref --quiet refs/remotes/origin/feat
    refute g beta show-ref --quiet refs/remotes/origin/feat
}
