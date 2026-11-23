## 1. Picker library
- [x] 1.1 Add lib/select.sh with `select_repos` (checkbox picker on /dev/tty, keys Up/Down/k/j, Space, a, Enter, q/Esc; disabled items with reasons; restores cursor on exit/INT; bash 3.2 and BSD/GNU portable)

## 2. Checkout command
- [x] 2.1 Add `-b`/`--new` and `-m`/`--repo REPOS` to commands/jef-checkout.sh; keep plain `jef checkout <branch>` unchanged; reject `-m` without `-b`
- [x] 2.2 Validate both names, compute per-repo eligibility (branch exists / base does not resolve)
- [x] 2.3 Choose repositories via picker (terminal) or `-m` (unknown names exit 2; no terminal and no `-m` exits 2)
- [x] 2.4 Create and check out with `git checkout -b <new> <base>`, print outcomes, finish_run summary

## 3. Base fallback, picker polish
- [x] 3.1 Resolve the base locally or as origin/<base> per repository (create with --no-track), start the cursor on the first available row, turn terminal echo off in the picker, skip the picker when nothing is available (exit 1)

## 4. Tests and docs
- [x] 4.1 Add a test helper that drives a picker in a fake terminal with raw keys; add tests to tests/checkout.bats for -m, no-terminal, unknown names, unavailable repos, picker select/toggle-all/cancel, arg count, failure
- [x] 4.2 Update README.md (usage line and options table)
