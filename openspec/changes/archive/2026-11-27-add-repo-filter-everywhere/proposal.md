## Why
Only `merged`, `sync`, `status` and `checkout -b` can be limited to some repositories with `-m`/`--repo`. Every other command always runs on every repository, so working on two services of twenty means running git by hand or touching all of them. Each of the four commands also carries its own copy of the same filter code.

## What Changes
- Every command that operates on repositories accepts `-m`/`--repo REPOS` (comma or space separated, repeatable): checkout, delete, fetch, find, merge, merged, migrate, pull, push, rebase, stash, status, sync and which.
- The filter lives in one place (lib/repos.sh): the repository iteration (`for_each_repo`, `list_repos`, `parallel_run`) only visits the named repositories, in the usual order, and unknown names are a usage error (exit 2) before anything runs. The copies in merged, sync, status and checkout are removed.
- Commands that print a banner show `Repositories: all` or the names.
- `jef checkout` accepts `-m` without `-b` too (it limits the checkout to those repositories); with `-b` it still replaces the picker.
- `jef migrate` does not warn about `MIGRATE_CMDS` entries for repositories left out by `-m`.

## Affected commands
- All repository commands; lib/repos.sh, lib/cli.sh (no change expected), README.md.

## Out of scope
- Glob patterns or exclusions in `-m`, a config default for it.
