## Why

Each microservice has its own migration command (for example `php artisan migrate` or `npm run migrate`). Running them by hand in every repository is tedious. jef already iterates over the repositories, so one setting in `.env` can drive them all.

## What Changes

- New command `jef migrate [-d DIR] [-n] [-j N] [-b BRANCH]`: runs, in each repository that has an entry in `MIGRATE_CMDS`, that entry's command from inside the repository.
- New `.env` variable `MIGRATE_CMDS="name:cmd; name2:cmd2"`; repositories without an entry are skipped silently, entries naming a missing repository only produce a warning.
- A failing command does not stop the run: the repository counts as failed, the run continues and the exit status is 3.
- Commands run non-interactively (stdin is `/dev/null`), so they work inside Docker containers (`docker exec <container> ...`, independent of where the compose file lives); a `;` inside quotes does not split an entry.
- `-n` prints "Would run: <command>" and runs nothing; `-j N` runs up to N migrations at once; `-b BRANCH` only migrates repositories that currently have BRANCH checked out.
- README and `.env.example` document the command and the variable.

## Capabilities

### New Capabilities
- `db-migrate`: running each repository's configured command across repositories.

### Modified Capabilities

## Impact

Affected commands: the new `migrate` command only (plus its listing in `jef help`). Code: commands/jef-migrate.sh, commands/jef.sh, tests, README.md, .env.example.

Out of scope: rollbacks, a default command applied to every repository, selecting an environment, a confirmation prompt, interactive commands (TTY or prompts), loading the user's shell rc files.
