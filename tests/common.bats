#!/usr/bin/env bats

load test_helper

setup() { setup_workspace; }

# Cross-cutting behaviour shared by every command.

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

@test "-d sets the target directory and beats TARGET_DIR" {
    write_env "$T/does-not-exist" "skipme" "main"
    local spec
    for spec in $SPECS; do
        run_spec "$spec" -d "$WS"
        assert_contains "$WS"
        refute_contains "is not a valid directory"
    done
}

@test "--directory is the long form of -d" {
    write_env "$T/does-not-exist" "skipme" "main"
    local spec
    for spec in $SPECS; do
        run_spec "$spec" --directory "$WS"
        assert_contains "$WS"
        refute_contains "is not a valid directory"
    done
}

@test "-d is used even when TARGET_DIR points at another workspace" {
    mkdir "$T/other"
    make_repo otherrepo "$T/other"
    write_env "$T/other" "skipme" "main"
    run_cmd fetch -d "$WS"
    assert_contains "Target directory: $WS"
    assert_contains "Working directory: alpha"
    refute_contains "otherrepo"
}

@test "TARGET_DIR from .env is the fallback when -d is absent" {
    write_env "$WS" "skipme" "main"
    run_cmd fetch
    assert_contains "Target directory: $WS"
    assert_contains "Working directory: alpha"
    run_cmd which
    case "$(table_row alpha)" in *main*) ;; *) echo "$output"; return 1 ;; esac
}

@test "no -d and no TARGET_DIR prints a hint" {
    local spec
    for spec in $SPECS; do
        run_spec "$spec"
        assert_contains "Target directory is not set"
    done
}

@test "a nonexistent target directory is reported" {
    local spec
    for spec in $SPECS; do
        run_spec "$spec" -d "$T/nope"
        assert_contains "$T/nope is not a valid directory"
    done
}

@test "SKIP_DIRS: comma separated, space separated and mixed lists" {
    local list
    for list in "skipme,gamma" "skipme gamma" "skipme, gamma"; do
        write_env "" "$list" "main"
        run_cmd which -d "$WS"
        [ -z "$(table_row skipme)" ]
        [ -z "$(table_row gamma)" ]
        [ -n "$(table_row alpha)" ]
    done
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

@test "non-repo directories and plain files are ignored by every command" {
    local spec
    for spec in $SPECS; do
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
    for spec in fetch: find:feat pull:main push:main merge:main,main delete:nope; do
        : > "$JEF_SPY_LOG"
        run_spec "$spec" -c -d "$WS"
        assert_contains "Cleared proxy"
        [ -s "$JEF_SPY_LOG" ]
        refute grep -q "proxy.invalid" "$JEF_SPY_LOG"

        : > "$JEF_SPY_LOG"
        run_spec "$spec" -d "$WS"
        refute_contains "Cleared proxy"
        [ -s "$JEF_SPY_LOG" ]
        grep -q "HTTPS_PROXY=http://proxy.invalid:3128" "$JEF_SPY_LOG"
    done
}

@test "proxy: --clear-proxy is the long form of -c" {
    local spec
    for spec in find:feat pull:main push:main merge:main,main delete:nope; do
        run_spec "$spec" --clear-proxy -d "$WS"
        assert_contains "Cleared proxy"
    done
}

@test "paths with spaces: target directory containing a space" {
    local spaced="$T/my work space"
    mkdir "$spaced"
    make_repo repo-in-spaced-dir "$spaced"
    run_cmd which -d "$spaced"
    assert_status 0
    assert_contains "repo-in-spaced-dir"
    run_cmd fetch -d "$spaced"
    assert_status 0
    assert_contains "Working directory: repo-in-spaced-dir"
}

@test "paths with spaces: repo directory name containing a space" {
    make_repo "repo one"
    run_cmd which -d "$WS"
    assert_contains "repo one"
    run_cmd fetch -d "$WS"
    assert_contains "Working directory: repo one"
    add_local_branch "repo one" feat
    run_cmd checkout -d "$WS" feat
    assert_contains "Working directory repo one"
    [ "$(current_branch "repo one")" = feat ]
}

@test "worktrees: a linked worktree (.git is a file) is treated as a repo" {
    g alpha worktree add -q "$WS/wt" -b wtbranch
    [ -f "$WS/wt/.git" ]
    run_cmd which -d "$WS"
    case "$(table_row wt)" in *wtbranch*) ;; *) echo "$output"; return 1 ;; esac
    run_cmd fetch -d "$WS"
    assert_contains "Working directory: wt"
}

