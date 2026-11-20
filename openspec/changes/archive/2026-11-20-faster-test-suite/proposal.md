## Why

The test suite takes about 200 s for 141 tests, and every change is verified twice (`bash` and `/bin/bash` 3.2), so one verification cycle costs 6-8 minutes. About 60% of the time is `setup_workspace` building the same git fixture (about 1.05 s, 25-30 git processes) before nearly every test, and all test files run serially.

## What Changes

- Build the fixture workspace once per test file and copy it per test (`cp -R`), repointing the clones' origin URLs to the test's own copy of the origins.
- Keep the full build available as `build_workspace_from_scratch` for tests or files that need a non-standard workspace.
- `scripts/check.sh` runs the `.bats` files concurrently with `xargs -P` (no GNU parallel), prints each file's TAP output in file order plus a total line, and gains `--quick [files...]` (no full gate, default bash) and `--both` (runs the suite under `bash` and `/bin/bash` concurrently).
- Make the interrupt test in `tests/parallel.bats` use a per-run unique `sleep` marker so concurrent files cannot confuse it.
- Trim redundant per-command loops in `tests/common.bats` where code is shared (`lib/cli.sh`, `lib/repos.sh`); every trimmed test is listed in the apply report.
- Document the new workflow in AGENTS.md and the README "Development" section.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
None. Tooling only; no jef command behaviour changes (`skip_specs: true`).

## Impact

- Affected jef commands: none. No `commands/`, `lib/` or installer changes.
- Files: `tests/test_helper.bash`, `tests/*.bats`, `scripts/check.sh`, `AGENTS.md`, `README.md`.
- CI keeps running `./scripts/check.sh` unchanged.
- Out of scope: rewriting jef in Rust, changing what jef does, changing CI configuration, new dependencies.
