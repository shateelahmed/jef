#!/usr/bin/env bats

load test_helper

setup_file() { build_fixture_template; }

setup() { setup_workspace; }

@test "checkout: switches repos that have the branch locally" {
    add_local_branch alpha feat
    add_local_branch beta feat
    add_local_branch skipme feat
    run_cmd checkout -d "$WS" feat
    assert_status 0
    assert_contains "Target directory: $WS"
    assert_contains "Branch to checkout: feat"
    assert_contains "Working directory alpha"
    assert_contains "Working directory beta"
    assert_contains "Checked out"
    refute_contains "Working directory gamma"
    refute_contains "Working directory skipme"
    refute_contains "Working directory plain"
    [ "$(current_branch alpha)" = feat ]
    [ "$(current_branch beta)" = feat ]
    [ "$(current_branch gamma)" = main ]
    [ "$(current_branch skipme)" = main ]
}

@test "checkout: no output for repos when the branch exists nowhere" {
    run_cmd checkout -d "$WS" nope
    assert_status 0
    refute_contains "Working directory"
}

@test "checkout: a branch that exists only on the remote is not checked out" {
    remote_only_branch alpha feat
    run_cmd checkout -d "$WS" feat
    refute_contains "Working directory alpha"
    [ "$(current_branch alpha)" = main ]
}

@test "checkout: already on the branch still reports Checked out" {
    add_local_branch alpha feat
    g alpha checkout -q feat
    run_cmd checkout -d "$WS" feat
    assert_contains "Working directory alpha"
    assert_contains "Checked out"
    [ "$(current_branch alpha)" = feat ]
}

@test "checkout: requires exactly one argument" {
    run_cmd checkout -d "$WS"
    assert_contains "1 argument required. 0 provided"
    run_cmd checkout -d "$WS" a b
    assert_contains "1 argument required. 2 provided"
    refute_contains "Working directory"
}

# --- jef checkout -b <new_branch> <base> ---

# checkout_b_tty <keys> <args...>: the picker in a fake terminal
checkout_b_tty() {
    local keys="$1"
    shift
    run_tty_keys 'Select repositories' "$keys" "$JEF_BASH" "$JEF_HOME/commands/jef-checkout.sh" -d "$WS" "$@"
}

# a base branch with its own commit in alpha and beta (gamma has none)
setup_base() {
    branch_with_commit alpha dev
    branch_with_commit beta dev
}

@test "checkout -b: --repo creates the branch at the base in the named repos only" {
    setup_base
    run_cmd checkout -d "$WS" -b feat dev -m alpha,beta
    assert_status 0
    assert_contains "New branch: feat"
    assert_contains "Base: dev"
    assert_contains "Working directory alpha"
    assert_contains "Created and checked out"
    assert_contains "2 done, 0 failed, 0 skipped"
    [ "$(current_branch alpha)" = feat ]
    [ "$(current_branch beta)" = feat ]
    [ "$(g alpha rev-parse feat)" = "$(g alpha rev-parse dev)" ]
    [ "$(g beta rev-parse feat)" = "$(g beta rev-parse dev)" ]
    refute g gamma show-ref --verify --quiet refs/heads/feat
    [ "$(current_branch gamma)" = main ]
}

@test "checkout -b: a remote base does not become the new branch's upstream" {
    run_cmd checkout -d "$WS" -b feat origin/main -m alpha
    assert_status 0
    assert_contains "Created and checked out"
    [ "$(current_branch alpha)" = feat ]
    run g alpha config --get branch.feat.merge
    [ "$status" -ne 0 ]
}

@test "checkout -b: repeated --repo and space separated names" {
    run_cmd checkout -d "$WS" --new feat main --repo alpha --repo "beta gamma"
    assert_status 0
    assert_contains "3 done"
}

@test "checkout -b: requires exactly two arguments" {
    run_cmd checkout -d "$WS" -b feat
    assert_status 2
    assert_contains "2 arguments required. 1 provided"
    run_cmd checkout -d "$WS" -b a b c
    assert_status 2
    assert_contains "2 arguments required. 3 provided"
    refute g alpha show-ref --verify --quiet refs/heads/feat
}

@test "checkout -b: invalid new branch name exits 2" {
    run_cmd checkout -d "$WS" -b "bad name" main -m alpha
    assert_status 2
}

@test "checkout -m without -b: checks the branch out in the named repositories only" {
    add_local_branch alpha feat
    add_local_branch beta feat
    run_cmd checkout -d "$WS" -m alpha feat
    assert_status 0
    assert_contains "Repositories: alpha"
    assert_contains "Working directory alpha"
    refute_contains "Working directory beta"
    [ "$(current_branch alpha)" = feat ]
    [ "$(current_branch beta)" = main ]
}

@test "checkout -m without -b: an unknown name exits 2 and checks nothing out" {
    add_local_branch alpha feat
    run_cmd checkout -d "$WS" -m nosuch feat
    assert_status 2
    assert_contains "unknown repository 'nosuch'"
    [ "$(current_branch alpha)" = main ]
}

@test "checkout -b: unknown --repo name exits 2 and creates nothing" {
    run_cmd checkout -d "$WS" -b feat main -m alpha,nosuch
    assert_status 2
    assert_contains "unknown repository 'nosuch'"
    refute g alpha show-ref --verify --quiet refs/heads/feat
}

@test "checkout -b: no terminal and no --repo exits 2" {
    run_cmd checkout -d "$WS" -b feat main < /dev/null
    assert_status 2
    assert_contains "Not running in a terminal. Re-run with --repo to choose repositories. Nothing was created."
    refute g alpha show-ref --verify --quiet refs/heads/feat
}

