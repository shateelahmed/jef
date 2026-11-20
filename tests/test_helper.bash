# Shared helpers for the jef bats suites. Works on bash 3.2 (macOS) and newer.
#
# Every test gets a throwaway workspace under $BATS_TEST_TMPDIR:
#   $WS/alpha $WS/beta $WS/gamma   git repos cloned from local bare origins
#   $WS/skipme                     git repo listed in SKIP_DIRS
#   $WS/plain                      directory that is not a git repo
# Each repo's "origin" lives in $ORIGINS/<name>.git, so push/pull/fetch and
# remote branch deletion all work offline.
#
# The commands read <repo>/.env (lib/load-env.sh sources it with allexport),
# which would silently override TARGET_DIR/SKIP_DIRS/DEFAULT_BRANCH exported by
# a test and leak the developer's real settings in. So instead of running the
# commands from the checkout, each test runs a COPY of commands/ and lib/
# ($JEF_HOME) that has its own explicit .env (see write_env).
#
# JEF_BASH selects the interpreter running the scripts (default: bash). CI sets
# it to /bin/bash on macOS to exercise bash 3.2.

JEF_BASH="${JEF_BASH:-bash}"
JEF_REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

# _init_env <root>: point the per-test variables and the isolated git/shell
# environment at <root> (the test's temp dir, or the template being built).
_init_env() {
    T="$1"
    WS="$T/ws"
    ORIGINS="$T/origins"
    JEF_HOME="$T/jef"

    # Isolate git from the developer's configuration.
    export HOME="$T/home"
    mkdir -p "$HOME"
    cat > "$HOME/.gitconfig" <<'EOF'
[user]
    name = Jef Test
    email = jef-test@example.invalid
[init]
    defaultBranch = main
[pull]
    rebase = false
[protocol "file"]
    allow = always
EOF
    export GIT_CONFIG_NOSYSTEM=1

    # tput needs a terminal type; "dumb" yields empty colour codes (plain output).
    export TERM=dumb
    unset TARGET_DIR SKIP_DIRS DEFAULT_BRANCH
    unset HTTPS_PROXY https_proxy HTTP_PROXY http_proxy NO_PROXY no_proxy
}

# _populate_fixture: build the standard workspace under the current $T.
_populate_fixture() {
    mkdir -p "$WS" "$ORIGINS" "$JEF_HOME"
    cp -R "$JEF_REPO_ROOT/commands" "$JEF_REPO_ROOT/lib" "$JEF_HOME/"
    write_env "" "skipme" "main"

    make_repo alpha
    make_repo beta
    make_repo gamma
    make_repo skipme
    mkdir "$WS/plain"
    echo "not a repo" > "$WS/plain/file.txt"
    echo "not a directory" > "$WS/loose-file.txt"
}

# build_workspace_from_scratch: the full (slow, about 1 s) workspace build in
# $BATS_TEST_TMPDIR. For tests that need a non-standard workspace.
build_workspace_from_scratch() {
    _init_env "$BATS_TEST_TMPDIR"
    _populate_fixture
}

# build_fixture_template: call from setup_file. Builds the standard workspace
# once into $BATS_FILE_TMPDIR/template; setup_workspace copies it per test.
# The template has no worktrees or submodules and no path baked in apart from
# the clones' origin URLs (repointed by setup_workspace).
build_fixture_template() {
    local saved_home="$HOME"
    _init_env "$BATS_FILE_TMPDIR/template"
    _populate_fixture
    export HOME="$saved_home"
}

# setup_workspace: a fresh, private copy of the fixture in $BATS_TEST_TMPDIR.
# Copies the per-file template and repoints every absolute path baked into it,
# so a test can never touch the template or another test's origins. Falls back
# to the full build when the file did not call build_fixture_template.
setup_workspace() {
    local template="$BATS_FILE_TMPDIR/template" d name
    if [ ! -d "$template/ws" ]; then
        build_workspace_from_scratch
        return
    fi
    _init_env "$BATS_TEST_TMPDIR"
    cp -R "$template/ws" "$template/origins" "$template/jef" "$T/"
    # Git stores the remote as an absolute path: point each clone at this
    # test's own copy of the origins. (.env holds no path: write_env rewrites
    # it; the gitconfig and any spies are created per test.)
    # Rewritten in pure bash: no git process per repo.
    for d in "$WS"/*/; do
        name="${d%/}"
        name="${name##*/}"
        if [ -d "$d/.git" ] && [ -d "$ORIGINS/$name.git" ]; then
            _repoint_origin "$d/.git/config" "$ORIGINS/$name.git"
        fi
    done
}

# _repoint_origin <config-file> <url>: set the url of remote "origin" (the
# template's clones have exactly one remote, with a single "url =" line).
_repoint_origin() {
    local line
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
        *"url = "*) printf '\turl = %s\n' "$2" ;;
        *) printf '%s\n' "$line" ;;
        esac
    done < "$1" > "$1.new" && mv "$1.new" "$1"
}

