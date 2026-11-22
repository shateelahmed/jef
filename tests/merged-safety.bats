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


# write_protected <value>: PROTECTED_BRANCHES for the copy's .env.
write_protected() {
    printf 'PROTECTED_BRANCHES="%s"\n' "$1" >> "$JEF_HOME/.env"
}

# race_git <subcommand> <git-dir> <branch>: put a git wrapper first on PATH that, the first time
# git is called as "git -C <dir> <subcommand> ...", adds a commit to <branch> in <git-dir> (an
# origin, or a clone's .git), then runs the real git. That simulates somebody moving the branch
# between jef's scan and its deletion.
race_git() {
    export JEF_REAL_GIT RACE_SUBCOMMAND="$1" RACE_GIT_DIR="$2" RACE_BRANCH="$3" RACE_DONE="$T/race.done"
    JEF_REAL_GIT="$(command -v git)"
    mkdir -p "$T/race"
    cat > "$T/race/git" <<'EOF'
#!/bin/bash
if [ "$1" = "-C" ] && [ "$3" = "$RACE_SUBCOMMAND" ] && [ ! -e "$RACE_DONE" ]; then
    touch "$RACE_DONE"
    old=$("$JEF_REAL_GIT" --git-dir="$RACE_GIT_DIR" rev-parse "refs/heads/$RACE_BRANCH")
    tree=$("$JEF_REAL_GIT" --git-dir="$RACE_GIT_DIR" rev-parse "$old^{tree}")
    new=$("$JEF_REAL_GIT" --git-dir="$RACE_GIT_DIR" commit-tree "$tree" -p "$old" -m race)
    "$JEF_REAL_GIT" --git-dir="$RACE_GIT_DIR" update-ref "refs/heads/$RACE_BRANCH" "$new"
fi
exec "$JEF_REAL_GIT" "$@"
EOF
    chmod +x "$T/race/git"
    export PATH="$T/race:$PATH"
}

@test "merged: PROTECTED_BRANCHES names and glob patterns are never listed or deleted, locally and on origin" {
    merged_remote_branch alpha dev
    merged_remote_branch alpha qa
    merged_remote_branch alpha release/1.0
    merged_remote_branch alpha release/2.0
    merged_remote_branch alpha feat
    write_protected " dev ,, release/* ,"
    run_cmd merged -d "$WS"
    assert_status 0
    assert_contains "Protected: dev, release/*"
    assert_line_is "    - qa"
    assert_line_is "    - origin/feat"
    refute_contains "- dev"
    refute_contains "origin/dev"
    refute_contains "release/1"
    refute_contains "release/2"
    run_cmd merged -D -y -d "$WS"
    assert_status 0
    refute g alpha show-ref --quiet --heads feat
    refute origin_has_branch alpha qa
    g alpha show-ref --quiet --heads dev
    origin_has_branch alpha dev
    g alpha show-ref --quiet --heads release/1.0
    origin_has_branch alpha release/2.0
}

@test "merged: a PROTECTED_BRANCHES entry containing spaces exits 2 and changes nothing" {
    merged_remote_branch alpha dev
    merged_remote_branch alpha qa
    write_protected "dev qa"
    run_cmd merged -D -y -d "$WS"
    assert_status 2
    assert_contains "Invalid PROTECTED_BRANCHES: 'dev qa' contains spaces; separate entries with commas"
    g alpha show-ref --quiet --heads dev
    g alpha show-ref --quiet --heads qa
    origin_has_branch alpha dev
    origin_has_branch alpha qa
}

@test "merged: --help still works with an invalid PROTECTED_BRANCHES" {
    write_protected "dev qa"
    run_cmd merged --help
    assert_status 0
}

@test "merged: without PROTECTED_BRANCHES only the default branch is protected" {
    merged_remote_branch alpha dev
    run_cmd merged -d "$WS"
    assert_contains "Protected: default branch only"
    assert_line_is "    - dev"
}

@test "merged: a protected pattern is not expanded against files in the current directory" {
    merged_remote_branch alpha qa-two
    write_protected "qa*"
    local dir="$T/cwd"
    mkdir -p "$dir"
    : > "$dir/qa-file"
    cd "$dir"
    run_cmd merged -d "$WS"
    assert_status 0
    refute_contains "qa-two"
    assert_contains "Protected: qa*"
}

@test "merged -D: a remote branch pushed to after the scan is kept, the others are deleted" {
    merged_remote_only_branch alpha moved
    merged_remote_only_branch alpha still
    race_git push "$ORIGINS/alpha.git" moved
    run_cmd merged -D -y -d "$WS"
    assert_status 0
    deleted_part="${output#*Deleted merged branches:}"
    [[ "$deleted_part" == *"      - origin/moved (changed since scan, kept)"* ]] || { echo "$output"; return 1; }
    [[ "$deleted_part" == *"      - origin/still"$'\n'* ]]
    origin_has_branch alpha moved
    refute origin_has_branch alpha still
    assert_contains "Summary: 1 done, 0 failed, 2 skipped"
}

