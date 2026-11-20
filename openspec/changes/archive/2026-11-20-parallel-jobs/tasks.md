## 1. Option parsing

- [x] 1.1 Add cli_value_flags (value-taking flags, posint validation, help line) to lib/cli.sh

## 2. Parallel runner

- [x] 2.1 Add is_target_repo/list_repos and parallel_run/parallel_apply_outcomes to lib/repos.sh
- [x] 2.2 Add -j/--jobs to jef fetch (parallel path, sequential for 1)
- [x] 2.3 Add -j/--jobs to jef find (parallel path, sequential for 1)

## 3. Tests and docs

- [x] 3.1 Add tests/parallel.bats (equal output, invalid values, long form, broken origin, help)
- [x] 3.2 Update README.md (flags table and a line on -j)
- [x] 3.3 Run ./scripts/check.sh with bash and JEF_BASH=/bin/bash; validate OpenSpec
