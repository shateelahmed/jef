## 1. Shared code
- [x] 1.1 Move `rebase_in_progress` to lib/repos.sh; add `parallel_use_repo_list` to `parallel_run`; add `dim` to lib/terminal-color-codes.sh

## 2. Command
- [x] 2.1 Add commands/jef-sync.sh: options (-r, -n, -y, -m, -j, -c), DEFAULT_BRANCH check, -m filter, banner
- [x] 2.2 Plan phase from local refs, plan output, confirmation (always asked) and dry run
- [x] 2.3 Per-repository worker: dirty check, fetch, pull the default branch, per-branch pull / merge or rebase / push, stop and abort on failure, restore the original branch
- [x] 2.4 Result tree from per-repository summary files, then finish_run
- [x] 2.5 List `sync` in commands/jef.sh

## 3. Tests and docs
- [x] 3.1 Add tests/sync.bats (merge, rebase, local-only, conflicts, dirty tree, diverged default, protected, -m, prompt, no terminal, dry run, missing DEFAULT_BRANCH, no default branch, -j, -c)
- [x] 3.3 Rework the output like `jef merged`: bulleted plan tree, quiet run (git output kept, failure lines shown under the branch), result tree with totals; update README (example and colours), spec, design and tests
- [x] 3.2 Update README.md (features, usage, options table, exit codes, summary, dry-run and --yes notes) and .env.example
