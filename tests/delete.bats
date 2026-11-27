#!/usr/bin/env bats

load test_helper

setup_file() { build_fixture_template; }

setup() { setup_workspace; }

@test "delete: removes the local branch and leaves the remote" {
    add_remote_branch alpha feat
    add_local_branch beta feat
    run_cmd delete -y -d "$WS" feat
    assert_status 0
    assert_contains "Branch to delete: feat"
    assert_contains "Clear proxy: false"
    assert_contains "Delete remote branch: false"
    assert_contains "local deleted: alpha"
    assert_contains "local deleted: beta"
    refute g alpha show-ref --quiet --heads feat
    refute g beta show-ref --quiet --heads feat
    origin_has_branch alpha feat
}

@test "delete: switches to DEFAULT_BRANCH first when the branch is checked out" {
    add_local_branch alpha feat
    g alpha checkout -q feat
    run_cmd delete -y -d "$WS" feat
    assert_contains "local deleted: alpha"
    [ "$(current_branch alpha)" = main ]
    refute g alpha show-ref --quiet --heads feat
}

@test "delete -r: also deletes the remote branch" {
    add_remote_branch alpha feat
    add_local_branch beta feat
    remote_only_branch gamma feat
    run_cmd delete -y -r -d "$WS" feat
    assert_status 0
    assert_contains "Delete remote branch: true"
    assert_contains "local & remote deleted: alpha"
    assert_contains "local deleted: beta"
    assert_contains "remote deleted: gamma"
    refute origin_has_branch alpha feat
    refute origin_has_branch gamma feat
}

@test "delete --delete-remote-branch is the long form of -r" {
    add_remote_branch alpha feat
    run_cmd delete -y --delete-remote-branch -d "$WS" feat
    assert_contains "local & remote deleted: alpha"
    refute origin_has_branch alpha feat
}

@test "delete -r: never deletes the remote default branch" {
    add_local_branch alpha feat
    g alpha checkout -q feat
    run_cmd delete -y -r -d "$WS" main
    assert_contains "main is the default branch in $WS/alpha/. It cannot be deleted."
    origin_has_branch alpha main
}

@test "delete: refuses when it cannot leave the branch being deleted" {
    # alpha is on main and DEFAULT_BRANCH is main, so main cannot be left.
    run_cmd delete -y -d "$WS" main
    assert_contains "Could not checkout to default branch in"
    g alpha show-ref --quiet --heads main
}

@test "delete: reports when the branch is found nowhere" {
    run_cmd delete -y -d "$WS" nope
    assert_status 0
    assert_contains "Branch not found in any repository"
}

@test "delete: leaves SKIP_DIRS repos alone" {
    add_local_branch skipme feat
    run_cmd delete -y -d "$WS" feat
    assert_contains "Branch not found in any repository"
    g skipme show-ref --quiet --heads feat
}

@test "delete: requires exactly one argument" {
    run_cmd delete -y -d "$WS"
    assert_contains "1 argument required. 0 provided"
}

@test "delete -r: the default branch comes from the local origin/HEAD ref" {
    # origin/HEAD points at develop while the real remote HEAD is main: only the
    # local ref can make develop "the default branch".
    add_remote_branch alpha develop
    g alpha fetch -q origin
    g alpha symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/develop
    run_cmd delete -y -r -d "$WS" develop
    assert_contains "develop is the default branch in $WS/alpha/. It cannot be deleted."
    origin_has_branch alpha develop
}

@test "delete -r: falls back to the remote when origin/HEAD is missing" {
    add_remote_branch alpha develop
    g alpha remote set-head origin -d 2> /dev/null || true
    refute g alpha symbolic-ref --quiet refs/remotes/origin/HEAD
    run_cmd delete -y -r -d "$WS" develop
    refute origin_has_branch alpha develop
    g alpha checkout -q -b other
    run_cmd delete -y -r -d "$WS" main
    assert_contains "main is the default branch in $WS/alpha/. It cannot be deleted."
}

# delete_tty <input> <args...>: run jef delete on a fake terminal that answers
# the confirmation prompt with <input> (see run_tty in test_helper.bash).
delete_tty() {
    local input="$1"
    shift
    run_tty "$input" "$JEF_BASH" "$JEF_HOME/commands/jef-delete.sh" "$@"
}