@test "merged -D: answering y at the prompt keeps a branch somebody pushed to meanwhile" {
    merged_remote_only_branch alpha moved
    race_git push "$ORIGINS/alpha.git" moved
    merged_tty y -D -d "$WS"
    assert_status 0
    assert_contains "(changed since scan, kept)"
    refute_contains "could not delete"
    origin_has_branch alpha moved
}

@test "merged -D: a local branch moved after the scan is kept" {
    merged_local_branch alpha moved
    merged_local_branch alpha still
    local before
    before=$(g alpha rev-parse moved)
    race_git update-ref "$WS/alpha/.git" moved
    run_cmd merged -D -y -d "$WS"
    assert_status 0
    deleted_part="${output#*Deleted merged branches:}"
    [[ "$deleted_part" == *"      - moved (changed since scan, kept)"* ]] || { echo "$output"; return 1; }
    g alpha show-ref --quiet --heads moved
    [ "$(g alpha rev-parse moved)" != "$before" ]
    refute g alpha show-ref --quiet --heads still
}

@test "merged -D: a rejected remote deletion is still marked could not delete, per branch" {
    merged_remote_only_branch alpha one
    printf '#!/bin/sh\nexit 1\n' > "$ORIGINS/alpha.git/hooks/pre-receive"
    chmod +x "$ORIGINS/alpha.git/hooks/pre-receive"
    run_cmd merged -D -y -d "$WS"
    assert_status 3
    assert_contains "      - origin/one (could not delete)"
    refute_contains "changed since scan"
    origin_has_branch alpha one
}

@test "merged -D: a branch checked out in another worktree is kept" {
    merged_local_branch alpha feat
    merged_local_branch alpha other
    g alpha worktree add -q "$T/wt-feat" feat
    run_cmd merged -d "$WS"
    assert_line_is "    - feat (checked out, kept)"
    run_cmd merged -D -y -d "$WS"
    assert_status 0
    [[ "${output#*Deleted merged branches:}" == *"      - feat (checked out, kept)"* ]]
    g alpha show-ref --quiet --heads feat
    refute g alpha show-ref --quiet --heads other
}

@test "merged: a branch without commits of its own is listed as kept and not deleted" {
    g alpha branch empty
    g alpha push -q origin empty 2> /dev/null
    merged_local_branch alpha real
    run_cmd merged -d "$WS"
    assert_line_is "    - empty (no commits, kept)"
    assert_line_is "    - origin/empty (no commits, kept)"
    assert_line_is "    - real"
    run_cmd merged -D -n -d "$WS"
    assert_line_is "      - empty (no commits, kept)"
    assert_line_is "      - origin/empty (no commits, kept)"
    run_cmd merged -D -y -d "$WS"
    assert_status 0
    [[ "${output#*Deleted merged branches:}" == *"      - empty (no commits, kept)"* ]]
    g alpha show-ref --quiet --heads empty
    origin_has_branch alpha empty
    refute g alpha show-ref --quiet --heads real
}

@test "merged -D: the confirmation count excludes kept branches" {
    g alpha branch empty
    merged_local_branch alpha real
    merged_tty n -D -d "$WS"
    assert_status 1
    assert_contains "Delete 1 branch in 1 repository? [y/N]"
}

@test "merged -D: only kept branches means no question and nothing deleted" {
    g alpha branch empty
    run_cmd merged -D -d "$WS"
    assert_status 0
    refute_contains "[y/N]"
    assert_line_is "      - empty (no commits, kept)"
    g alpha show-ref --quiet --heads empty
}

@test "merged -D --include-empty: deletes branches without commits as well" {
    g alpha branch empty
    g alpha push -q origin empty 2> /dev/null
    run_cmd merged -D -y --include-empty -d "$WS"
    assert_status 0
    refute_contains "no commits"
    refute g alpha show-ref --quiet --heads empty
    refute origin_has_branch alpha empty
}

@test "merged: a squash-merged branch is never treated as empty" {
    branch_with_commit alpha squashed
    squash_merge_on_origin alpha squashed
    run_cmd merged -d "$WS"
    assert_line_is "    - squashed"
    assert_line_is "    - origin/squashed"
    refute_contains "no commits"
    run_cmd merged -D -y -d "$WS"
    assert_status 0
    refute g alpha show-ref --quiet --heads squashed
    refute origin_has_branch alpha squashed
}

@test "merged: a branch fast-forward merged into main counts as empty and is kept" {
    branch_with_commit alpha ff
    g alpha merge -q --ff-only ff
    g alpha push -q origin main 2> /dev/null
    run_cmd merged -d "$WS"
    assert_line_is "    - ff (no commits, kept)"
}