@test "checkout -b: --repo names an unavailable repository: reported and skipped" {
    setup_base
    add_local_branch beta feat # beta already has feat
    run_cmd checkout -d "$WS" -b feat dev -m alpha,beta,gamma
    assert_status 0
    assert_contains "Skipped: branch exists"
    assert_contains "Skipped: no dev"
    assert_contains "1 done, 0 failed, 2 skipped"
    [ "$(current_branch alpha)" = feat ]
    [ "$(current_branch beta)" = main ]
    [ "$(current_branch gamma)" = main ]
}

@test "checkout -b: a failing creation exits 3 and the next repository is still processed" {
    # alpha: a dirty file that differs between main and the base, so git refuses to switch
    g alpha checkout -q -b other
    echo changed > "$WS/alpha/file.txt"
    g alpha commit -q -am "change file"
    g alpha checkout -q main
    echo dirty > "$WS/alpha/file.txt"
    g beta branch other main
    run_cmd checkout -d "$WS" -b feat other -m alpha,beta
    assert_status 3
    assert_contains "Could not create"
    assert_contains "Created and checked out"
    assert_contains "1 done, 1 failed, 0 skipped"
    [ "$(current_branch beta)" = feat ]
    [ "$(current_branch alpha)" = main ]
}

@test "checkout -b picker: arrow down, space, enter creates only in that repo" {
    checkout_b_tty '\033[B \n' -b feat main
    assert_status 0
    assert_contains "Created and checked out"
    assert_contains "1 done, 0 failed, 0 skipped"
    [ "$(current_branch beta)" = feat ]
    [ "$(current_branch alpha)" = main ]
    [ "$(current_branch gamma)" = main ]
}

@test "checkout -b picker: j and k move, space toggles" {
    checkout_b_tty 'jjk \n' -b feat main
    assert_status 0
    [ "$(current_branch beta)" = feat ]
    [ "$(current_branch alpha)" = main ]
    [ "$(current_branch gamma)" = main ]
}

@test "checkout -b picker: a ticks every available repository" {
    add_local_branch gamma feat
    checkout_b_tty 'a\n' -b feat main
    assert_status 0
    assert_contains "2 done, 0 failed, 0 skipped"
    [ "$(current_branch alpha)" = feat ]
    [ "$(current_branch beta)" = feat ]
    [ "$(current_branch gamma)" = main ]
}

@test "checkout -b picker: unavailable repositories are shown with the reason and cannot be ticked" {
    add_local_branch gamma feat
    checkout_b_tty 'jj \n' -b feat main # space on gamma does nothing, so nothing is ticked
    assert_status 1
    assert_contains "gamma (branch exists)"
    assert_contains "Aborted. Nothing was created."
    [ "$(current_branch gamma)" = main ]
}

@test "checkout -b picker: a base that does not resolve is listed as unavailable" {
    branch_with_commit alpha dev
    checkout_b_tty 'a\n' -b feat dev
    assert_status 0
    assert_contains "beta (no dev)"
    [ "$(current_branch alpha)" = feat ]
    [ "$(current_branch beta)" = main ]
}

@test "checkout -b picker: q cancels" {
    checkout_b_tty ' q' -b feat main
    assert_status 1
    assert_contains "Aborted. Nothing was created."
    [ "$(current_branch alpha)" = main ]
    refute g alpha show-ref --verify --quiet refs/heads/feat
}

@test "checkout -b picker: Esc cancels" {
    checkout_b_tty ' \033' -b feat main
    assert_status 1
    assert_contains "Aborted. Nothing was created."
    refute g alpha show-ref --verify --quiet refs/heads/feat
}

@test "checkout -b picker: Enter with nothing ticked aborts" {
    checkout_b_tty '\n' -b feat main
    assert_status 1
    assert_contains "Aborted. Nothing was created."
    refute g alpha show-ref --verify --quiet refs/heads/feat
}

@test "checkout -b picker: --repo skips the picker" {
    run_tty_keys 'Created and checked out' '' "$JEF_BASH" "$JEF_HOME/commands/jef-checkout.sh" -d "$WS" -b feat main -m gamma
    assert_status 0
    refute_contains "Select repositories"
    [ "$(current_branch gamma)" = feat ]
}

@test "checkout -b: a base that exists only on origin is used and not tracked" {
    remote_only_branch alpha dev
    run_cmd checkout -d "$WS" -b feat dev -m alpha
    assert_status 0
    assert_contains "Created from origin/dev and checked out"
    [ "$(current_branch alpha)" = feat ]
    [ "$(g alpha rev-parse feat)" = "$(g alpha rev-parse origin/dev)" ]
    refute g alpha config --get branch.feat.remote
}

@test "checkout -b picker: the cursor starts on the first available row" {
    add_local_branch alpha feat # alpha is unavailable, so the cursor starts on beta
    checkout_b_tty ' \n' -b feat main
    assert_status 0
    [ "$(current_branch beta)" = feat ]
    [ "$(current_branch alpha)" = main ]
    [ "$(current_branch gamma)" = main ]
}

@test "checkout -b picker: with no available repository there is no picker and it exits 1" {
    add_local_branch alpha feat
    add_local_branch beta feat
    add_local_branch gamma feat
    run_tty_keys 'No repository can get' '' "$JEF_BASH" "$JEF_HOME/commands/jef-checkout.sh" -d "$WS" -b feat main
    assert_status 1
    assert_contains "Skipped: branch exists"
    assert_contains "No repository can get feat. Nothing was created."
    refute_contains "Select repositories"
}
