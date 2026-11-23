## Why
Starting a feature that spans several repositories means running `git checkout -b` in each one by hand. `jef checkout` only switches to branches that already exist.

## What Changes
- New flag `-b`/`--new` on `jef checkout`: `jef checkout -b <new_branch> <base>` creates `<new_branch>` from `<base>` and checks it out in the repositories the user picks.
- On a terminal, an interactive checkbox list of repositories is shown (nothing ticked): Up/Down or k/j move, Space toggles, `a` toggles all, Enter confirms, `q`/Esc cancels. Repositories where `<new_branch>` already exists or `<base>` does not resolve are listed but cannot be ticked, with the reason.
- `-m`/`--repo REPOS` (comma or space separated, repeatable) picks the repositories without the picker; required when there is no terminal (else exit 2).
- Without `-b`, `jef checkout <branch>` behaves exactly as today (one positional; `-m` is rejected without `-b`).
- New shared library `lib/select.sh` with the checkbox picker (bash 3.2, BSD/GNU portable, reads keys from the terminal).

## Affected commands
- `jef checkout` only.

## Out of scope
- Pushing the new branch or setting an upstream.
- Branching from each repository's current HEAD (a base is always required).
- Using the picker in other commands.

## Impact
- Spec: branch-checkout. Code: commands/jef-checkout.sh, new lib/select.sh. Tests: tests/checkout.bats (and test_helper.bash for key-sending in a fake terminal). Docs: README.md.
