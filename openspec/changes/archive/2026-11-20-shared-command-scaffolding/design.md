# Design

## Context

See proposal.md. Commands run as plain scripts (no `.sh` suffix once installed, on PATH). They must work on bash 3.2/BSD and Linux. Ordering constraints today: usage errors (`N argument(s) required`) appear before the `.env`/target-directory checks, the banner is printed before `clear-proxy.sh` runs, and the spinner traps are only wanted in `find`/`which`.

## Goals / Non-Goals

**Goals:** remove the duplicated scaffolding, add help/usage, keep normal output byte-identical.

**Non-Goals:** changing option semantics (options must still precede positional arguments), changing per-repository git logic.

## Decisions

- **Two-phase command prologue.** A command sources `lib/cli.sh`, declares `cli_name`, `cli_description`, `cli_positionals`, `cli_accepts_proxy` and optional `cli_extra_flags` (`"short|long|variable|description"`), calls `parse_options "$@"`, then `require_args N` if it takes arguments, and only then sources `lib/common.sh`. This keeps help and usage errors independent of `.env`/target configuration, as the argument-count error is today. Alternative (one lib doing everything) would make `--help` fail when no target is configured.
- **`getopts` inside `parse_options`** with `local OPTIND=1` and an explicit argument array, in silent mode (`:` prefix) so jef prints its own messages. Long options are normalised to short ones first, as before; unknown `--long` options are reported by their original name. Results are left in globals (`target_directory`, `clear_proxy`, the extra-flag variables, `cli_positional` array). `--help`/`-h` anywhere in the arguments wins. Alternative (hand-written parser) would lose bundled short options like `-cd dir`.
- **Usage errors go to stderr, help to stdout.** Unknown option: message plus usage on stderr, exit 2. Argument-count messages stay on stdout exactly as today.
- **`for_each_repo` calls a callback in the current shell**, so callbacks can fill arrays and set flags; callbacks use `return` where the old loops used `continue`. A `print_repo_header` helper prints the "Working directory" line (fetch passes `:` to keep its legacy colon).
- **`lib/common.sh`** sources load-env, target-directory, verify-git-repo, directory-name, skip-directory, terminal-color-codes, max-length and repos. `spinner.sh` (installs signal traps) and `clear-proxy.sh` (must run after the banner) stay explicit in the commands that need them.
- **Dispatcher** keeps a static list of command names and descriptions (it has no libs on the installed PATH copy and must not run every command to list them); a test checks the list matches the commands and their `--help` descriptions. Command lookup uses `command -v jef-<name>` and rejects names with unexpected characters.

## Risks / Trade-offs

- [Callback style is less obvious than inline loops] -> the helper is small and documented in `lib/repos.sh`.
- [Description drift between dispatcher list and commands] -> covered by a bats test.
- [`jef find -c` ordering of "Cleared proxy" changes] -> intentional, matches the other commands and the brief.