# write_env <TARGET_DIR> <SKIP_DIRS> <DEFAULT_BRANCH>: the copy's .env.
write_env() {
    {
        echo "TARGET_DIR=\"$1\""
        echo "SKIP_DIRS=\"$2\""
        echo "DEFAULT_BRANCH=\"$3\""
    } > "$JEF_HOME/.env"
}

# setup_dispatcher: mimic install.sh (extension-less copies on PATH).
setup_dispatcher() {
    local f
    for f in "$JEF_HOME"/commands/jef*.sh; do
        cp "$f" "${f%.sh}"
    done
    export PATH="$JEF_HOME/commands:$PATH"
}

# make_repo <name> [parent-dir]: bare origin + clone with one commit on main.
make_repo() {
    local name="$1" dir="${2:-$WS}"
    # An empty template skips the ~14 sample hooks per repo: far fewer files to
    # create now and to copy per test.
    git init -q --template= --bare -b main "$ORIGINS/$name.git"
    mkdir -p "$ORIGINS/$name.git/hooks" # tests install hooks here
    git clone -q --template= "$ORIGINS/$name.git" "$dir/$name" 2> /dev/null
    git -C "$dir/$name" symbolic-ref HEAD refs/heads/main
    echo "$name" > "$dir/$name/file.txt"
    git -C "$dir/$name" add file.txt
    git -C "$dir/$name" commit -q -m "init"
    git -C "$dir/$name" push -q -u origin main 2> /dev/null
}

# g <repo> <git args...>: run git in $WS/<repo>.
g() {
    local repo="$1"
    shift
    git -C "$WS/$repo" "$@"
}

current_branch() { g "$1" branch --show-current; }

# add_local_branch <repo> <branch>: create a local branch (no checkout).
add_local_branch() { g "$1" branch "$2"; }

# commit_on <repo> <file>: add a commit to the repo's current branch.
commit_on() {
    echo "$2 $RANDOM" > "$WS/$1/$2"
    g "$1" add "$2"
    g "$1" commit -q -m "add $2"
}

# add_remote_branch <repo> <branch>: create + push a branch, keep it locally.
add_remote_branch() {
    g "$1" branch "$2"
    g "$1" push -q origin "$2" 2> /dev/null
}

# remote_only_branch <repo> <branch>: branch exists on origin but not locally.
remote_only_branch() {
    add_remote_branch "$1" "$2"
    g "$1" branch -q -D "$2"
}

# origin_has_branch <repo> <branch>
origin_has_branch() {
    git --git-dir="$ORIGINS/$1.git" show-ref --verify --quiet "refs/heads/$2"
}

# remote_commit <repo> <branch> <file>: someone else pushes a commit to origin.
remote_commit() {
    local other="$T/other-$1"
    [ -d "$other" ] || git clone -q "$ORIGINS/$1.git" "$other" 2> /dev/null
    git -C "$other" fetch -q origin
    if git -C "$other" show-ref --verify --quiet "refs/remotes/origin/$2"; then
        git -C "$other" checkout -q -B "$2" "origin/$2"
    else
        git -C "$other" checkout -q -B "$2"
    fi
    echo "$3 $RANDOM" > "$other/$3"
    git -C "$other" add "$3"
    git -C "$other" commit -q -m "remote $3"
    git -C "$other" push -q origin "$2" 2> /dev/null
}

# run_cmd <command> [args...]: run commands/jef-<command>.sh under $JEF_BASH.
run_cmd() {
    local cmd="$1"
    shift
    run "$JEF_BASH" "$JEF_HOME/commands/jef-$cmd.sh" "$@"
}

# setup_git_spy: put a git wrapper first on PATH that logs proxy variables.
setup_git_spy() {
    export JEF_SPY_LOG="$T/git-spy.log"
    export JEF_REAL_GIT
    JEF_REAL_GIT="$(command -v git)"
    mkdir -p "$T/spy"
    cat > "$T/spy/git" <<'EOF'
#!/bin/bash
echo "HTTPS_PROXY=${HTTPS_PROXY-unset} http_proxy=${http_proxy-unset}" >> "$JEF_SPY_LOG"
exec "$JEF_REAL_GIT" "$@"
EOF
    chmod +x "$T/spy/git"
    export PATH="$T/spy:$PATH"
}

# Assertions. Plain [[ ]] failures are not caught by bash 3.2 under set -e, so
# these return explicitly.
assert_status() {
    [ "$status" -eq "$1" ] || {
        echo "expected exit status $1, got $status"
        echo "$output"
        return 1
    }
}

assert_contains() {
    case "$output" in
    *"$1"*) return 0 ;;
    esac
    echo "expected output to contain: $1"
    echo "--- output ---"
    echo "$output"
    return 1
}

refute_contains() {
    case "$output" in
    *"$1"*)
        echo "expected output NOT to contain: $1"
        echo "--- output ---"
        echo "$output"
        return 1
        ;;
    esac
    return 0
}

# refute <command...>: succeeds when the command fails (a bare "!" is not caught
# by set -e).
refute() {
    if "$@"; then
        echo "unexpected success: $*"
        return 1
    fi
    return 0
}

# table_row <name>: the table row starting with "| <name> ".
table_row() {
    printf '%s\n' "$output" | grep "^| $1 " || true
}
