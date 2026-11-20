# Tasks

## 1. Shared libraries

- [x] 1.1 Add `lib/cli.sh` (parse_options, print_usage, require_args) and `lib/repos.sh` (for_each_repo, print_repo_header); verify `bash -n` and shellcheck pass
- [x] 1.2 Add `lib/common.sh`; verify it sources every non-side-effect lib

## 2. Commands

- [x] 2.1 Port checkout, delete, fetch, merge, pull, push to the helpers; verify existing bats suites pass unchanged
- [x] 2.2 Port find and which (explicit spinner source); verify existing bats suites pass unchanged
- [x] 2.3 Rewrite `commands/jef.sh` with help, no-command and unknown-command handling; verify manually and via tests

## 3. Tests

- [x] 3.1 Add bats tests for `--help` per command, unknown option (usage, exit 2), unsupported option, and the dispatcher cases; update the old dispatcher "unknown command" test; verify `bats tests` passes
- [x] 3.2 Verify `./scripts/check.sh` passes with bash and with `JEF_BASH=/bin/bash`

## 4. Docs

- [x] 4.1 Update README.md (`jef help`, `jef <command> --help`, command/flag table, development notes); verify the table matches each command's `--help`
- [x] 4.2 Verify `openspec validate shared-command-scaffolding --strict` and `openspec validate --specs --strict` pass
