# Design

## Context

Commands load `<repo>/.env` through `lib/load-env.sh` (allexport), so a developer's real `.env` would override `TARGET_DIR`, `SKIP_DIRS` and `DEFAULT_BRANCH` exported by a test. Commands locate their libs via `BASH_SOURCE/..`. The dispatcher calls `jef-<name>` from `PATH` (the installer strips `.sh`). Existing code has ~94 shellcheck findings below error severity.

## Goals / Non-Goals

**Goals:** hermetic, offline tests that pin current behaviour; one entry point (`scripts/check.sh`) used locally and in CI; tests run on bash 3.2.

**Non-Goals:** fixing script bugs; spec changes.

## Decisions

- **Copy `commands/` and `lib/` into a per-test temp dir** and write that copy's own `.env`. Alternative (exporting env vars) fails because `.env` is sourced after and wins. Also lets the dispatcher test mimic the installer (extension-less copies on `PATH`).
- **Per-repo local bare origin + clone** so push/pull/fetch/delete-remote work offline. Git is isolated via a temp `HOME` with its own `.gitconfig`.
- **`TERM=dumb`** so `tput` yields empty colour codes and output is plain text.
- **`JEF_BASH`** (default `bash`) selects the interpreter running the scripts; CI sets `/bin/bash` on macOS to exercise bash 3.2.
- **Known-broken behaviours** are written as tests of the desired behaviour with `skip "fixed in harden-repo-iteration"`; that change removes the skips.
- **shellcheck at `-S error`** now; `harden-repo-iteration` raises it to `-S warning`.
- No bats-assert dependency; small assertion helpers live in `tests/test_helper.bash` (bash 3.2 does not fail a test on a false `[[ ]]`, so helpers return explicitly).

## Risks / Trade-offs

- Git version differences (`init -b` needs git 2.28+) → fine on current runners.
- Output assertions on table rows depend on glyphs ✔/✘ → asserted loosely (order only), not on widths.
