# Design

## Context

`jef fetch` already shows the pattern: iterate the first-level repositories sequentially with `for_each_repo`, or concurrently with `parallel_run` and a worker returning 0, 1 or 2. `jef migrate` follows it, with the command coming from `.env`.

## Goals / Non-Goals

**Goals:** one setting for all repositories; failures never stop the run; same ordering and outcome with `-j`.

**Non-Goals:** rollbacks, a default command, environment selection, a confirmation prompt.

## Decisions

- **Format.** `MIGRATE_CMDS="name:cmd; name2:cmd2"`. Entries are split on `;` outside single or double quotes (a small character scan), so `docker exec app sh -c "a; b"` stays one entry; an unterminated quote exits 2. The name is the text before the first `:`; whitespace around names and commands is trimmed. Blank entries (a trailing `;`) are ignored.
- **Parsing.** Two parallel indexed arrays (names, commands); bash 3.2 has no associative arrays. Looked up by the directory name from `get_directory_name`.
- **Validation.** An entry without `:`, with an empty name or command, or a duplicate name exits 2 before anything runs. `MIGRATE_CMDS` unset or empty exits 1 with a hint, like a missing `TARGET_DIR`. Names that match no repository (missing, not a git repository, or in `SKIP_DIRS`) only warn, because the same `.env` may be used with different `-d` targets.
- **Execution.** `(cd "<repo>" && bash -c "<command>")`. `bash -c` makes `&&`, redirects and quotes work; the command is data from `.env` that is only run when the user runs `jef migrate`. The shell is non-interactive, so rc files (nvm, etc.) are not loaded.
- **Non-interactive.** Commands often run inside Docker containers and must not wait for input. The documented method is `docker exec <container> ...` without `-it`: it addresses the running container by name, so it works wherever the compose file lives (often not in the repository root), whereas `docker compose exec` would need `-f <file>`. Every command gets stdin from `/dev/null`, with or without `-j`, so a prompt fails fast instead of hanging and sequential and parallel runs behave the same. No TTY is allocated, so commands using `docker exec -it` must drop `-it`; the README says so.
- **Branch check.** `-b` compares `git branch --show-current`; other repositories print "on <current>, not <BRANCH>. skipping..." and count as skipped. The name is validated with `is_valid_branch_name`.
- **No entry.** The repository is skipped silently and counted as skipped.

## Risks / Trade-offs

- A `;` outside quotes always separates entries; quote it (e.g. inside `sh -c "..."`) or use `&&`.
- Output of parallel runs is printed per repository when all are done, as in `fetch`.
