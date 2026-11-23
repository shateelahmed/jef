#!/usr/bin/env bats

load test_helper

setup_file() { build_fixture_template; }

setup() { setup_workspace; }

# merge_in_progress <repo>
merge_in_progress() { [ -f "$WS/$1/.git/MERGE_HEAD" ]; }

rebase_in_progress() {
    [ -d "$WS/$1/.git/rebase-merge" ] || [ -d "$WS/$1/.git/rebase-apply" ]
}

# origin_sha <repo> <branch>: the branch tip on the bare origin
origin_sha() { git --git-dir="$ORIGINS/$1.git" rev-parse "refs/heads/$2"; }

# local_branch_with_commit <repo> <branch>: a local-only branch with a commit of its own
# (HEAD stays where it was).
local_branch_with_commit() {
    local current
    current=$(current_branch "$1")
    g "$1" checkout -q -b "$2"
    commit_on "$1" "$2.txt"
    g "$1" checkout -q "$current"
}

# conflict_on <repo> <branch>: <branch> (pushed) and main both change c.txt; HEAD ends on main.
conflict_on() {
    g "$1" checkout -q -b "$2"
    commit_on "$1" c.txt
    g "$1" push -q origin "$2" 2> /dev/null
    g "$1" checkout -q main
    commit_on "$1" c.txt
}

@test "sync: merges the default branch into pushed and local-only branches, pulling first" {
    remote_commit alpha main r.txt             # origin's main is ahead
    branch_with_commit alpha feat              # on origin and local
    remote_commit alpha feat f2.txt            # origin's feat is ahead too
    local_branch_with_commit alpha loc         # local only
    g alpha checkout -q feat
    run_cmd sync -y -d "$WS"
    assert_status 0
    assert_contains "Default branch: main"
    assert_contains "Mode: merge"
    assert_contains "Total: 2 branches in 1 repository"
    assert_contains "alpha (2)"
    assert_contains "- feat"
    assert_contains "no other branches"
    [ "$(g alpha rev-parse main)" = "$(origin_sha alpha main)" ]
    g alpha merge-base --is-ancestor main feat
    g alpha merge-base --is-ancestor main loc
    [ "$(g alpha rev-parse feat)" = "$(origin_sha alpha feat)" ]
    g alpha show-ref --verify --quiet refs/remotes/origin/feat
    g alpha cat-file -e feat:f2.txt              # pulled from origin
    refute origin_has_branch alpha loc           # local only: never pushed
    [ "$(current_branch alpha)" = feat ]         # the starting branch is back
    assert_contains "- feat (merged 1 commit from main, pushed)"
    assert_contains "- loc (local only, merged 1 commit from main)"
    assert_contains "Summary: 1 done, 0 failed, 2 skipped"
}

@test "sync: -r rebases onto the default branch and force-pushes" {
    branch_with_commit alpha feat
    commit_on alpha m.txt                      # main is ahead of feat (HEAD is main)
    local before
    before=$(g alpha rev-parse feat)
    run_cmd sync -r -y -d "$WS"
    assert_status 0
    assert_contains "Mode: rebase"
    g alpha merge-base --is-ancestor main feat
    [ "$(g alpha rev-parse feat)" != "$before" ]
    [ -z "$(g alpha rev-list --merges main..feat)" ]
    [ "$(g alpha rev-parse feat)" = "$(origin_sha alpha feat)" ]
    [ "$(current_branch alpha)" = main ]
    assert_contains "- feat (rebased onto main (1 new commit), pushed)"
}

@test "sync: nothing to do changes nothing and counts as skipped" {
    branch_with_commit alpha feat
    commit_on alpha m.txt
    g alpha push -q origin main 2> /dev/null
    run_cmd sync -y -d "$WS"                   # first run brings main into feat
    assert_status 0
    local before
    before=$(origin_sha alpha feat)
    run_cmd sync -y -d "$WS"
    assert_status 0
    assert_contains "- feat (up to date)"
    [ "$(origin_sha alpha feat)" = "$before" ]
    assert_contains "Summary: 0 done, 0 failed, 3 skipped"
}

@test "sync: a merge conflict aborts and stops that repository only" {
    branch_with_commit alpha a-first
    conflict_on alpha feat
    branch_with_commit alpha zeta
    branch_with_commit beta feat
    commit_on beta m.txt
    local zeta_before
    zeta_before=$(g alpha rev-parse zeta)
    run_cmd sync -y -d "$WS"
    assert_status 3
    assert_contains "- feat (conflict while merging main; merge aborted, stopped)"
    assert_contains "- zeta (not attempted)"
    refute merge_in_progress alpha
    [ -z "$(g alpha status --porcelain)" ]
    [ "$(g alpha rev-parse zeta)" = "$zeta_before" ]
    [ "$(current_branch alpha)" = main ]
    g alpha merge-base --is-ancestor main a-first   # synced before the conflict
    g beta merge-base --is-ancestor main feat       # the other repository carried on
    [ "$(g beta rev-parse feat)" = "$(origin_sha beta feat)" ]
    assert_contains "Summary: 1 done, 1 failed, 1 skipped"
}