refs_snapshot() {
    local d
    for d in "$WS"/alpha "$WS"/beta "$WS"/gamma; do
        git -C "$d" for-each-ref
    done
    for d in "$ORIGINS"/*.git; do
        git --git-dir="$d" for-each-ref
    done
}

@test "delete plan: shows local, remote or both per repository with -r" {
    add_remote_branch alpha feat
    add_local_branch beta feat
    remote_only_branch gamma feat
    run_cmd delete -y -r -d "$WS" feat
    assert_contains "Will delete branch 'feat':"
    assert_contains "alpha: local and remote (origin)"
    assert_contains "beta: local"
    assert_contains "gamma: remote (origin)"
    refute_contains "local only"
}

@test "delete plan: without -r only the local branch is listed" {
    add_remote_branch alpha feat
    remote_only_branch gamma feat
    run_cmd delete -y -d "$WS" feat
    assert_contains "(local only; add -r to also delete on origin)"
    assert_contains "alpha: local"
    refute_contains "alpha: local and remote"
    refute_contains "gamma:"
    origin_has_branch gamma feat
}

@test "delete plan: lists repositories that will be skipped or fail" {
    # DEFAULT_BRANCH=feat: alpha (on feat) cannot leave it, beta can be deleted
    write_env "" "skipme" "feat"
    add_local_branch alpha feat
    g alpha checkout -q feat
    add_local_branch beta feat
    run_cmd delete -y -d "$WS" feat
    assert_contains "alpha: will fail: cannot leave the branch"
    assert_contains "beta: local"
    # a repository on a side branch whose remote default branch is the one being deleted
    write_env "" "skipme" "main"
    g gamma checkout -q -b side
    run_cmd delete -y -r -d "$WS" main
    assert_contains "gamma: local; remote skipped: is the remote default branch"
}

@test "delete: no terminal and no --yes exits 2 and deletes nothing" {
    add_remote_branch alpha feat
    add_local_branch beta feat
    local before after
    before=$(refs_snapshot)
    run_cmd delete -r -d "$WS" feat
    assert_status 2
    assert_contains "alpha: local and remote (origin)"
    assert_contains "Not running in a terminal. Re-run with --yes to delete. Nothing was deleted."
    after=$(refs_snapshot)
    [ "$before" = "$after" ]
}

@test "delete: answering n aborts with exit 1 and deletes nothing" {
    add_remote_branch alpha feat
    add_local_branch beta feat
    local before after
    before=$(refs_snapshot)
    delete_tty n -r -d "$WS" feat
    assert_status 1
    assert_contains "Delete branch 'feat' in 2 repositories? [y/N]"
    assert_contains "Aborted. Nothing was deleted."
    after=$(refs_snapshot)
    [ "$before" = "$after" ]
}

@test "delete: an empty answer (Enter) aborts" {
    add_local_branch alpha feat
    delete_tty "" -d "$WS" feat
    assert_status 1
    assert_contains "Delete branch 'feat' in 1 repository? [y/N]"
    g alpha show-ref --quiet --heads feat
}

@test "delete: answering y deletes" {
    add_remote_branch alpha feat
    add_local_branch beta feat
    delete_tty y -r -d "$WS" feat
    assert_status 0
    assert_contains "local deleted: beta"
    refute g alpha show-ref --quiet --heads feat
    refute origin_has_branch alpha feat
}

@test "delete: -y skips the prompt but still prints the plan" {
    add_local_branch alpha feat
    run_cmd delete -y -d "$WS" feat
    assert_status 0
    assert_contains "alpha: local"
    refute_contains "[y/N]"
    refute g alpha show-ref --quiet --heads feat
}

@test "delete: --yes is the long form of -y" {
    add_local_branch alpha feat
    run_cmd delete --yes -d "$WS" feat
    assert_status 0
    refute_contains "[y/N]"
    refute g alpha show-ref --quiet --heads feat
}

@test "delete --help lists -y, --yes" {
    run_cmd delete --help
    assert_contains "-y, --yes"
    assert_contains "Delete without asking for confirmation"
}

@test "delete: nothing to delete does not prompt" {
    run_cmd delete -d "$WS" nope
    assert_status 0
    assert_contains "Branch not found in any repository"
    refute_contains "[y/N]"
    refute_contains "Not running in a terminal"
}

@test "delete: --dry-run never prompts and wins over --yes" {
    add_local_branch alpha feat
    run_cmd delete -n -d "$WS" feat
    assert_status 0
    refute_contains "[y/N]"
    run_cmd delete -n -y -d "$WS" feat
    assert_status 0
    assert_contains "Would delete local branch feat"
    g alpha show-ref --quiet --heads feat
}

@test "delete -r -y: queries each remote once (ls-remote runs once per repo)" {
    add_remote_branch alpha feat
    mkdir "$T/spy"
    JEF_REAL_GIT="$(command -v git)"
    export JEF_REAL_GIT JEF_SPY_LOG="$T/git-args.log"
    printf '#!/bin/bash\necho "$*" >> "$JEF_SPY_LOG"\nexec "$JEF_REAL_GIT" "$@"\n' > "$T/spy/git"
    chmod +x "$T/spy/git"
    PATH="$T/spy:$PATH" run_cmd delete -r -y -d "$WS" feat
    assert_status 0
    [ "$(grep -c "ls-remote" "$JEF_SPY_LOG")" -eq 3 ]
    refute origin_has_branch alpha feat
}

@test "delete: header only for repos with something to delete or a message" {
    add_local_branch alpha feat
    run_cmd delete -y -d "$WS" feat
    assert_contains "Working directory alpha"
    refute_contains "Working directory beta"
    refute_contains "Working directory gamma"
    assert_contains "Summary: 1 done, 0 failed, 2 skipped"
    run_cmd delete -y -d "$WS" main
    assert_contains "Working directory alpha"
    assert_contains "Could not checkout to default branch"
}

@test "delete --dry-run: no header for repos without the branch" {
    add_local_branch alpha feat
    run_cmd delete -n -d "$WS" feat
    assert_contains "Working directory alpha"
    refute_contains "Working directory beta"
    assert_contains "Summary: 1 done, 0 failed, 2 skipped"
}

@test "delete -m: deletes the branch only in the named repositories" {
    add_local_branch alpha feat
    add_local_branch beta feat
    add_local_branch gamma feat
    run_cmd delete -y -d "$WS" -m alpha,gamma feat
    assert_status 0
    assert_contains "Repositories: alpha,gamma"
    assert_contains "local deleted: alpha"
    assert_contains "local deleted: gamma"
    refute_contains "beta"
    refute g alpha show-ref --quiet --heads feat
    refute g gamma show-ref --quiet --heads feat
    g beta show-ref --quiet --heads feat
}
