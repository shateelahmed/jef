#!/bin/bash
# Run every quality gate: syntax check, shellcheck, bats tests.
# Exits non-zero if any gate fails. Compatible with bash 3.2 (macOS).
#
# Usage: scripts/check.sh [--quick] [--both] [tests/file.bats ...]
#   (no options)  full gate: bash -n, shellcheck, every bats file
#   --quick       for the edit loop: same gates, but only the bats files given
#                 (or, with none given, those affected by uncommitted changes:
#                 a changed tests/X.bats or commands/jef-X.sh maps to X.bats;
#                 any other change, or no change, runs all of them)
#   --both        run the bats suite under both "bash" and /bin/bash (the
#                 macOS bash 3.2) concurrently
#
# The bats files run concurrently (xargs -P, one bats process per file); each
# file's output is printed in file order, followed by a total line.
# Set JEF_BASH=/bin/bash to run the tests' scripts under a specific bash.

cd "$(dirname "$0")/.." || exit 1

quick=0
both=0
bats_files=()
while [ $# -gt 0 ]; do
    case "$1" in
    --quick) quick=1 ;;
    --both) both=1 ;;
    -h | --help)
        sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    -*)
        echo "check.sh: unknown option: $1" >&2
        exit 2
        ;;
    *) bats_files+=("$1") ;;
    esac
    shift
done

