## Context

See proposal.md. Commands are standalone bash scripts that share small helpers in `lib/`. They must run on bash 3.2 (macOS) and Linux, so no bash 4 features and no GNU-only flags. The bats suite from `quality-gates` pins behaviour; `tests/known_issues.bats` holds the desired-behaviour tests for these bugs.

## Goals / Non-Goals

**Goals:**
- Correct handling of spaces and special characters in paths and branch names.
- Meaningful exit statuses for scripting.
- `.env` read as data.

**Non-Goals:**
- Refactoring option parsing into a shared library; changing output.

## Decisions

- **Glob iteration** (`for d in "$target"/*/; do [ -d "$d" ] || continue`) instead of `ls`: handles spaces and an empty target (the unmatched pattern is skipped by the `-d` check). No `nullglob` needed, which keeps bash 3.2 compatibility.
- **`is_git_repo` uses `[ -e "$dir/.git" ]`**: linked worktrees and submodules have a `.git` file. All commands call the helper rather than testing inline.
- **Exact local-branch check**: `git show-ref --verify --quiet "refs/heads/$b"` (the old `--heads $b` matched by suffix pattern). Alternative considered: `git rev-parse --verify`, rejected because it also resolves tags and abbreviations.
- **Dash-prefixed branch names**: git cannot create such branches, and `--` is not accepted by every subcommand used (`ls-remote`, `push`). So `is_valid_branch_name` rejects them up front (exit 2); `--` is added where git accepts it (`checkout <b> --`, `branch -D --`).
- **Exit codes**: 2 for usage errors (arg count, unknown option), 1 for target-directory problems. Matches common CLI convention.
- **`.env` parser**: line loop with `IFS= read -r`, parameter expansion for trimming/quote stripping, `export "$key=$value"` for valid keys only. No `eval`, no `source`. Values override variables already in the environment (same as before, as sourcing did). Values are literal: no `$VAR` or `$(...)` expansion, and no inline `# comment` stripping.
- **shellcheck -S warning**: `.shellcheckrc` disables SC1090/SC1091 (dynamic source paths); SC2154 (colour variables defined in a sourced lib) is disabled per file with a reason.

## Risks / Trade-offs

- [Users relying on shell syntax in `.env` (e.g. `TARGET_DIR=$HOME/code`)] → documented in README as a behaviour change; `~` and `$HOME` are not expanded, so use absolute paths (README already says absolute).
- [Worktrees now included in every command, which may surprise] → intended; documented.
