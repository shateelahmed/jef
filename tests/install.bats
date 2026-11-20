#!/usr/bin/env bats
# install.sh / uninstall.sh run against a throwaway HOME and a fixture clone;
# the real ~/.jef and shell rc files are never touched. Only the basename of
# SHELL matters, so the shells need not exist.

load test_helper

setup() {
    T="$BATS_TEST_TMPDIR"
    export HOME="$T/home"
    CLONE="$T/clone"
    mkdir -p "$HOME" "$CLONE"
    export TERM=dumb
    export SHELL=/bin/zsh
    unset TARGET_DIR SKIP_DIRS DEFAULT_BRANCH

    # A fixture clone: runtime files plus dev-only files that must not be installed.
    cp -R "$JEF_REPO_ROOT/commands" "$JEF_REPO_ROOT/lib" "$CLONE/"
    cp "$JEF_REPO_ROOT/install.sh" "$JEF_REPO_ROOT/uninstall.sh" "$CLONE/"
    mkdir -p "$CLONE/openspec" "$CLONE/tests" "$CLONE/.claude" "$CLONE/.agents" "$CLONE/scripts"
    echo x > "$CLONE/README.md"
    echo x > "$CLONE/.env.example"
    echo x > "$CLONE/openspec/config.yaml"

    PATH_LINE="export PATH=\"\$PATH:$HOME/.jef/commands\""
}

# install [shell]: run install.sh from the clone root with SHELL set.
do_install() {
    if [ -n "$1" ]; then export SHELL="$1"; fi
    cd "$CLONE"
    run "$JEF_BASH" ./install.sh
}

do_uninstall() {
    cd "$CLONE"
    run "$JEF_BASH" ./uninstall.sh "$@" < /dev/null
}

# rc file install.sh should pick for bash on this OS.
bash_rc() {
    case "$OSTYPE" in
    darwin*) echo "$HOME/.bash_profile" ;;
    *) echo "$HOME/.bashrc" ;;
    esac
}

# count_path_lines <file>
count_path_lines() { grep -cF "$HOME/.jef/commands" "$1"; }

