#!/bin/bash
# Run every quality gate: syntax check, shellcheck, bats tests.
# Exits non-zero if any gate fails. Compatible with bash 3.2 (macOS).
#
# Set JEF_BASH=/bin/bash to run the tests' scripts under a specific bash.

cd "$(dirname "$0")/.." || exit 1

failed=0

# Every shell file we own (skip vendored/agent/tooling directories).
shell_files=()
while IFS= read -r f; do
    shell_files+=("$f")
done < <(find . \( -name .git -o -name .agents -o -name .claude -o -name openspec -o -name node_modules \) -prune \
    -o \( -name '*.sh' -o -name '*.bash' \) -type f -print | sort)

echo "==> bash -n (${#shell_files[@]} files)"
for f in "${shell_files[@]}"; do
    if ! bash -n "$f"; then
        echo "syntax error: $f"
        failed=1
    fi
done

echo "==> shellcheck"
if command -v shellcheck > /dev/null 2>&1; then
    # Only .sh files: tests/test_helper.bash is a bats helper, not a standalone script.
    sh_files=()
    for f in "${shell_files[@]}"; do
        case "$f" in
        *.sh) sh_files+=("$f") ;;
        esac
    done
    shellcheck -s bash -S warning "${sh_files[@]}" || failed=1
else
    echo "shellcheck not found (install: brew install shellcheck / apt-get install shellcheck)"
    failed=1
fi

echo "==> bats"
if command -v bats > /dev/null 2>&1; then
    bats tests || failed=1
else
    echo "bats not found (install: brew install bats-core / apt-get install bats)"
    failed=1
fi

if [ "$failed" -ne 0 ]; then
    echo "check.sh: FAILED"
    exit 1
fi
echo "check.sh: all checks passed"
