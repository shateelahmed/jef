## 1. Shared filter
- [x] 1.1 Move the -m filter into lib/repos.sh (validation with usage_error, applied by for_each_repo, list_repos and parallel_run)
- [x] 1.2 Remove the per-command filter copies from merged, sync, status and checkout

## 2. Commands
- [x] 2.1 Declare -m/--repo in every repository command and add "Repositories:" to the banners
- [x] 2.2 checkout: accept -m without -b; migrate: no warning for entries outside the filter

## 3. Tests and docs
- [x] 3.1 Tests: shared filter (cli.bats over every command: --help lists it, unknown name exits 2), one filtered-run test per command, checkout -m without -b, migrate warning, merge branch check
- [x] 3.2 README.md: document -m for every command (options table, a general note) and update the checkout notes
