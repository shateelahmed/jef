#!/usr/bin/env bats

load test_helper

setup_file() { build_fixture_template; }

setup() { setup_workspace; }

@test "migrate: runs each repo's command in that repo and skips repos without an entry" {
    write_migrate_cmds "alpha:echo ran > migrated.txt; beta:echo ran > migrated.txt"
    run_cmd migrate -d "$WS"
    assert_status 0
    assert_contains "Target directory: $WS"
    assert_contains "Branch filter: any"
    assert_contains "Jobs: 1"
    assert_contains "Dry run: false"
    assert_contains "Working directory alpha"
    assert_contains "Running: echo ran > migrated.txt"
    refute_contains "Working directory gamma"
    assert_contains "Summary: 2 done, 0 failed, 1 skipped"
    [ "$(cat "$WS/alpha/migrated.txt")" = ran ]
    [ "$(cat "$WS/beta/migrated.txt")" = ran ]
    [ ! -e "$WS/gamma/migrated.txt" ]
}

@test "migrate: trims whitespace and splits the name at the first colon" {
    write_migrate_cmds "  alpha : echo a:b > out.txt ;  ; beta:echo x > out.txt ; "
    run_cmd migrate -d "$WS"
    assert_status 0
    [ "$(cat "$WS/alpha/out.txt")" = "a:b" ]
    assert_contains "Summary: 2 done, 0 failed, 1 skipped"
}

@test "migrate: commands with && and quotes work" {
    write_migrate_cmds "alpha:echo \"hello world\" > a.txt && echo more >> a.txt"
    run_cmd migrate -d "$WS"
    assert_status 0
    [ "$(cat "$WS/alpha/a.txt")" = "$(printf 'hello world\nmore')" ]
}

@test "migrate: an unknown repository name is a warning" {
    write_migrate_cmds "alpha:echo ran > m.txt; nosuch:true; skipme:echo ran > m.txt; plain:true"
    run_cmd migrate -d "$WS"
    assert_status 0
    assert_contains "MIGRATE_CMDS names 'nosuch'"
    assert_contains "MIGRATE_CMDS names 'skipme'"
    assert_contains "MIGRATE_CMDS names 'plain'"
    assert_contains "Summary: 1 done, 0 failed, 2 skipped"
    [ ! -e "$WS/skipme/m.txt" ]
}

@test "migrate: MIGRATE_CMDS unset or empty exits 1 with a hint" {
    run_cmd migrate -d "$WS"
    assert_status 1
    assert_contains "MIGRATE_CMDS is not set"
    write_migrate_cmds ""
    run_cmd migrate -d "$WS"
    assert_status 1
    write_migrate_cmds " ; "
    run_cmd migrate -d "$WS"
    assert_status 1
}

@test "migrate: malformed or duplicate entries exit 2 and run nothing" {
    local value
    for value in "alpha" "alpha:" ":echo hi" "alpha:echo a > m.txt; alpha:echo b > m.txt" "alpha:echo a > m.txt; beta"; do
        write_migrate_cmds "$value"
        run_cmd migrate -d "$WS"
        [ "$status" -eq 2 ] || { echo "'$value' exited $status"; echo "$output"; return 1; }
        assert_contains "Invalid MIGRATE_CMDS entry"
        [ ! -e "$WS/alpha/m.txt" ]
    done
}

@test "migrate: a failing command is reported, later repos still run, exit 3" {
    write_migrate_cmds "alpha:exit 7; beta:echo ran > m.txt; gamma:echo ran > m.txt"
    run_cmd migrate -d "$WS"
    assert_status 3
    assert_contains "Migration failed in alpha (exit 7)"
    assert_contains "Summary: 2 done, 1 failed, 0 skipped"
    [ -e "$WS/beta/m.txt" ]
    [ -e "$WS/gamma/m.txt" ]
}

@test "migrate -n: prints what would run and runs nothing" {
    write_migrate_cmds "alpha:echo ran > m.txt; beta:echo ran > m.txt"
    run_cmd migrate -n -d "$WS"
    assert_status 0
    assert_contains "Dry run: true"
    assert_contains "Would run: echo ran > m.txt"
    refute_contains "Running:"
    assert_contains "Summary: 2 done, 0 failed, 1 skipped"
    [ ! -e "$WS/alpha/m.txt" ]
    run_cmd migrate --dry-run -d "$WS"
    assert_contains "Would run:"
}

@test "migrate -b: only repos on that branch run" {
    write_migrate_cmds "alpha:echo ran > m.txt; beta:echo ran > m.txt"
    g beta checkout -q -b feat
    run_cmd migrate -b main -d "$WS"
    assert_status 0
    assert_contains "Branch filter: main"
    assert_contains "on feat, not main. skipping..."
    assert_contains "Summary: 1 done, 0 failed, 2 skipped"
    [ -e "$WS/alpha/m.txt" ]
    [ ! -e "$WS/beta/m.txt" ]
    run_cmd migrate --branch=feat -d "$WS"
    assert_contains "on main, not feat. skipping..."
    [ -e "$WS/beta/m.txt" ]
}