@test "sync: a rebase conflict is aborted too" {
    conflict_on alpha feat
    local before
    before=$(g alpha rev-parse feat)
    run_cmd sync -r -y -d "$WS"
    assert_status 3
    assert_contains "- feat (conflict while rebasing onto main; rebase aborted, stopped)"
    refute rebase_in_progress alpha
    [ "$(g alpha rev-parse feat)" = "$before" ]
    [ "$(current_branch alpha)" = main ]
}

@test "sync: a conflict while pulling the branch from origin is aborted" {
    branch_with_commit alpha feat
    g alpha checkout -q feat
    commit_on alpha c.txt
    remote_commit alpha feat c.txt
    g alpha checkout -q main
    run_cmd sync -y -d "$WS"
    assert_status 3
    assert_contains "- feat (conflict while pulling origin/feat; merge aborted, stopped)"
    refute merge_in_progress alpha
    [ -z "$(g alpha status --porcelain)" ]
}

@test "sync: prints no raw git output, only the plan and the result" {
    branch_with_commit alpha feat
    commit_on alpha m.txt
    run_cmd sync -y -d "$WS"
    assert_status 0
    refute_contains "Working directory"
    refute_contains "Switched to branch"
    refute_contains "Already up to date"
    refute_contains "Merge made by"
    refute_contains "FETCH_HEAD"
    assert_contains "Will sync these branches (merge main into each, then push where on origin):"
    assert_contains "Synced branches:"
    assert_contains "  Total: 1 synced, 0 up to date, 0 failed, 0 not attempted in 3 repositories"
    assert_contains "    - feat (merged 1 commit from main, pushed)"
}

@test "sync: a conflict shows git's CONFLICT line under the failed branch" {
    conflict_on alpha feat
    branch_with_commit alpha zeta
    run_cmd sync -y -d "$WS"
    assert_status 3
    assert_contains "    - feat (conflict while merging main; merge aborted, stopped)"
    assert_contains "        CONFLICT (add/add): Merge conflict in c.txt"
    assert_contains "    - zeta (not attempted)"
    assert_contains "  Total: 0 synced, 0 up to date, 1 failed, 1 not attempted in 3 repositories"
}

@test "sync: a dirty working tree fails the repository without touching it" {
    branch_with_commit alpha feat
    commit_on alpha m.txt
    echo "local edit" >> "$WS/alpha/file.txt"
    local before
    before=$(g alpha rev-parse feat)
    run_cmd sync -y -d "$WS"
    assert_status 3
    assert_contains "uncommitted changes"
    assert_contains "- feat (not attempted)"
    [ "$(g alpha rev-parse feat)" = "$before" ]
    grep -q "local edit" "$WS/alpha/file.txt"
    assert_contains "Summary: 0 done, 1 failed, 2 skipped"
}

@test "sync: a default branch that cannot fast-forward stops the repository" {
    branch_with_commit alpha feat
    commit_on alpha local.txt
    remote_commit alpha main remote.txt
    run_cmd sync -y -d "$WS"
    assert_status 3
    assert_contains "- main (diverged from origin/main; stopped)"
    assert_contains "- feat (not attempted)"
    refute merge_in_progress alpha
}

@test "sync: protected branches are synced like any other" {
    branch_with_commit alpha dev
    commit_on alpha m.txt
    PROTECTED_BRANCHES="dev,qa" run_cmd sync -y -d "$WS"
    assert_status 0
    g alpha merge-base --is-ancestor main dev
    [ "$(g alpha rev-parse dev)" = "$(origin_sha alpha dev)" ]
}

@test "sync: -m limits the run and the summary to the named repositories" {
    branch_with_commit alpha feat
    branch_with_commit beta feat
    commit_on alpha m.txt
    commit_on beta m.txt
    local beta_before
    beta_before=$(g beta rev-parse feat)
    run_cmd sync -y -m alpha -d "$WS"
    assert_status 0
    assert_contains "Repositories: alpha"
    assert_contains "alpha (2)"
    refute_contains "beta ("
    refute_contains "  beta"
    g alpha merge-base --is-ancestor main feat
    [ "$(g beta rev-parse feat)" = "$beta_before" ]
    assert_contains "Summary: 1 done, 0 failed, 0 skipped"
}

