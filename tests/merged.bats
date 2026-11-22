#!/usr/bin/env bats

load test_helper

setup_file() { build_fixture_template; }

setup() { setup_workspace; }

# merged_tty <input> <args...>: run jef merged on a fake terminal that answers the
# confirmation prompt with <input> (see run_tty in test_helper.bash).
merged_tty() {
    local input="$1"
    shift
    run_tty "$input" "$JEF_BASH" "$JEF_HOME/commands/jef-merged.sh" "$@"
}

# assert_line_is <text>: some line of the output is exactly <text>.
assert_line_is() {
    if printf '%s\n' "$output" | grep -qxF -- "$1"; then
        return 0
    fi
    echo "expected a line: $1"
    echo "--- output ---"
    echo "$output"
    return 1
}

refute_line_is() {
    if printf '%s\n' "$output" | grep -qxF -- "$1"; then
        echo "unexpected line: $1"
        return 1
    fi
}

refs_snapshot() {
    local d
    for d in "$WS"/alpha "$WS"/beta "$WS"/gamma; do
        git -C "$d" for-each-ref refs/heads
    done
    for d in "$ORIGINS"/*.git; do
        git --git-dir="$d" for-each-ref
    done
}

@test "merged: lists ancestor-merged local and remote branches per repository" {
    add_remote_branch alpha feat-a
    add_local_branch alpha feat-b
    remote_only_branch beta feat-c
    run_cmd merged -d "$WS"
    assert_status 0
    assert_contains "Target directory: $WS"
    assert_contains "Branches: local and remote"
    refute_contains "Working directory"
    assert_line_is "alpha"
    assert_line_is "  local"
    assert_line_is "    - feat-a"
    assert_line_is "    - feat-b"
    assert_line_is "  remote"
    assert_line_is "    - origin/feat-a"
    assert_line_is "beta"
    assert_line_is "    - origin/feat-c"
    refute_line_is "gamma"
    refute_contains "local:"
    assert_contains "Summary: 2 done, 0 failed, 1 skipped"
}

@test "merged: a squash-merged branch is listed, an unmerged one is not" {
    branch_with_commit alpha squashed
    branch_with_commit alpha unmerged
    squash_merge_on_origin alpha squashed
    run_cmd merged -d "$WS"
    assert_status 0
    assert_line_is "    - squashed"
    assert_line_is "    - origin/squashed"
    refute_contains "unmerged"
}

@test "merged: the default branch and origin's HEAD branch are never listed" {
    g alpha remote set-head origin main > /dev/null
    run_cmd merged -d "$WS"
    assert_status 0
    refute_contains "main"
    assert_contains "No merged branches found"
    assert_contains "Summary: 0 done, 0 failed, 3 skipped"
}

@test "merged: a custom DEFAULT_BRANCH is respected" {
    g alpha branch -q trunk
    g alpha push -q origin trunk 2> /dev/null
    write_env "" "skipme" "trunk"
    add_local_branch alpha feat
    run_cmd merged -d "$WS"
    assert_line_is "    - feat"
    refute_line_is "    - trunk"
}

@test "merged -l: only local branches" {
    add_remote_branch alpha feat
    remote_only_branch beta other
    run_cmd merged -l -d "$WS"
    assert_status 0
    assert_contains "Branches: local"
    assert_line_is "  local"
    assert_line_is "    - feat"
    refute_line_is "  remote"
    refute_line_is "beta"
}

@test "merged -r: only remote branches" {
    add_remote_branch alpha feat
    remote_only_branch beta other
    run_cmd merged --remote -d "$WS"
    assert_status 0
    assert_contains "Branches: remote"
    assert_line_is "    - origin/feat"
    assert_line_is "    - origin/other"
    refute_line_is "  local"
}

@test "merged -l -r: both, same as the default" {
    add_remote_branch alpha feat
    run_cmd merged -l -r -d "$WS"
    assert_contains "Branches: local and remote"
    assert_line_is "  local"
    assert_line_is "    - feat"
    assert_line_is "  remote"
    assert_line_is "    - origin/feat"
}

@test "merged -m: limits the run to the named repositories" {
    add_local_branch alpha feat
    add_local_branch beta feat
    add_local_branch gamma feat
    run_cmd merged -d "$WS" -m beta
    assert_status 0
    assert_contains "Repositories: beta"
    assert_line_is "beta"
    refute_line_is "alpha"
    refute_line_is "gamma"
    assert_contains "Summary: 1 done, 0 failed, 0 skipped"
}

@test "merged -m: comma lists, space lists and repeated flags combine" {
    add_local_branch alpha feat
    add_local_branch beta feat
    add_local_branch gamma feat
    run_cmd merged -d "$WS" -m alpha,beta
    assert_line_is "alpha"
    assert_line_is "beta"
    refute_line_is "gamma"
    run_cmd merged -d "$WS" -m "alpha gamma"
    assert_line_is "gamma"
    refute_line_is "beta"
    run_cmd merged -d "$WS" -m alpha --repo=gamma
    assert_contains "Repositories: alpha gamma"
    assert_line_is "alpha"
    assert_line_is "gamma"
    refute_line_is "beta"
}

@test "merged -m: an unknown repository is a usage error" {
    run_cmd merged -d "$WS" -m alpha,nope
    assert_status 2
    assert_contains "unknown repository 'nope'"
    assert_contains "Usage: jef merged"
}

@test "merged -m: a repository in SKIP_DIRS or a plain directory is a usage error" {
    run_cmd merged -d "$WS" -m skipme
    assert_status 2
    assert_contains "unknown repository 'skipme'"
    run_cmd merged -d "$WS" -m plain
    assert_status 2
    assert_contains "unknown repository 'plain'"
}

@test "merged: the checked-out branch is listed as kept and never deleted" {
    add_local_branch alpha feat
    g alpha checkout -q feat
    run_cmd merged -d "$WS"
    assert_line_is "    - feat (checked out, kept)"
    run_cmd merged -D -y -d "$WS"
    assert_status 0
    [[ "${output#*Deleted merged branches:}" == *"      - feat (checked out, kept)"* ]]
    [ "$(current_branch alpha)" = feat ]
    g alpha show-ref --quiet --heads feat
}

@test "merged -D -y: deletes merged local and remote branches, keeps unmerged ones" {
    add_remote_branch alpha feat
    remote_only_branch beta other
    branch_with_commit gamma unmerged
    run_cmd merged -D -y -d "$WS"
    assert_status 0
    assert_contains "Will delete these merged branches:"
    assert_line_is "  alpha"
    assert_line_is "      - feat"
    assert_line_is "      - origin/feat"
    assert_line_is "    local"
    assert_line_is "    remote"
    assert_contains "Deleted merged branches:"
    deleted_part="${output#*Deleted merged branches:}"
    expected=$'\n  alpha\n    local\n      - feat\n    remote\n      - origin/feat\n\n  beta\n    remote\n      - origin/other\n'
    [[ "$deleted_part" == "$expected"* ]] || { echo "got: $deleted_part"; return 1; }
    refute_contains "Deleted local branch"
    refute_contains "Working directory"
    assert_contains "Summary: 2 done, 0 failed, 1 skipped"
    refute g alpha show-ref --quiet --heads feat
    refute origin_has_branch alpha feat
    refute origin_has_branch beta other
    g gamma show-ref --quiet --heads unmerged
    origin_has_branch gamma unmerged
    origin_has_branch alpha main
}

@test "merged -D -y: deletes several remote branches of one repository in one push" {
    remote_only_branch alpha one
    remote_only_branch alpha two
    run_cmd merged -D -y -r -d "$WS"
    assert_status 0
    refute origin_has_branch alpha one
    refute origin_has_branch alpha two
}

@test "merged -D -l -y: leaves remote branches alone" {
    add_remote_branch alpha feat
    run_cmd merged -D -l -y -d "$WS"
    assert_status 0
    refute g alpha show-ref --quiet --heads feat
    origin_has_branch alpha feat
}

@test "merged -D: answering n aborts with exit 1 and deletes nothing" {
    add_remote_branch alpha feat
    add_local_branch beta feat
    local before after
    before=$(refs_snapshot)
    merged_tty n -D -d "$WS"
    assert_status 1
    assert_contains "Delete 3 branches in 2 repositories? [y/N]"
    assert_contains "Aborted. Nothing was deleted."
    after=$(refs_snapshot)
    [ "$before" = "$after" ]
}

@test "merged -D: answering y deletes" {
    add_local_branch alpha feat
    merged_tty y -D -d "$WS"
    assert_status 0
    assert_contains "Delete 1 branch in 1 repository? [y/N]"
    refute g alpha show-ref --quiet --heads feat
}

@test "merged -D: no terminal and no --yes exits 2 and deletes nothing" {
    add_remote_branch alpha feat
    local before after
    before=$(refs_snapshot)
    run_cmd merged -D -d "$WS"
    assert_status 2
    assert_contains "Will delete these merged branches:"
    assert_contains "Not running in a terminal. Re-run with --yes to delete. Nothing was deleted."
    after=$(refs_snapshot)
    [ "$before" = "$after" ]
}

@test "merged -D: nothing to delete means no prompt" {
    run_cmd merged -D -d "$WS"
    assert_status 0
    assert_contains "No merged branches found"
    refute_contains "[y/N]"
}

@test "merged -D -n: prints what would be deleted and changes nothing, even with -y" {
    add_remote_branch alpha feat
    add_local_branch beta feat
    local before after
    before=$(refs_snapshot)
    run_cmd merged -D -n -y -d "$WS"
    assert_status 0
    assert_contains "Dry run: true"
    assert_contains "Would delete these merged branches:"
    assert_line_is "  alpha"
    assert_line_is "    local"
    assert_line_is "      - feat"
    assert_line_is "    remote"
    assert_line_is "      - origin/feat"
    refute_contains "Would delete local branch"
    refute_contains "Working directory"
    refute_contains "[y/N]"
    assert_contains "Summary: 2 done, 0 failed, 1 skipped"
    after=$(refs_snapshot)
    [ "$before" = "$after" ]
}

@test "merged -D -n: needs no terminal" {
    add_local_branch alpha feat
    run_cmd merged -D -n -d "$WS"
    assert_status 0
    assert_line_is "      - feat"
}

@test "merged: a failed fetch marks the repository failed but local branches are still listed" {
    add_local_branch alpha feat
    add_remote_branch alpha fed
    g alpha remote set-url origin "$T/does-not-exist.git"
    run_cmd merged -d "$WS"
    assert_status 3
    assert_line_is "  Could not fetch origin in alpha"
    assert_line_is "    - feat"
    assert_line_is "    - fed"
    refute_line_is "  remote"
    assert_contains "1 failed"
}

@test "merged: always fetches first, so a branch merged on origin is found" {
    branch_with_commit alpha late
    git -C "$ORIGINS/alpha.git" update-ref refs/heads/main "$(g alpha rev-parse late)"
    run_cmd merged -d "$WS"
    assert_line_is "    - late"
    assert_line_is "    - origin/late"
}

@test "merged: falls back to the local default branch when origin has none" {
    add_local_branch alpha feat
    g alpha remote set-url origin "$T/does-not-exist.git"
    g alpha update-ref -d refs/remotes/origin/main
    run_cmd merged -d "$WS"
    assert_line_is "    - feat"
}

@test "merged: a repository without the default branch is skipped with a message" {
    write_env "" "skipme" "nosuchbranch"
    run_cmd merged -d "$WS"
    assert_status 0
    assert_line_is "alpha"
    assert_line_is "  Neither origin/nosuchbranch nor nosuchbranch exists in alpha. skipping..."
    assert_contains "Summary: 0 done, 0 failed, 3 skipped"
}

@test "merged: git older than 2.38 prints a notice once and uses the ancestor test only" {
    mkdir -p "$T/oldgit"
    cat > "$T/oldgit/git" <<'EOF'
#!/bin/bash
if [ "$1" = "--version" ]; then
    echo "git version 2.30.1"
    exit 0
fi
exec "$JEF_REAL_GIT" "$@"
EOF
    chmod +x "$T/oldgit/git"
    export JEF_REAL_GIT
    JEF_REAL_GIT="$(command -v git)"
    export PATH="$T/oldgit:$PATH"
    branch_with_commit alpha squashed
    branch_with_commit beta merged-normally
    g beta merge -q merged-normally
    g beta push -q origin main 2> /dev/null
    squash_merge_on_origin alpha squashed
    run_cmd merged -d "$WS"
    assert_status 0
    assert_contains "older than 2.38"
    refute_contains "squashed"
    assert_contains "merged-normally"
    local count
    count=$(printf '%s\n' "$output" | grep -c "older than 2.38")
    [ "$count" -eq 1 ]
}

@test "merged: no escape codes when piped, coloured on a terminal unless NO_COLOR is set" {
    add_local_branch alpha feat
    TERM=xterm-256color run_cmd merged -d "$WS"
    refute_contains $'\033'
    TERM=xterm-256color merged_tty n -D -d "$WS"
    assert_contains $'\033['
    NO_COLOR=1 TERM=xterm-256color merged_tty n -D -d "$WS"
    refute_contains $'\033'
}

@test "merged: -c clears the proxy variables" {
    run_cmd merged -c -d "$WS"
    assert_contains "Clear proxy: true"
    assert_contains "Cleared proxy"
}

@test "merged: --help documents the flags" {
    run_cmd merged --help
    assert_status 0
    assert_contains "Usage: jef merged [options]"
    assert_contains "-l, --local"
    assert_contains "-r, --remote"
    assert_contains "-m, --repo REPOS"
    assert_contains "-D, --delete"
    assert_contains "-n, --dry-run"
    assert_contains "-y, --yes"
    assert_contains "-c, --clear-proxy"
}

@test "merged: takes no positional arguments" {
    run_cmd merged -d "$WS" extra
    assert_status 2
    assert_contains "0 arguments required. 1 provided"
}

@test "merged -D -y: branches that could not be deleted are marked in the list" {
    add_remote_branch alpha feat
    printf '#!/bin/sh\nexit 1\n' > "$ORIGINS/alpha.git/hooks/pre-receive"
    chmod +x "$ORIGINS/alpha.git/hooks/pre-receive"
    run_cmd merged -D -y -d "$WS"
    assert_status 3
    deleted_part="${output#*Deleted merged branches:}"
    [[ "$deleted_part" == *"      - feat"$'\n'* ]]
    [[ "$deleted_part" == *"      - origin/feat (could not delete)"* ]]
    assert_contains "Summary: 0 done, 1 failed"
    refute g alpha show-ref --quiet --heads feat
    origin_has_branch alpha feat
}
