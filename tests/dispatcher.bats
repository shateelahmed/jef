#!/usr/bin/env bats

load test_helper

setup() { setup_workspace; }

setup() {
    setup_workspace
    setup_dispatcher
}

jef() { run "$JEF_BASH" "$JEF_HOME/commands/jef" "$@"; }

@test "jef which: dispatches to jef-which" {
    jef which -d "$WS"
    assert_status 0
    assert_contains "Current Branch"
    case "$(table_row alpha)" in *main*) ;; *) echo "$output"; return 1 ;; esac
}

@test "jef checkout: passes flags and arguments through" {
    add_local_branch alpha feat
    jef checkout -d "$WS" feat
    assert_status 0
    assert_contains "Working directory alpha"
    [ "$(current_branch alpha)" = feat ]
}

@test "jef <unknown>: reports the unknown command and lists the commands" {
    bats_require_minimum_version 1.5.0
    run -127 "$JEF_BASH" "$JEF_HOME/commands/jef" nonsense
    assert_contains "jef: unknown command 'nonsense'"
    assert_contains "checkout"
}

@test "jef: no command lists the commands and exits 2" {
    jef
    assert_status 2
    assert_contains "Usage: jef <command>"
    assert_contains "checkout"
}

@test "jef help, -h and --help list every command with its description and exit 0" {
    local form f name desc
    for form in help -h --help; do
        jef $form
        assert_status 0
        for f in "$JEF_HOME"/commands/jef-*.sh; do
            name="$(basename "$f" .sh)"
            name="${name#jef-}"
            assert_contains "$name"
            run "$JEF_BASH" "$f" --help
            desc="$(sed -n 3p <<< "$output")"
            jef $form
            assert_contains "$desc"
        done
    done
}

@test "jef help <command>: shows that command's help" {
    jef help delete
    assert_status 0
    assert_contains "Usage: jef delete"
    assert_contains "--delete-remote-branch"
}

@test "jef help <unknown>: exits 127" {
    bats_require_minimum_version 1.5.0
    run -127 "$JEF_BASH" "$JEF_HOME/commands/jef" help nonsense
    assert_contains "jef: unknown command 'nonsense'"
}

