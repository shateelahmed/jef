#!/usr/bin/env bats
# Cross-cutting behaviour shared by every command: repo detection, branch names, .env.

load test_helper

setup_file() { build_fixture_template; }

setup() { setup_workspace; }

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
