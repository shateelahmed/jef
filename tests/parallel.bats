#!/usr/bin/env bats

load test_helper

setup() { setup_workspace; }

@test "fetch -j 4: output equals -j 1" {
    remote_commit alpha feat a.txt
    run_cmd fetch -j 4 -d "$WS"
    assert_status 0
    par_output="$output"
    assert_contains "[new branch]"
    g alpha update-ref -d refs/remotes/origin/feat # make the next fetch see the branch as new again
    run_cmd fetch -d "$WS"
    assert_status 0
    seq_output="$output"
    [ "$par_output" = "$seq_output" ] || { echo "--- j1 ---"; echo "$seq_output"; echo "--- j4 ---"; echo "$par_output"; return 1; }
    assert_contains "Summary: 3 done, 0 failed, 0 skipped"
    g alpha show-ref --quiet refs/remotes/origin/feat
}

@test "find -j 4: output equals -j 1" {
    add_remote_branch alpha feat
    add_local_branch beta feat
    remote_only_branch gamma feat
    run_cmd find -d "$WS" feat
    assert_status 0
    seq_output="$output"
    run_cmd find -j 4 -d "$WS" feat
    assert_status 0
    [ "$output" = "$seq_output" ] || { echo "--- j1 ---"; echo "$seq_output"; echo "--- j4 ---"; echo "$output"; return 1; }
    case "$(table_row alpha)" in *✔*✔*) ;; *) echo "$output"; return 1 ;; esac
}

@test "fetch and find: invalid -j values are usage errors" {
    local bad
    for bad in 0 -1 abc 1.5 ""; do
        run_cmd fetch -j "$bad" -d "$WS"
        assert_status 2
        run_cmd find -j "$bad" -d "$WS" feat
        assert_status 2
    done
}

@test "fetch and find: -j without a value is a usage error" {
    run_cmd fetch -d "$WS" -j
    assert_status 2
    assert_contains "requires an argument"
    run_cmd find -d "$WS" feat --jobs
    assert_status 2
}

@test "fetch --jobs and --jobs=N are long forms of -j" {
    run_cmd fetch --jobs 2 -d "$WS"
    assert_status 0
    assert_contains "Summary: 3 done"
    run_cmd fetch --jobs=2 -d "$WS"
    assert_status 0
    run_cmd find --jobs 2 -d "$WS" feat
    assert_status 0
    assert_contains "| Directory"
}

@test "fetch -j: a broken origin is reported in the summary and exits 3" {
    g beta remote set-url origin "$T/does-not-exist.git"
    run_cmd fetch -j 3 -d "$WS"
    assert_status 3
    assert_contains "Summary: 2 done, 1 failed, 0 skipped"
    assert_contains "Working directory: beta"
}

@test "fetch -j: runs concurrent jobs and leaves no temp dir behind" {
    export TMPDIR="$T/tmp"
    mkdir -p "$TMPDIR"
    run_cmd fetch -j 3 -d "$WS"
    assert_status 0
    [ -z "$(ls -A "$TMPDIR")" ]
}

@test "find -j: TERM kills in-flight git children and removes the temp dir" {
    mkdir -p "$T/slow" "$T/tmp"
    cat > "$T/slow/git" <<'EOF'
#!/bin/bash
case "$*" in
*ls-remote*) exec sleep 37 ;;
esac
exec "$JEF_REAL_GIT" "$@"
EOF
    chmod +x "$T/slow/git"
    export JEF_REAL_GIT
    JEF_REAL_GIT="$(command -v git)"
    export PATH="$T/slow:$PATH"
    export TMPDIR="$T/tmp"
    "$JEF_BASH" "$JEF_HOME/commands/jef-find.sh" -j 2 -d "$WS" main > /dev/null 2>&1 3>&- &
    local pid=$!
    sleep 2
    pgrep -f "sleep 37" > /dev/null # the slow lookups are in flight
    kill -TERM "$pid"
    wait "$pid" || true
    local tries=0
    while pgrep -f "sleep 37" > /dev/null && [ "$tries" -lt 50 ]; do
        sleep 0.1
        tries=$((tries + 1))
    done
    ps -o pid,ppid,command -ax | grep "sleep 37" | grep -v grep || true
    refute pgrep -f "sleep 37"
    [ -z "$(ls -A "$TMPDIR")" ]
}

@test "help lists -j/--jobs for fetch and find only" {
    run_cmd fetch --help
    assert_contains "-j, --jobs N"
    run_cmd find --help
    assert_contains "-j, --jobs N"
    run_cmd which --help
    refute_contains "--jobs"
}
