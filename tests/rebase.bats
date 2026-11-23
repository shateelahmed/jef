#!/usr/bin/env bats

load test_helper

setup_file() { build_fixture_template; }

setup() { setup_workspace; }

# diverge <repo> <branch> <base>: <branch> gets a commit of its own, then <base> gets one
# too, so rebasing <branch> onto <base> has to replay a commit. HEAD ends on <base>.
diverge() {
    g "$1" checkout -q -b "$2"
    commit_on "$1" "$2.txt"
    g "$1" push -q origin "$2" 2> /dev/null
    g "$1" checkout -q "$3" 2> /dev/null || g "$1" checkout -q -b "$3"
    commit_on "$1" "$3-$2.txt"
}

# rebase_tty <input> <args...>: run jef rebase on a fake terminal answering the prompt.
rebase_tty() {
    local input="$1"
    shift
    run_tty "$input" "$JEF_BASH" "$JEF_HOME/commands/jef-rebase.sh" "$@"
}

rebase_in_progress() {
    [ -d "$WS/$1/.git/rebase-merge" ] || [ -d "$WS/$1/.git/rebase-apply" ]
}

@test "rebase: replays the branch onto the other in repos that have both" {
    diverge alpha feat main
    add_local_branch beta feat           # beta already contains main: up to date
    local before
    before=$(g alpha rev-parse feat)
    run_cmd rebase -y -d "$WS" feat main
    assert_status 0
    assert_contains "Branch: feat"
    assert_contains "Onto: main"
    assert_contains "Push: false"
    assert_contains "Dry run: false"
    assert_contains "Will rebase 'feat' onto 'main':"
    assert_contains "alpha: 1 commit"
    assert_contains "beta: already up to date"
    assert_contains "Working directory alpha"
    [ "$(current_branch alpha)" = feat ]
    g alpha merge-base --is-ancestor main feat
    [ "$(g alpha rev-parse feat)" != "$before" ]
    [ -f "$WS/alpha/main-feat.txt" ]
    [ -f "$WS/alpha/feat.txt" ]
    assert_contains "Summary: 1 done, 0 failed, 2 skipped"
}

@test "rebase: repos lacking either branch are skipped silently" {
    add_local_branch alpha feat
    add_local_branch beta other        # each branch exists somewhere, but no repo has both
    run_cmd rebase -y -d "$WS" feat other
    assert_status 0
    refute_contains "Working directory"
    refute_contains "Will rebase"
    assert_contains "Summary: 0 done, 0 failed, 3 skipped"
}

@test "rebase: a branch that already contains onto is skipped and not checked out" {
    g alpha checkout -q -b feat
    commit_on alpha f.txt
    g alpha checkout -q main
    run_cmd rebase -y -d "$WS" feat main
    assert_status 0
    assert_contains "already up to date"
    refute_contains "Will rebase"
    [ "$(current_branch alpha)" = main ]
    assert_contains "Summary: 0 done, 0 failed, 3 skipped"
}

@test "rebase: a conflict aborts the rebase, leaves the repo as it was and exits 3" {
    g alpha checkout -q -b feat
    commit_on alpha c.txt
    g alpha checkout -q main
    commit_on alpha c.txt
    diverge beta feat2 main
    local before
    before=$(g alpha rev-parse feat)
    run_cmd rebase -y -d "$WS" feat main
    assert_status 3
    assert_contains "Rebase of feat onto main failed in alpha; aborted, nothing changed"
    [ "$(g alpha rev-parse feat)" = "$before" ]
    refute rebase_in_progress alpha
    [ -z "$(g alpha status --porcelain)" ]
    assert_contains "Summary: 0 done, 1 failed, 2 skipped"
}

@test "rebase: a conflict in one repo does not stop the others" {
    g alpha checkout -q -b feat
    commit_on alpha c.txt
    g alpha checkout -q main
    commit_on alpha c.txt
    diverge beta feat main
    run_cmd rebase -y -d "$WS" feat main
    assert_status 3
    g beta merge-base --is-ancestor main feat
    assert_contains "Summary: 1 done, 1 failed, 1 skipped"
}

@test "rebase: a dirty working tree fails the repo without aborting anything" {
    diverge alpha feat main
    echo "local edit" >> "$WS/alpha/file.txt"
    local before
    before=$(g alpha rev-parse feat)
    run_cmd rebase -y -d "$WS" feat main
    assert_status 3
    assert_contains "Rebase of feat onto main failed in alpha"
    [ "$(g alpha rev-parse feat)" = "$before" ]
    refute rebase_in_progress alpha
    grep -q "local edit" "$WS/alpha/file.txt"
}

@test "rebase: -p force-pushes the rebased branch to origin" {
    diverge alpha feat main
    run_cmd rebase -y -p -d "$WS" feat main
    assert_status 0
    assert_contains "Push: true"
    assert_contains "force-push"
    [ "$(git --git-dir="$ORIGINS/alpha.git" rev-parse refs/heads/feat)" = "$(g alpha rev-parse feat)" ]
}

@test "rebase: without -p origin is not touched" {
    diverge alpha feat main
    local before
    before=$(git --git-dir="$ORIGINS/alpha.git" rev-parse refs/heads/feat)
    run_cmd rebase -y -d "$WS" feat main
    assert_status 0
    [ "$(git --git-dir="$ORIGINS/alpha.git" rev-parse refs/heads/feat)" = "$before" ]
}