@test "submodules: a submodule checkout (.git is a file) is treated as a repo" {
    local super="$T/super"
    mkdir "$super"
    git init -q "$super"
    git -C "$super" commit -q --allow-empty -m init
    git -C "$super" submodule add -q "$ORIGINS/alpha.git" sub
    [ -f "$super/sub/.git" ]
    run_cmd which -d "$super"
    case "$(table_row sub)" in *main*) ;; *) echo "$output"; return 1 ;; esac
}

@test "exit code: a usage error exits with 2" {
    local cmd
    for cmd in checkout delete find merge pull push; do
        run_cmd "$cmd" -d "$WS"
        [ "$status" -eq 2 ] || { echo "$cmd exited $status on a usage error"; return 1; }
    done
}

@test "exit code: unset or invalid target directory exits with 1" {
    local spec
    for spec in $SPECS; do
        run_spec "$spec"
        [ "$status" -eq 1 ] || { echo "$spec exited $status with no target directory"; return 1; }
        run_spec "$spec" -d "$T/nope"
        [ "$status" -eq 1 ] || { echo "$spec exited $status on a bad directory"; return 1; }
    done
}

@test "exit code: an unknown option exits with 2" {
    local spec
    for spec in $SPECS; do
        run_spec "$spec" -d "$WS" -z
        [ "$status" -eq 2 ] || { echo "$spec exited $status on an unknown option"; return 1; }
    done
}

@test "branch names starting with a dash are rejected with exit 2" {
    local cmd
    for cmd in checkout delete find pull push; do
        run_cmd "$cmd" -d "$WS" -- -x
        [ "$status" -eq 2 ] || { echo "$cmd exited $status"; return 1; }
        assert_contains "'-x' is not a valid branch name"
    done
    run_cmd merge -d "$WS" -- main -x
    [ "$status" -eq 2 ]
}

@test "local branch check is exact, not a suffix pattern" {
    add_local_branch alpha feature/x
    run_cmd checkout -d "$WS" x
    refute_contains "Working directory alpha"
    run_cmd find -d "$WS" x
    case "$(table_row alpha)" in *✘*) ;; *) echo "$output"; return 1 ;; esac
}

@test ".env: an unquoted value with spaces is data, not shell code" {
    printf 'SKIP_DIRS=skipme, gamma\n' > "$JEF_HOME/.env"
    run_cmd which -d "$WS"
    assert_status 0
    [ -z "$(table_row skipme)" ]
    [ -z "$(table_row gamma)" ]
    [ -n "$(table_row alpha)" ]
    refute_contains "command not found"
}

@test ".env: quotes, whitespace, comments and CRLF are handled" {
    printf '# comment\n\n  SKIP_DIRS = "skipme, gamma"  \r\n' > "$JEF_HOME/.env"
    run_cmd which -d "$WS"
    [ -z "$(table_row skipme)" ]
    [ -z "$(table_row gamma)" ]
    printf "SKIP_DIRS='skipme beta'\n" > "$JEF_HOME/.env"
    run_cmd which -d "$WS"
    [ -z "$(table_row skipme)" ]
    [ -z "$(table_row beta)" ]
    [ -n "$(table_row alpha)" ]
}

@test ".env: TARGET_DIR with a space works, and .env overrides the environment" {
    local spaced="$T/my work space"
    mkdir "$spaced"
    make_repo spaced-repo "$spaced"
    printf 'TARGET_DIR=%s\n' "$spaced" > "$JEF_HOME/.env"
    run_cmd which
    assert_contains "spaced-repo"
    printf 'SKIP_DIRS=skipme\n' > "$JEF_HOME/.env"
    SKIP_DIRS=alpha run_cmd which -d "$WS"
    [ -n "$(table_row alpha)" ]
    [ -z "$(table_row skipme)" ]
}

@test ".env: shell syntax and invalid keys are never executed" {
    {
        echo "touch \"$T/pwned-1\""
        echo "X=\$(touch \"$T/pwned-2\")"
        echo "BAD-KEY=1"
        echo "1BAD=1"
        echo "export Y=1"
        echo "SKIP_DIRS=skipme"
    } > "$JEF_HOME/.env"
    run_cmd which -d "$WS"
    assert_status 0
    [ ! -e "$T/pwned-1" ]
    [ ! -e "$T/pwned-2" ]
    [ -z "$(table_row skipme)" ]
}