@test "migrate -b: an invalid branch name exits 2" {
    write_migrate_cmds "alpha:true"
    run_cmd migrate --branch=-x -d "$WS"
    assert_status 2
    assert_contains "not a valid branch name"
}

@test "migrate: SKIP_DIRS is honoured" {
    write_migrate_cmds "alpha:echo ran > m.txt; skipme:echo ran > m.txt"
    run_cmd migrate -d "$WS"
    [ ! -e "$WS/skipme/m.txt" ]
}

@test "migrate: takes no arguments" {
    write_migrate_cmds "alpha:true"
    run_cmd migrate -d "$WS" extra
    assert_status 2
}

@test "migrate -j 2: same ordered output and outcome as -j 1" {
    write_migrate_cmds "alpha:sleep 1 && echo ran > m.txt; beta:echo ran > m.txt; gamma:exit 4"
    run_cmd migrate -d "$WS"
    assert_status 3
    seq_output="$output"
    rm -f "$WS/alpha/m.txt" "$WS/beta/m.txt"
    run_cmd migrate -j 2 -d "$WS"
    assert_status 3
    par_output="$output"
    seq_output="${seq_output//Jobs: 1/Jobs: 2}"
    [ "$par_output" = "$seq_output" ] || { echo "--- j1 ---"; echo "$seq_output"; echo "--- j2 ---"; echo "$par_output"; return 1; }
    assert_contains "Summary: 2 done, 1 failed, 0 skipped"
    [ -e "$WS/alpha/m.txt" ]
}

@test "migrate: commands never read input, with -j 1 or -j 2" {
    write_migrate_cmds "alpha:read -r line && echo got:\$line > in.txt"
    local jobs
    for jobs in 1 2; do
        run bash -c "echo hello | '$JEF_BASH' '$JEF_HOME/commands/jef-migrate.sh' -j $jobs -d '$WS'"
        assert_status 3
        assert_contains "Migration failed in alpha (exit 1)"
        [ ! -e "$WS/alpha/in.txt" ]
    done
}

@test "migrate: a ';' inside quotes does not split the entry" {
    write_migrate_cmds "alpha:sh -c \"echo one; echo two\" > out.txt; beta:echo x > out.txt"
    run_cmd migrate -d "$WS"
    assert_status 0
    [ "$(cat "$WS/alpha/out.txt")" = "$(printf 'one\ntwo')" ]
    [ "$(cat "$WS/beta/out.txt")" = x ]
}

@test "migrate: an unterminated quote exits 2 and runs nothing" {
    write_migrate_cmds "alpha:echo \"oops > m.txt; beta:echo x > m.txt"
    run_cmd migrate -d "$WS"
    assert_status 2
    assert_contains "unterminated quote"
    [ ! -e "$WS/beta/m.txt" ]
}

@test "migrate: invalid -j values are usage errors" {
    local bad
    for bad in 0 abc ""; do
        run_cmd migrate -j "$bad" -d "$WS"
        assert_status 2
    done
}

@test "migrate: docker exec entries reach docker with their arguments and no input" {
    mkdir -p "$T/fakebin"
    cat > "$T/fakebin/docker" <<'EOF'
#!/bin/sh
printf '%s|' "$@" > "$PWD/docker-args.txt"
if [ -t 0 ] || read -r line; then echo "has input" > "$PWD/docker-stdin.txt"; fi
[ "$2" = down-app ] && exit 1
exit 0
EOF
    chmod +x "$T/fakebin/docker"
    write_migrate_cmds "alpha:docker exec alpha-app sh -c \"php artisan migrate --force; php artisan db:seed\"; beta:docker exec down-app true"
    PATH="$T/fakebin:$PATH" run bash -c "echo hello | '$JEF_BASH' '$JEF_HOME/commands/jef-migrate.sh' -d '$WS'"
    assert_status 3
    [ "$(cat "$WS/alpha/docker-args.txt")" = "exec|alpha-app|sh|-c|php artisan migrate --force; php artisan db:seed|" ]
    [ ! -e "$WS/alpha/docker-stdin.txt" ]
    assert_contains "Migration failed in beta (exit 1)"
    assert_contains "Summary: 1 done, 1 failed, 1 skipped"
}

@test "migrate -m: an entry for a repository left out by -m does not warn; an unknown name still does" {
    write_migrate_cmds "alpha:echo ran > migrated.txt; beta:echo ran > migrated.txt; nosuch:echo x"
    run_cmd migrate -d "$WS" -m alpha
    assert_status 0
    refute_contains "MIGRATE_CMDS names 'beta'"
    assert_contains "MIGRATE_CMDS names 'nosuch'"
    [ "$(cat "$WS/alpha/migrated.txt")" = ran ]
    [ ! -e "$WS/beta/migrated.txt" ]
}
