# Tasks

## 1. Migrate command

- [x] 1.1 Add commands/jef-migrate.sh: parse `MIGRATE_CMDS`, banner, warnings, per-repository run, `-n`, `-b`, `-j`; verify with tests/migrate.bats
- [x] 1.2 List `migrate` in commands/jef.sh
- [x] 1.3 Add `MIGRATE_CMDS` to .env.example

## 2. Tests

- [x] 2.1 Add tests/migrate.bats and a `write_migrate_cmds` helper; add migrate to the command lists in tests/cli.bats, tests/dry-run.bats and tests/parallel.bats

## 3. Non-interactive commands

- [x] 3.0 Give every command stdin from /dev/null (with or without -j) and split MIGRATE_CMDS on ';' only outside quotes, for Docker commands such as `docker exec app sh -c "a; b"`; document `docker exec <container>` (independent of the compose file location) as the Docker method in README.md and .env.example; cover with tests/migrate.bats

## 4. Docs and checks

- [x] 4.1 Update README.md (feature bullet, `MIGRATE_CMDS` setting, usage, flags table row, exit codes, summary, dry-run and `-j` notes, the `;` and `bash -c` caveats)
- [x] 4.2 Run `./scripts/check.sh --both`, `openspec validate add-migrate-command --strict` and `openspec validate --specs --strict`
