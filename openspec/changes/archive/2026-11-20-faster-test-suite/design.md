## Context

See proposal.md - Why. `setup_workspace` builds 4 bare origins, clones, commits and pushes for every test; copying a ready-made workspace is about 5x cheaper. Test files are already isolated (per-test temp dir and `HOME`), so they can run concurrently.

## Goals / Non-Goals

**Goals:** about 200 s to about 20-30 s for the full suite; no test isolation loss; works on bash 3.2 / BSD tools and Linux without new dependencies.

**Non-Goals:** changing what is tested for jef behaviour; rewriting jef.

## Decisions

- **Template per file.** `build_fixture_template` (called from each file's `setup_file`) builds the fixture into `$BATS_FILE_TMPDIR/template`. `setup_workspace` copies `ws/`, `origins/` and `jef/` with `cp -R`, so each test owns its origins. Alternative considered: a single template shared across files; rejected because it needs cross-process locking and bats has no global setup hook per run.
- **Repoint absolute paths after copy.** Git stores the remote URL as an absolute path, so every first-level repo gets `git remote set-url origin "$ORIGINS/<name>.git"`. The template contains no worktrees or submodules (tests create those per test, after the copy), `.env` is rewritten by `write_env` for each test, `.gitconfig` is written fresh, and the git spies are created per test under `$T`. Alternative: relative remote URLs; rejected as less explicit.
- **Fallback.** If no template exists, `setup_workspace` calls `build_workspace_from_scratch` (the old full build), which files with non-standard needs may also call directly.
- **Parallel runner.** `xargs -P <ncpu>` over the bats files, one `bats` per file writing to a temp file; outputs are printed in file order. CPU count from `getconf _NPROCESSORS_ONLN`, then `sysctl -n hw.ncpu`, fallback 4. Exit is non-zero if any file failed.
- **Modes.** `--quick [files]` runs `bash -n`, shellcheck and the given files (default: all) under the default bash. `--both` runs the full suite under `bash` and `/bin/bash` concurrently.

## Risks / Trade-offs

- [Concurrent files colliding on process names] -> unique `sleep 37.<pid>` marker in the interrupt test.
- [Copied clone pushing to the template's origins] -> set-url fix-up plus a test asserting the template origins are untouched.
- [Resource contention causing timing flakiness] -> concurrency bounded by CPU count; suite run repeatedly to check.
