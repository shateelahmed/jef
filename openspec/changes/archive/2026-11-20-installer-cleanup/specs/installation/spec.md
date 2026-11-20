## MODIFIED Requirements

### Requirement: Unix installation
The installer SHALL, on Linux or macOS with git available, replace `~/.jef` with a fresh copy of only the `commands/` and `lib/` directories and the `.env` file (if present in the repository), without requiring rsync. It SHALL make the command scripts executable with their `.sh` suffix removed and add `~/.jef/commands` to PATH in the user's shell rc file (see "Shell rc file selection") if not already present.

#### Scenario: Fresh install
- **WHEN** the user runs `./install.sh` on macOS with zsh
- **THEN** `~/.jef/commands/jef` and `~/.jef/commands/jef-*` exist as executables, `~/.jef/lib` exists, `~/.zshrc` exports the commands directory on PATH, and `~/.jef` contains nothing else (no `openspec/`, `tests/`, `.claude/`, `README.md`)

#### Scenario: Re-install
- **WHEN** the commands directory is already on PATH in the rc file
- **THEN** the PATH line is not added again

#### Scenario: Git missing
- **WHEN** git is not installed
- **THEN** the installer prints that git is required and exits

### Requirement: Unsupported platforms
The installer SHALL refuse to install on Windows or unknown OS types with an explanatory message and a non-zero exit status.

#### Scenario: Windows
- **WHEN** the installer runs under msys, cygwin or win32
- **THEN** it prints that Windows is not supported yet and exits with status 1

#### Scenario: Unknown OS
- **WHEN** the OS type is not recognised
- **THEN** it prints "Unsupported OS" and exits with status 1

## ADDED Requirements

### Requirement: Shell rc file selection
The installer SHALL choose the rc file from the basename of `$SHELL`: zsh uses `~/.zshrc`; bash uses `~/.bash_profile` on macOS and `~/.bashrc` on Linux. For any other shell it SHALL NOT write any file and SHALL print the exact `export PATH=...` line for the user to add. The "already in PATH" check SHALL match the commands directory as a fixed string.

#### Scenario: zsh
- **WHEN** `SHELL` is `/bin/zsh`
- **THEN** the PATH line is appended to `~/.zshrc`

#### Scenario: bash on macOS
- **WHEN** `SHELL` is `/bin/bash` on macOS
- **THEN** the PATH line is appended to `~/.bash_profile`

#### Scenario: bash on Linux
- **WHEN** `SHELL` is `/bin/bash` on Linux
- **THEN** the PATH line is appended to `~/.bashrc`

#### Scenario: Other shell
- **WHEN** `SHELL` is `/usr/bin/fish`
- **THEN** no rc file is created or modified and the output contains the exact PATH line to add

### Requirement: Configuration preservation
Re-installing SHALL NOT lose the user's `.env`. If `~/.jef/.env` exists and the repository has no `.env`, the installed one SHALL be kept. If both exist, the repository's SHALL be installed and the previous one backed up to `~/.jef.env.bak`, and the installer SHALL say so.

#### Scenario: Keep installed .env
- **WHEN** `~/.jef/.env` exists and the repository has no `.env`
- **THEN** after install `~/.jef/.env` has its previous contents

#### Scenario: Repository .env wins
- **WHEN** both `~/.jef/.env` and a repository `.env` exist with different contents
- **THEN** `~/.jef/.env` has the repository's contents, `~/.jef.env.bak` has the previous contents, and the output mentions the backup

### Requirement: jef uninstaller
The project SHALL provide `uninstall.sh`, which lists what it will remove, asks for confirmation (`-y`/`--yes` skips the prompt; without a terminal and without `-y` it aborts changing nothing), backs up each shell rc file as `<file>.jef-uninstall.bak` before removing only the PATH line(s) containing `/.jef/commands`, and removes `~/.jef`. If `~/.jef/.env` exists it SHALL be saved to `~/.jef.env.bak` first and the output SHALL say so.

#### Scenario: Confirmed removal
- **WHEN** jef is installed and the user runs `./uninstall.sh` and answers `y`
- **THEN** `~/.jef` is gone, the PATH line is removed from the rc file with all other lines unchanged, and the rc backup holds the original

#### Scenario: Declined
- **WHEN** the user answers anything other than `y`
- **THEN** nothing is changed and the exit status is non-zero

#### Scenario: Non-interactive without --yes
- **WHEN** it runs without a terminal and without `-y`
- **THEN** it aborts with an explanatory message and changes nothing

#### Scenario: Unattended removal
- **WHEN** the user runs `./uninstall.sh --yes`
- **THEN** the removal happens without a prompt

#### Scenario: .env kept
- **WHEN** `~/.jef/.env` exists and uninstall completes
- **THEN** `~/.jef.env.bak` holds its contents

#### Scenario: Nothing to remove
- **WHEN** neither `~/.jef` nor any jef PATH line exists
- **THEN** it prints "No jef installation found." and exits 0