@test "rebase: -p does not push a branch that was already up to date" {
    g alpha checkout -q -b feat
    commit_on alpha f.txt
    g alpha checkout -q main
    run_cmd rebase -y -p -d "$WS" feat main
    assert_status 0
    refute origin_has_branch alpha feat
}

@test "rebase: a failed push marks the repo failed" {
    diverge alpha feat main
    remote_commit alpha feat other.txt   # origin/feat moved on: the lease is stale
    run_cmd rebase -y -p -d "$WS" feat main
    assert_status 3
    assert_contains "Could not force-push feat to origin in alpha"
    assert_contains "Summary: 0 done, 1 failed, 2 skipped"
}

@test "rebase: -n changes nothing, even with -y" {
    diverge alpha feat main
    local before before_head
    before=$(g alpha rev-parse feat)
    before_head=$(current_branch alpha)
    run_cmd rebase -n -y -p -d "$WS" feat main
    assert_status 0
    assert_contains "Dry run: true"
    assert_contains "Would rebase feat onto main (1 commit)"
    assert_contains "Would force-push feat to origin"
    refute_contains "Will rebase"
    [ "$(g alpha rev-parse feat)" = "$before" ]
    [ "$(current_branch alpha)" = "$before_head" ]
    assert_contains "Summary: 1 done, 0 failed, 2 skipped"
}

@test "rebase: --dry-run without -p does not mention pushing" {
    diverge alpha feat main
    run_cmd rebase --dry-run -d "$WS" feat main
    assert_contains "Would rebase feat onto main"
    refute_contains "force-push"
}

@test "rebase: declining at the prompt exits 1 and changes nothing" {
    diverge alpha feat main
    local before
    before=$(g alpha rev-parse feat)
    rebase_tty n -d "$WS" feat main
    assert_status 1
    assert_contains "Rebase 'feat' onto 'main' in 1 repository?"
    assert_contains "Aborted. Nothing was rebased."
    [ "$(g alpha rev-parse feat)" = "$before" ]
    [ "$(current_branch alpha)" = main ]
}

@test "rebase: answering yes at the prompt rebases" {
    diverge alpha feat main
    rebase_tty y -d "$WS" feat main
    assert_status 0
    g alpha merge-base --is-ancestor main feat
}

@test "rebase: without a terminal and without --yes it exits 2 and changes nothing" {
    diverge alpha feat main
    local before
    before=$(g alpha rev-parse feat)
    run_cmd rebase -d "$WS" feat main < /dev/null
    assert_status 2
    assert_contains "Not running in a terminal. Re-run with --yes to rebase. Nothing was rebased."
    [ "$(g alpha rev-parse feat)" = "$before" ]
}

@test "rebase: nothing to rebase asks nothing, even without a terminal" {
    add_local_branch alpha feat
    run_cmd rebase -d "$WS" feat main < /dev/null
    assert_status 0
}

@test "rebase: a branch that exists in no repository exits 2 before any plan" {
    diverge alpha feat main
    local before
    before=$(g alpha rev-parse feat)
    run_cmd rebase -y -d "$WS" feat nosuch
    assert_status 2
    assert_contains "Branch 'nosuch' does not exist in any repository"
    refute_contains "Branch 'feat' does not exist"
    refute_contains "Will rebase"
    [ "$(current_branch alpha)" = main ]
    [ "$(g alpha rev-parse feat)" = "$before" ]
    run_cmd rebase -y -d "$WS" nosuch main
    assert_status 2
    assert_contains "Branch 'nosuch' does not exist in any repository"
    refute_contains "Branch 'main' does not exist"
}

@test "rebase: both branches missing everywhere print both lines" {
    run_cmd rebase -y -d "$WS" nosuch1 nosuch2
    assert_status 2
    assert_contains "Branch 'nosuch1' does not exist in any repository"
    assert_contains "Branch 'nosuch2' does not exist in any repository"
}

@test "rebase: a branch missing everywhere exits 2 with --dry-run, --yes and without a terminal, asking nothing" {
    diverge alpha feat main
    run_cmd rebase -n -d "$WS" feat nosuch
    assert_status 2
    assert_contains "Branch 'nosuch' does not exist in any repository"
    run_cmd rebase -y -d "$WS" feat nosuch < /dev/null
    assert_status 2
    run_cmd rebase -d "$WS" feat nosuch < /dev/null
    assert_status 2
    assert_contains "Branch 'nosuch' does not exist in any repository"
    refute_contains "[y/N]"
    refute_contains "Not running in a terminal"
}

@test "rebase: a branch that exists only on origin counts as absent" {
    diverge alpha feat main
    g alpha push -q origin main:onlyremote
    run_cmd rebase -y -d "$WS" feat onlyremote
    assert_status 2
    assert_contains "Branch 'onlyremote' does not exist in any repository"
}

@test "rebase: requires exactly two arguments" {
    run_cmd rebase -d "$WS" only-one
    assert_status 2
    assert_contains "2 arguments required. 1 provided"
    run_cmd rebase -d "$WS"
    assert_contains "2 arguments required. 0 provided"
}

@test "rebase: rejects invalid branch names" {
    run_cmd rebase -d "$WS" -- -bad main
    assert_status 2
    assert_contains "'-bad' is not a valid branch name"
    run_cmd rebase -d "$WS" -- feat -bad
    assert_status 2
    assert_contains "'-bad' is not a valid branch name"
}

@test "rebase: skips SKIP_DIRS repos" {
    diverge skipme feat main
    run_cmd rebase -y -d "$WS" feat main
    refute_contains "skipme"
    refute_contains "Will rebase"
}
