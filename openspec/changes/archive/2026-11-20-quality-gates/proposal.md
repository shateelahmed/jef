# Proposal

## Why

jef has no automated checks: no tests, no linting, no CI. The next change (`harden-repo-iteration`) fixes known bugs (paths with spaces, exit codes, worktrees/submodules), which is risky without a safety net that pins the current behaviour. The `.gitignore` rule `**/*test*` also prevents test files from being committed at all.

## What Changes

- Replace the `**/*test*` rule in `.gitignore` so only `.env` is ignored.
- Add a bats-core test suite in `tests/` covering every command and the dispatcher against throwaway local git repositories (offline, bare "origin" per repo). Known-broken behaviours get tests for the *desired* behaviour, marked `skip "fixed in harden-repo-iteration"`.
- Add `scripts/check.sh`: `bash -n` on all shell files, `shellcheck -S error`, and the bats suite.
- Add a GitHub Actions workflow running `scripts/check.sh` on ubuntu-latest and macos-latest (macOS tests run under `/bin/bash` 3.2).
- Document the checks in `AGENTS.md` and a new "Development" section in `README.md`.

## Capabilities

### New Capabilities

None. This is tooling only; no spec-level behaviour changes (`skip_specs: true`).

### Modified Capabilities

None.

## Impact

- Commands affected: none changed; all of checkout, delete, fetch, find, merge, pull, push, which and the `jef` dispatcher are covered by tests.
- New files: `tests/`, `scripts/check.sh`, `.github/workflows/ci.yml`. Edited: `.gitignore`, `AGENTS.md`, `README.md`, `openspec/config.yaml` (stale gitignore note).
- Dev prerequisites: bats-core and shellcheck (not needed at runtime).
- Out of scope: fixing any bug in the scripts, raising shellcheck severity (done in `harden-repo-iteration`), Windows.
