# Tasks

## 1. Rename scripts

- [x] 1.1 `git mv commands/scrippy.sh commands/jef.sh`; verify `ls commands` shows `jef.sh` and no `scrippy.sh`.
- [x] 1.2 `git mv` each of `commands/scrippy-{checkout,delete,fetch,find,merge,pull,push,which}.sh` to `commands/jef-<name>.sh`; verify `ls commands` shows eight `jef-*.sh` files and no `scrippy-*`.
- [x] 1.3 Update the dispatcher comment and call in `commands/jef.sh` to `"jef-$command" "$@"`; verify with `bash -n commands/jef.sh` and `grep -i scrippy commands/` returning nothing.

## 2. Installer

- [x] 2.1 In `install.sh`, set the installation directory to `$HOME/.jef` and change both `scrippy*.sh` globs to `jef*.sh` (update the chmod comment, remove or update the stale commented `bulk-git` line); verify with `bash -n install.sh`.
- [x] 2.2 Add the legacy-install notice: if `$HOME/.scrippy` exists or the rc file contains `.scrippy/commands`, print the manual steps (`rm -rf ~/.scrippy`; remove the old PATH line from the rc file) without deleting or editing anything; handle a missing rc file without error; use bash 3.2/BSD-safe constructs only. The notice recommends `./uninstall-scrippy.sh` before listing the manual steps. Verify in a temp HOME: notice appears with an old dir or old PATH line, and not otherwise, and `~/.scrippy` is untouched.
- [x] 2.3 Create `uninstall-scrippy.sh` (executable, bash 3.2/BSD-safe) per design decision 9:
  - detection across `~/.zshrc`, `~/.bashrc`, `~/.bash_profile`, `~/.profile` and the `$SHELL` rc file;
  - list, then `[y/N]` confirmation, with `-y`/`--yes` to skip it;
  - abort when there is no terminal and no `-y`;
  - rc backups to `<file>.scrippy-uninstall.bak`;
  - line removal with `grep -v` plus `cat` write-back, with no `sed -i`;
  - guarded `rm -rf "$HOME/.scrippy"`;
  - prints "No scrippy installation found." and exits 0 when there's nothing to remove.
  Verify with `bash -n`.

## 3. Documentation and config

- [x] 3.1 Update `README.md`: title and prose, all usage examples (`jef <cmd>`, including the sample output headings), the `TARGET_DIR` description, and the install path; add a short "Migrating from scrippy" section (re-run `install.sh`, then run `./uninstall-scrippy.sh` or remove `~/.scrippy` and the old PATH line by hand; no `.env` migration needed). Verify by reading README and grep.
- [x] 3.2 Update `AGENTS.md` title and the "Scrippy specifics" heading to jef; update `openspec/config.yaml` context and proposal rule text from scrippy to jef. Verify with `grep -i scrippy AGENTS.md openspec/config.yaml` returning nothing.
- [x] 3.3 Update the Purpose lines in `openspec/specs/{branch-checkout,branch-delete,branch-find,branch-merge,branch-pull,branch-push,branch-status}/spec.md` (and the installation, fetch and target-discovery Purpose lines) to use `jef`; verify with `grep -ri scrippy openspec/specs` returning only text that archive will replace, then none after archive.
- [x] 3.4 Confirm `.env.example` and `lib/*.sh` need no change (`grep -i scrippy` returns nothing); no env var is renamed.

## 4. Verification

- [x] 4.1 `bash -n` on every `.sh` file in `commands/`, `lib/`, `install.sh` and `uninstall-scrippy.sh`; all exit 0.
- [x] 4.2 `grep -ri scrippy . --exclude-dir=.git --exclude-dir=archive --exclude-dir=changes` returns only the intended migration mentions (install.sh notice, README migration section, `uninstall-scrippy.sh`).
- [x] 4.3 Install into a temp HOME (`HOME=$(mktemp -d) SHELL=/bin/bash ./install.sh`), put `$HOME/.jef/commands` on PATH, create a directory with 2 test git repos, and run `jef which -d <dir>`; it lists both repos and exits 0. Also check `jef` with an unknown command fails cleanly and that no `scrippy` executable is installed.
- [x] 4.5 Test the uninstaller in a temp HOME seeded with a fake `~/.scrippy`, a `~/.zshrc` containing the old PATH line plus unrelated lines and the `~/.jef` PATH line, and a `~/.jef` directory. Check:
  - Answering `n` changes nothing and exits non-zero.
  - `--yes` removes `~/.scrippy` and only the old line, creates the `.bak`, and leaves `~/.jef` and the other lines identical (diff against the backup).
  - Running it with no terminal (`</dev/null`) and no `-y` aborts and changes nothing.
  - A second run prints "No scrippy installation found." and exits 0.
- [x] 4.4 Run `openspec validate rename-to-jef --strict` and `openspec validate --specs --strict`; both pass.