# affected_bats: bats files affected by uncommitted changes (see --quick).
affected_bats() {
    local path name all=0 out=""
    while IFS= read -r path; do
        case "$path" in
        tests/*.bats) out="$out $path" ;;
        commands/jef-*.sh)
            name="${path#commands/jef-}"
            name="tests/${name%.sh}.bats"
            if [ -f "$name" ]; then out="$out $name"; else all=1; fi
            ;;
        '' | openspec/* | README.md | AGENTS.md | CLAUDE.md | .env.example) ;;
        *) all=1 ;;
        esac
    done < <(git status --porcelain --untracked-files=all 2> /dev/null | sed 's/^...//')
    [ "$all" -eq 0 ] && [ -n "$out" ] && printf '%s\n' $out | sort -u
}

if [ ${#bats_files[@]} -eq 0 ] && [ "$quick" -eq 1 ]; then
    while IFS= read -r f; do
        bats_files+=("$f")
    done < <(affected_bats)
fi
if [ ${#bats_files[@]} -eq 0 ]; then
    for f in tests/*.bats; do
        bats_files+=("$f")
    done
fi

failed=0

# Every shell file we own (skip vendored/agent/tooling directories).
shell_files=()
while IFS= read -r f; do
    shell_files+=("$f")
done < <(find . \( -name .git -o -name .agents -o -name .claude -o -name openspec -o -name node_modules \) -prune \
    -o \( -name '*.sh' -o -name '*.bash' \) -type f -print | sort)

# The two static gates, run in the background alongside the bats suite.
static_bash_n() {
    local f rc=0
    for f in "${shell_files[@]}"; do
        if ! bash -n "$f"; then
            echo "syntax error: $f"
            rc=1
        fi
    done
    return "$rc"
}

static_shellcheck() {
    if command -v shellcheck > /dev/null 2>&1; then
        # Only .sh files: tests/test_helper.bash is a bats helper, not a standalone script.
        local f sh_files=()
        for f in "${shell_files[@]}"; do
            case "$f" in
            *.sh) sh_files+=("$f") ;;
            esac
        done
        shellcheck -s bash -S warning "${sh_files[@]}"
    else
        echo "shellcheck not found (install: brew install shellcheck / apt-get install shellcheck)"
        return 1
    fi
}

tmp="$(mktemp -d "${TMPDIR:-/tmp}/jef-check.XXXXXX")" || exit 1
trap 'rm -rf "$tmp"' EXIT

# Start both static gates in the background; their reports are printed (in the
# same order as before) once they finish, while the bats suite is running.
(static_bash_n > "$tmp/bashn.out" 2>&1; echo $? > "$tmp/bashn.rc") &
pid_n=$!
(static_shellcheck > "$tmp/shellcheck.out" 2>&1; echo $? > "$tmp/shellcheck.rc") &
pid_s=$!

# cpu_count: online CPUs (Linux, then macOS), 4 when unknown.
cpu_count() {
    local n
    n="$(getconf _NPROCESSORS_ONLN 2> /dev/null)" ||
        n="$(sysctl -n hw.ncpu 2> /dev/null)" || n=""
    case "$n" in
    '' | *[!0-9]* | 0) n=4 ;;
    esac
    echo "$n"
}

# run_bats_dir <outdir> <jef-bash>: run every file in bats_files concurrently,
# writing <outdir>/<n>.out (TAP) and <outdir>/<n>.rc, n = position in the list.
run_bats_dir() {
    local outdir="$1" shell="$2" i=0 f
    # Slowest files first (most @test lines, a cheap proxy for run time) so a
    # long file is never started last; the position n keeps the report order.
    for f in "${bats_files[@]}"; do
        printf '%s %s %s\n' "$(grep -c '^@test' "$f" 2> /dev/null)" "$i" "$f"
        i=$((i + 1))
    done | sort -k1,1nr -k2,2n | cut -d' ' -f2,3 | JEF_BASH="$shell" xargs -P "${JEF_CHECK_JOBS:-$(cpu_count)}" -L 1 sh -c \
        'bats "$2" > "$0/$1.out" 2>&1; echo $? > "$0/$1.rc"' "$outdir"
}

# report_bats_dir <outdir> <label>: print the outputs in file order and a
# total line; returns non-zero if any file failed.
report_bats_dir() {
    local outdir="$1" label="$2" i=0 f rc ok=0 notok=0 n bad=0
    for f in "${bats_files[@]}"; do
        echo "--- $f ($label)"
        cat "$outdir/$i.out" 2> /dev/null
        rc="$(cat "$outdir/$i.rc" 2> /dev/null)"
        n="$(grep -c '^ok ' "$outdir/$i.out" 2> /dev/null)"
        ok=$((ok + n))
        n="$(grep -c '^not ok ' "$outdir/$i.out" 2> /dev/null)"
        notok=$((notok + n))
        [ "${rc:-1}" = 0 ] || bad=$((bad + 1))
        i=$((i + 1))
    done
    echo "bats ($label): $ok passed, $notok failed, $bad of ${#bats_files[@]} files failed"
    [ "$bad" -eq 0 ] && [ "$notok" -eq 0 ]
}

bats_ok=0
if command -v bats > /dev/null 2>&1; then
    bats_ok=1
    start=$SECONDS
    if [ "$both" -eq 1 ]; then
        mkdir "$tmp/a" "$tmp/b"
        run_bats_dir "$tmp/a" bash &
        pid_a=$!
        run_bats_dir "$tmp/b" /bin/bash &
        pid_b=$!
        wait "$pid_a"
        wait "$pid_b"
    else
        run_bats_dir "$tmp" "${JEF_BASH:-bash}"
    fi
fi

wait "$pid_n" "$pid_s"
echo "==> bash -n (${#shell_files[@]} files)"
cat "$tmp/bashn.out"
[ "$(cat "$tmp/bashn.rc")" = 0 ] || failed=1
echo "==> shellcheck"
cat "$tmp/shellcheck.out"
[ "$(cat "$tmp/shellcheck.rc")" = 0 ] || failed=1

echo "==> bats"
if [ "$bats_ok" -eq 1 ]; then
    if [ "$both" -eq 1 ]; then
        report_bats_dir "$tmp/a" "bash" || failed=1
        report_bats_dir "$tmp/b" "/bin/bash" || failed=1
    else
        report_bats_dir "$tmp" "${JEF_BASH:-bash}" || failed=1
    fi
    echo "bats finished in $((SECONDS - start)) s"
else
    echo "bats not found (install: brew install bats-core / apt-get install bats)"
    failed=1
fi

if [ "$failed" -ne 0 ]; then
    echo "check.sh: FAILED"
    exit 1
fi
echo "check.sh: all checks passed"
