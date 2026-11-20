# Tasks

## 1. Delete command

- [x] 1.1 Add `-y`/`--yes` to cli_extra_flags in commands/jef-delete.sh and verify `jef delete --help` lists it
- [x] 1.2 Extract read-only `plan_repo` shared by dry run, plan and real deletion; verify tests/dry-run.bats and tests/summary.bats still pass
- [x] 1.3 Add plan printing, prompt, abort (exit 1) and no-terminal (exit 2) handling; verify with tests/delete.bats

## 2. Tests

- [x] 2.1 Pass `-y` in existing tests that expect deletion (delete.bats, summary.bats) and verify they pass
- [x] 2.2 Add tests for plan text, n/y via fake terminal, no terminal, -y, --yes, help, nothing to delete, -n with -y; verify `./scripts/check.sh --quick tests/delete.bats` passes

## 3. Cached plan and quiet repositories

- [x] 3.1 Cache each repository's plan in parallel indexed arrays and reuse it in the deletion pass; verify the ls-remote-once test in tests/delete.bats passes
- [x] 3.2 Print the repository header only for repositories with something to delete or a message (also in --dry-run); verify the header tests pass

## 4. Docs and checks

- [x] 4.1 Update README.md (usage line, flags table, exit codes, prompt example) and verify the text matches behaviour
- [x] 4.2 Run `./scripts/check.sh --both`, the Linux docker check, and `openspec validate delete-confirmation --strict` and `openspec validate --specs --strict`
