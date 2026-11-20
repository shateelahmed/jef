#!/usr/bin/env bats

load test_helper

setup() { setup_workspace; }

@test "no command or library uses realpath" {
    run grep -rn "realpath" "$JEF_REPO_ROOT/commands" "$JEF_REPO_ROOT/lib"
    [ "$status" -eq 1 ]
}

@test "a command symlinked with an absolute path finds lib and .env" {
    mkdir "$T/bin"
    ln -s "$JEF_HOME/commands/jef-which.sh" "$T/bin/jwhich"
    printf 'TARGET_DIR=%s\n' "$WS" > "$JEF_HOME/.env"
    run "$JEF_BASH" "$T/bin/jwhich"
    assert_status 0
    [ -n "$(table_row alpha)" ]
}

@test "a command symlinked with a relative path and a symlink chain works" {
    mkdir "$T/bin"
    ln -s ../jef/commands/jef-which.sh "$T/bin/first"
    ln -s first "$T/bin/second"
    printf 'TARGET_DIR=%s\n' "$WS" > "$JEF_HOME/.env"
    run "$JEF_BASH" "$T/bin/second"
    assert_status 0
    [ -n "$(table_row beta)" ]
}

@test "piped jef which output has no escape codes, even with a colour-capable TERM" {
    TERM=xterm-256color run_cmd which -d "$WS"
    assert_status 0
    refute_contains $'\033'
    refute_contains $'\r'
}

@test "piped jef find output has no escape codes, even with a colour-capable TERM" {
    TERM=xterm-256color run_cmd find -d "$WS" main
    assert_status 0
    refute_contains $'\033'
    refute_contains $'\r'
    refute_contains "Directory ... "
}

@test "NO_COLOR yields empty colour variables" {
    run env NO_COLOR=1 TERM=xterm-256color "$JEF_BASH" -c 'source "$1"; echo "[$green$yellow$red$reset]"' _ "$JEF_HOME/lib/terminal-color-codes.sh"
    assert_status 0
    [ "$output" = "[]" ]
    TERM=xterm-256color run_cmd which -d "$WS"
    refute_contains $'\033'
}

@test "colour variables are empty when stdout is not a terminal or tput is missing" {
    run env -u NO_COLOR TERM=xterm-256color "$JEF_BASH" -c 'source "$1"; echo "[$green$reset]"' _ "$JEF_HOME/lib/terminal-color-codes.sh"
    [ "$output" = "[]" ]
    local bash_path
    bash_path="$(command -v "$JEF_BASH")"
    run env -u NO_COLOR PATH="/nonexistent" "$bash_path" -c 'source "$1"; echo "[$green$reset]"' _ "$JEF_HOME/lib/terminal-color-codes.sh"
    assert_status 0
    [ "$output" = "[]" ]
}

@test ".env: tilde and HOME references expand at the start of a value" {
    mkdir "$HOME/code"
    make_repo homerepo "$HOME/code"
    local v
    for v in '~/code' '$HOME/code' '${HOME}/code' '"$HOME/code"'; do
        printf 'TARGET_DIR=%s\n' "$v" > "$JEF_HOME/.env"
        run_cmd which
        assert_status 0
        assert_contains "homerepo"
        assert_contains "$HOME/code"
    done
}

@test ".env: ~ alone expands to HOME" {
    make_repo homerepo2 "$HOME"
    printf 'TARGET_DIR=~\n' > "$JEF_HOME/.env"
    run_cmd which
    assert_contains "homerepo2"
}

@test ".env: nothing but a leading home reference is expanded" {
    local v
    for v in '~root/code' '$HOMEDIR/code' '/x/$HOME' '/x/~' '$OTHER/code'; do
        printf 'TARGET_DIR=%s\n' "$v" > "$JEF_HOME/.env"
        run_cmd which
        assert_status 1
        assert_contains "$v is not a valid directory"
    done
}