@test "install: copies only commands, lib and .env" {
    echo 'SKIP_DIRS="a"' > "$CLONE/.env"
    do_install /bin/zsh
    assert_status 0
    [ -d "$HOME/.jef/commands" ]
    [ -d "$HOME/.jef/lib" ]
    [ -f "$HOME/.jef/.env" ]
    local entry
    for entry in "$HOME/.jef"/* "$HOME/.jef"/.[!.]*; do
        case "$(basename "$entry")" in
        commands | lib | .env) ;;
        *) echo "unexpected: $entry"; return 1 ;;
        esac
    done
    [ ! -e "$HOME/.jef/openspec" ]
    [ ! -e "$HOME/.jef/README.md" ]
    [ ! -e "$HOME/.jef/install.sh" ]
}

@test "install: works without a .env in the clone" {
    do_install /bin/zsh
    assert_status 0
    [ ! -e "$HOME/.jef/.env" ]
}

@test "install: commands are extension-less and executable" {
    do_install /bin/zsh
    assert_status 0
    local f
    for f in jef jef-checkout jef-delete jef-fetch jef-find jef-merge jef-pull jef-push jef-which; do
        [ -x "$HOME/.jef/commands/$f" ] || { echo "not executable: $f"; return 1; }
        [ ! -e "$HOME/.jef/commands/$f.sh" ] || { echo "still has .sh: $f"; return 1; }
    done
}

@test "install: installed jef dispatcher runs" {
    do_install /bin/zsh
    assert_status 0
    PATH="$HOME/.jef/commands:$PATH" run jef help
    assert_status 0
    assert_contains "checkout"
}

@test "install: zsh writes ~/.zshrc" {
    do_install /bin/zsh
    assert_status 0
    grep -qxF "$PATH_LINE" "$HOME/.zshrc"
}

@test "install: bash writes the OS-appropriate rc file" {
    do_install /bin/bash
    assert_status 0
    grep -qxF "$PATH_LINE" "$(bash_rc)"
    [ ! -e "$HOME/.zshrc" ]
}

@test "install: PATH line is added once across re-installs" {
    do_install /bin/zsh
    assert_status 0
    do_install /bin/zsh
    assert_status 0
    assert_contains "already in PATH"
    [ "$(count_path_lines "$HOME/.zshrc")" -eq 1 ]
}

@test "install: unrecognised shell writes nothing and prints the PATH line" {
    do_install /usr/bin/fish
    assert_status 0
    assert_contains "$PATH_LINE"
    [ -d "$HOME/.jef/commands" ]
    [ ! -e "$HOME/.zshrc" ]
    [ ! -e "$HOME/.bashrc" ]
    [ ! -e "$HOME/.bash_profile" ]
    [ ! -e "$HOME/.fishrc" ]
}

@test "install: keeps the installed .env when the clone has none" {
    do_install /bin/zsh
    echo 'SKIP_DIRS="mine"' > "$HOME/.jef/.env"
    do_install /bin/zsh
    assert_status 0
    assert_contains "Kept your existing configuration"
    [ "$(cat "$HOME/.jef/.env")" = 'SKIP_DIRS="mine"' ]
}

@test "install: clone .env wins and the old one is backed up" {
    do_install /bin/zsh
    echo 'SKIP_DIRS="old"' > "$HOME/.jef/.env"
    echo 'SKIP_DIRS="new"' > "$CLONE/.env"
    do_install /bin/zsh
    assert_status 0
    assert_contains "$HOME/.jef.env.bak"
    [ "$(cat "$HOME/.jef/.env")" = 'SKIP_DIRS="new"' ]
    [ "$(cat "$HOME/.jef.env.bak")" = 'SKIP_DIRS="old"' ]
}

@test "install: identical .env needs no backup" {
    echo 'SKIP_DIRS="same"' > "$CLONE/.env"
    do_install /bin/zsh
    do_install /bin/zsh
    assert_status 0
    [ ! -e "$HOME/.jef.env.bak" ]
}

@test "install: legacy scrippy notice is shown and ~/.scrippy untouched" {
    mkdir -p "$HOME/.scrippy"
    do_install /bin/zsh
    assert_status 0
    assert_contains "legacy scrippy"
    [ -d "$HOME/.scrippy" ]
}

@test "install: no notice without a legacy install" {
    do_install /bin/zsh
    refute_contains "scrippy"
}

@test "install: refuses to run on Windows with exit 1" {
    cd "$CLONE"
    # OSTYPE is a bash variable, so override it inside the shell that sources the script.
    run "$JEF_BASH" -c 'OSTYPE=msys; . ./install.sh'
    assert_status 1
    assert_contains "Windows is not supported yet"
    [ ! -e "$HOME/.jef" ]
}

@test "uninstall: --yes removes ~/.jef and only the jef PATH line" {
    printf 'alias a=b\nexport PATH="$PATH:/other/bin"\n' > "$HOME/.zshrc"
    do_install /bin/zsh
    cp "$HOME/.zshrc" "$T/zshrc.installed"
    do_uninstall --yes
    assert_status 0
    [ ! -e "$HOME/.jef" ]
    [ "$(count_path_lines "$HOME/.zshrc" || true)" = "0" ]
    grep -qxF 'alias a=b' "$HOME/.zshrc"
    grep -qF '/other/bin' "$HOME/.zshrc"
    cmp -s "$HOME/.zshrc.jef-uninstall.bak" "$T/zshrc.installed"
}

@test "uninstall: lists what will be removed" {
    do_install /bin/zsh
    do_uninstall --yes
    assert_contains "The following will be removed:"
    assert_contains "$HOME/.jef"
    assert_contains ".zshrc"
}

@test "uninstall: without a terminal and without --yes changes nothing" {
    do_install /bin/zsh
    do_uninstall
    assert_status 1
    assert_contains "Re-run with --yes"
    [ -d "$HOME/.jef" ]
    [ "$(count_path_lines "$HOME/.zshrc")" -eq 1 ]
    [ ! -e "$HOME/.zshrc.jef-uninstall.bak" ]
}

@test "uninstall: answering n aborts and changes nothing" {
    do_install /bin/zsh
    cd "$CLONE"
    run_tty n "$JEF_BASH" ./uninstall.sh
    assert_contains "Aborted"
    [ -d "$HOME/.jef" ]
    [ "$(count_path_lines "$HOME/.zshrc")" -eq 1 ]
}

@test "uninstall: answering y removes (fake terminal)" {
    do_install /bin/zsh
    cd "$CLONE"
    run_tty y "$JEF_BASH" ./uninstall.sh
    assert_status 0
    assert_contains "Removed $HOME/.jef"
    [ ! -e "$HOME/.jef" ] || { echo "$output"; return 1; }
}

@test "uninstall: saves .env to ~/.jef.env.bak" {
    echo 'SKIP_DIRS="keepme"' > "$CLONE/.env"
    do_install /bin/zsh
    do_uninstall -y
    assert_status 0
    assert_contains "$HOME/.jef.env.bak"
    [ ! -e "$HOME/.jef" ]
    [ "$(cat "$HOME/.jef.env.bak")" = 'SKIP_DIRS="keepme"' ]
}

@test "uninstall: works for a fish install (no rc line to remove)" {
    do_install /usr/bin/fish
    export SHELL=/usr/bin/fish
    do_uninstall -y
    assert_status 0
    [ ! -e "$HOME/.jef" ]
}

@test "uninstall: nothing installed" {
    do_uninstall --yes
    assert_status 0
    assert_contains "No jef installation found."
}

@test "uninstall: unknown option prints usage and exits 2" {
    do_uninstall --bogus
    assert_status 2
    assert_contains "Usage:"
}

@test "uninstall: leaves legacy scrippy install alone" {
    mkdir -p "$HOME/.scrippy"
    do_install /bin/zsh
    do_uninstall -y
    [ -d "$HOME/.scrippy" ]
}