@test "sync: -m accepts comma separated, repeated and unknown names" {
    branch_with_commit alpha feat
    commit_on alpha m.txt
    run_cmd sync -y -m alpha,beta -m gamma -d "$WS"
    assert_status 0
    run_cmd sync -y -m alpha,nosuch -d "$WS"
    assert_status 2
    assert_contains "unknown repository 'nosuch'"
}

@test "sync: without a terminal and without --yes it exits 2 and changes nothing" {
    branch_with_commit alpha feat
    commit_on alpha m.txt
    local before
    before=$(g alpha rev-parse feat)
    run_cmd sync -d "$WS" < /dev/null
    assert_status 2
    assert_contains "Not running in a terminal. Re-run with --yes to sync. Nothing was synced."
    [ "$(g alpha rev-parse feat)" = "$before" ]
}

@test "sync: declining at the prompt exits 1 and changes nothing" {
    branch_with_commit alpha feat
    commit_on alpha m.txt
    local before
    before=$(g alpha rev-parse feat)
    run_tty n "$JEF_BASH" "$JEF_HOME/commands/jef-sync.sh" -d "$WS"
    assert_status 1
    assert_contains "Sync 1 branch in 3 repositories by merging main? [y/N]"
    assert_contains "Aborted. Nothing was synced."
    [ "$(g alpha rev-parse feat)" = "$before" ]
}

@test "sync: answering y at the prompt syncs" {
    branch_with_commit alpha feat
    commit_on alpha m.txt
    run_tty y "$JEF_BASH" "$JEF_HOME/commands/jef-sync.sh" -d "$WS"
    assert_status 0
    g alpha merge-base --is-ancestor main feat
}

@test "sync: -r asks about force-pushing at the prompt" {
    branch_with_commit alpha feat
    commit_on alpha m.txt
    run_tty n "$JEF_BASH" "$JEF_HOME/commands/jef-sync.sh" -r -d "$WS"
    assert_status 1
    assert_contains "Sync 1 branch in 3 repositories by rebasing onto main and force-pushing them (--force-with-lease)? [y/N]"
}

@test "sync: -n shows the plan, asks nothing and changes nothing" {
    branch_with_commit alpha feat
    commit_on alpha m.txt
    local before
    before=$(g alpha rev-parse feat)
    run_cmd sync -n -d "$WS" < /dev/null
    assert_status 0
    assert_contains "Dry run: true"
    assert_contains "Would sync these branches (merge main into each, then push where on origin):"
    assert_contains "Total: 1 branch in 1 repository"
    assert_contains "alpha (1)"
    assert_contains "- feat"
    refute_contains "[y/N]"
    [ "$(g alpha rev-parse feat)" = "$before" ]
    [ "$(current_branch alpha)" = main ]
}

@test "sync: DEFAULT_BRANCH unset exits 1" {
    write_env "" "skipme" ""
    run_cmd sync -y -d "$WS"
    assert_status 1
    assert_contains "DEFAULT_BRANCH is not set"
}

@test "sync: a repository without a local default branch is skipped" {
    g gamma checkout -q -b other
    g gamma branch -q -D main
    branch_with_commit alpha feat
    commit_on alpha m.txt
    run_cmd sync -y -d "$WS"
    assert_status 0
    assert_contains "no main, skipped"
    [ "$(current_branch gamma)" = other ]
    assert_contains "Summary: 1 done, 0 failed, 2 skipped"
}

@test "sync: no positional arguments are accepted" {
    run_cmd sync -y -d "$WS" extra
    assert_status 2
    assert_contains "0 arguments required. 1 provided"
}

@test "sync: -j 1 gives the same result as the default" {
    local repo
    for repo in alpha beta; do
        branch_with_commit "$repo" feat
        commit_on "$repo" m.txt
    done
    run_cmd sync -y -j 1 -d "$WS"
    assert_status 0
    assert_contains "Jobs: 1"
    for repo in alpha beta; do
        g "$repo" merge-base --is-ancestor main feat
        [ "$(g "$repo" rev-parse feat)" = "$(origin_sha "$repo" feat)" ]
    done
    assert_contains "Summary: 2 done, 0 failed, 1 skipped"
}

@test "sync: the default is every repository at once" {
    run_cmd sync -n -d "$WS"
    assert_status 0
    assert_contains "Jobs: all"
    run_cmd sync -n -j 2 -d "$WS"
    assert_contains "Jobs: 2"
}

@test "sync: -c clears the proxy" {
    branch_with_commit alpha feat
    commit_on alpha m.txt
    setup_git_spy
    export HTTPS_PROXY="http://proxy.invalid:1"
    run_cmd sync -y -c -d "$WS"
    assert_status 0
    assert_contains "Cleared proxy"
    [ -s "$JEF_SPY_LOG" ]
    refute grep -q "HTTPS_PROXY=http://proxy.invalid" "$JEF_SPY_LOG"
}
