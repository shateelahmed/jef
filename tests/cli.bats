#!/usr/bin/env bats

load test_helper

setup_file() { build_fixture_template; }

setup() { setup_workspace; }

COMMANDS="checkout delete exec fetch find merge merged migrate pull push rebase status which"

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
    for cmd in fetch find merge merged pull push delete rebase; do
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

# value flags of type "list" (merged -m): repeated flags accumulate, space-joined

@test "list flag: repeated -m, --repo and --repo= all accumulate" {
    add_local_branch alpha feat
    add_local_branch beta feat
    add_local_branch gamma feat
    run_cmd merged -d "$WS" -m alpha --repo beta
    assert_contains "Repositories: alpha beta"
    run_cmd merged -d "$WS" --repo=beta -m gamma
    assert_contains "Repositories: beta gamma"
    refute_contains "Working directory alpha"
}

@test "list flag: a single occurrence and an empty one" {
    run_cmd merged -d "$WS" -m alpha -m ""
    assert_contains "Repositories: alpha"
    run_cmd merged -d "$WS"
    assert_contains "Repositories: all"
}

@test "list flag: missing value is a usage error" {
    run_cmd merged -d "$WS" -m
    assert_status 2
    assert_contains "requires an argument"
}

# long-only boolean flags (empty short letter): merged --include-empty

@test "long-only flag: is accepted, listed in --help without a short letter, and has no short form" {
    run_cmd merged --include-empty -d "$WS"
    assert_status 0
    run_cmd merged --help
    assert_contains "    --include-empty"
    refute_contains "-i, --include-empty"
    run_cmd merged -i -d "$WS"
    assert_status 2
    assert_contains "unknown option '-i'"
}

@test "long-only flag: sets its variable and combines with other flags" {
    g alpha branch empty
    run_cmd merged -D -n -d "$WS"
    assert_contains "empty (no commits, kept)"
    run_cmd merged -D -n --include-empty -y -d "$WS"
    assert_status 0
    refute_contains "no commits"
}

@test "long-only flag: works as the only argument (stash --clear)" {
    write_env "$WS" "skipme" "main" # no -d: --clear must be the only argument
    run_cmd stash --clear
    assert_status 0
    refute_contains "unknown option"
    assert_contains "No stashes to clear"
}

# -m/--repo (lib/repos.sh): every repository command accepts it

REPO_COMMANDS="checkout delete exec fetch find merge merged migrate pull push rebase stash status sync which"

# repo_positionals <command>: the positional arguments a command needs, so that only -m is checked.
repo_positionals() {
    case "$1" in
    checkout | delete | find | pull | push) echo feat ;;
    merge | rebase) echo "feat main" ;;
    exec) echo true ;;
    *) ;;
    esac
}

@test "-m/--repo: every repository command lists it in --help" {
    local cmd
    for cmd in $REPO_COMMANDS; do
        run_cmd "$cmd" --help
        [ "$status" -eq 0 ] || { echo "$cmd --help exited $status"; return 1; }
        assert_contains "-m, --repo REPOS"
    done
}

@test "-m/--repo: an unknown name exits 2 before anything runs, for every repository command" {
    local cmd
    for cmd in $REPO_COMMANDS; do
        # shellcheck disable=SC2046 # word splitting of the positionals is intended
        run_cmd "$cmd" -d "$WS" -m nosuch $(repo_positionals "$cmd")
        [ "$status" -eq 2 ] || { echo "$cmd exited $status"; echo "$output"; return 1; }
        assert_contains "unknown repository 'nosuch' (not a git repository in the target directory, or listed in SKIP_DIRS)"
        assert_contains "Usage: jef $cmd"
        refute_contains "Target directory:"
    done
}

@test "-m/--repo: a SKIP_DIRS name and a plain directory are unknown names for every repository command" {
    local cmd
    for cmd in $REPO_COMMANDS; do
        # shellcheck disable=SC2046
        run_cmd "$cmd" -d "$WS" -m skipme $(repo_positionals "$cmd")
        [ "$status" -eq 2 ] || { echo "$cmd skipme exited $status"; return 1; }
        assert_contains "unknown repository 'skipme'"
        # shellcheck disable=SC2046
        run_cmd "$cmd" -d "$WS" --repo plain $(repo_positionals "$cmd")
        [ "$status" -eq 2 ] || { echo "$cmd plain exited $status"; return 1; }
        assert_contains "unknown repository 'plain'"
    done
}

@test "-m/--repo: a name that is only a prefix or a comma-joined pair is unknown" {
    run_cmd fetch -d "$WS" -m alp
    assert_status 2
    assert_contains "unknown repository 'alp'"
    run_cmd fetch -d "$WS" -m "alpha,nosuch"
    assert_status 2
    assert_contains "unknown repository 'nosuch'"
}

# cli_pass_through (lib/cli.sh): parse_options on its own, with a few value and boolean flags.

pass_through_parse() {
    "$JEF_BASH" -c '
        source "$1"; shift
        cli_name=test
        cli_pass_through=true
        cli_extra_flags=("n|dry-run|dry_run|Dry")
        cli_value_flags=("j|jobs|parallel_jobs|N|1|posint|Jobs" "b|branch|branch_filter|BRANCH||string|Branch")
        parse_options "$@"
        echo "pos=$(printf "%s;" "${cli_positional[@]}") dry=$dry_run jobs=$parallel_jobs branch=$branch_filter"
    ' _ "$JEF_HOME/lib/cli.sh" "$@"
}

@test "cli_pass_through: jef words before the command are parsed, the command is kept whole" {
    run pass_through_parse -n -j 4 git log -1 -n
    assert_status 0
    assert_contains "pos=git;log;-1;-n; dry=true jobs=4 branch="
}

@test "cli_pass_through: -- is dropped and ends jef's options" {
    run pass_through_parse -b dev -- -n x
    assert_status 0
    assert_contains "pos=-n;x; dry=false jobs=1 branch=dev"
}

@test "cli_pass_through: attached values, clusters and --long=value" {
    run pass_through_parse -j2 echo -j
    assert_status 0
    assert_contains "pos=echo;-j; dry=false jobs=2"
    run pass_through_parse -nj3 ls
    assert_contains "pos=ls; dry=true jobs=3"
    run pass_through_parse --jobs=5 --branch=main ls -b
    assert_contains "pos=ls;-b; dry=false jobs=5 branch=main"
}

@test "cli_pass_through: a value flag takes the next word even when it looks like an option" {
    run pass_through_parse -b -n ls
    assert_status 0
    assert_contains "pos=ls; dry=false jobs=1 branch=-n"
}

@test "cli_pass_through: -h before the command is help, after it is the command's" {
    run pass_through_parse -h git
    assert_status 0
    assert_contains "Usage: jef test"
    run pass_through_parse git -h
    assert_status 0
    assert_contains "pos=git;-h;"
    refute_contains "Usage: jef test"
}

@test "cli_pass_through: an unknown option before the command is still unknown (exit 2)" {
    run pass_through_parse -z git
    assert_status 2
    assert_contains "unknown option '-z'"
}

@test "cli_pass_through: no words at all gives no positionals" {
    run pass_through_parse
    assert_status 0
    assert_contains "pos=; dry=false jobs=1 branch="
}

@test "without cli_pass_through, -h and -- are still parsed for every other command" {
    run_cmd push feat -h
    assert_status 0
    assert_contains "Usage: jef push [options] <branch>"
    run_cmd merge -d "$WS" -- onlyone
    assert_status 2
    assert_contains "2 arguments required. 1 provided"
}
