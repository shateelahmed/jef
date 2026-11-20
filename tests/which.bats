#!/usr/bin/env bats

load test_helper

setup_file() { build_fixture_template; }

setup() { setup_workspace; }

@test "which: lists the current branch of every repo" {
    add_local_branch alpha feat
    g alpha checkout -q feat
    run_cmd which -d "$WS"
    assert_status 0
    assert_contains "| Directory"
    assert_contains "Current Branch"
    case "$(table_row 'Target directory')" in *"$WS"*) ;; *) echo "$output"; return 1 ;; esac
    case "$(table_row alpha)" in *feat*) ;; *) echo "$output"; return 1 ;; esac
    case "$(table_row beta)" in *main*) ;; *) echo "$output"; return 1 ;; esac
    case "$(table_row gamma)" in *main*) ;; *) echo "$output"; return 1 ;; esac
}

@test "which: omits SKIP_DIRS repos, non-repos and plain files" {
    run_cmd which -d "$WS"
    [ -z "$(table_row skipme)" ]
    [ -z "$(table_row plain)" ]
    refute_contains "loose-file"
}
