## Why
Many one-off jobs across the repositories (`git log -1`, `npm install`, a `grep`, a version bump) will never get a jef command of their own, so they are run by hand in each repository.

## What Changes
- New command `jef exec [options] [--] <command...>`: runs a command inside every repository (or the ones named with `-m`), with the usual "Working directory" headers, a summary and exit 3 when a command fails.
- One argument is run as a shell string (`bash -c`, so pipes, `&&` and redirects work); several arguments are run as the command and its arguments, as given.
- `-j N` runs up to N repositories at once (output kept per repository and printed in order), `-b BRANCH` only runs in repositories that have BRANCH checked out, `-n` previews.
- Option parsing (lib/cli.sh) gains a mode in which everything from the first positional word or `--` on is passed through untouched, so the command's own options (`-1`, `-h`, `--dry-run`) are not taken as jef's.
- Listed in `jef help`; documented in README.md.

## Affected commands
- New `jef exec`; lib/cli.sh (opt-in, no change for other commands); the dispatcher's command list.

## Out of scope
- Interactive commands (no terminal input), per-repository different commands (that is `jef migrate`), stopping at the first failure.
