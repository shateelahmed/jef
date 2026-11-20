# installation Specification

## Purpose
Installing jef on a user machine and dispatching `jef <command>` to the matching command script.

## Requirements

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

### Requirement: Command dispatch
The system SHALL provide a `jef` entry point that runs `jef-<command>` with the remaining arguments.

#### Scenario: Dispatch
- **WHEN** the user runs `jef find feature-x -c`
- **THEN** `jef-find feature-x -c` is executed

### Requirement: Legacy scrippy install notice
When `~/.scrippy` exists or the user's shell rc file contains `~/.scrippy/commands` (or its expanded form), the installer SHALL print a notice recommending `./uninstall-scrippy.sh`, with the manual cleanup steps as a fallback (remove `~/.scrippy` and remove the old PATH line from the rc file). The installer SHALL NOT delete `~/.scrippy` or modify existing rc lines, and SHALL still complete the `~/.jef` installation.

#### Scenario: Old install present
- **WHEN** `~/.scrippy` exists and the user runs `./install.sh`
- **THEN** `~/.jef` is installed, the notice recommends `./uninstall-scrippy.sh` and lists the manual steps, and `~/.scrippy` is left untouched

#### Scenario: Old PATH line only
- **WHEN** `~/.scrippy` is gone but the rc file still contains the old commands path
- **THEN** the notice is printed and the rc file is not modified for that line

#### Scenario: No old install
- **WHEN** neither `~/.scrippy` nor the old PATH line exists
- **THEN** no migration notice is printed

### Requirement: Scrippy uninstaller
The project SHALL provide `uninstall-scrippy.sh`, which removes `~/.scrippy` and the old `export PATH=` lines containing `/.scrippy/commands` from the user's shell rc files, after listing them and getting confirmation (`-y`/`--yes` skips the prompt). It SHALL back up each rc file it modifies and SHALL NOT change anything else.

#### Scenario: Confirmed removal
- **WHEN** `~/.scrippy` exists, `~/.zshrc` contains the old PATH line, and the user runs `./uninstall-scrippy.sh` and answers `y`
- **THEN** `~/.scrippy` is removed, the PATH line is removed from `~/.zshrc`, `~/.zshrc.scrippy-uninstall.bak` holds the original, and all other lines in `~/.zshrc` are unchanged

#### Scenario: Declined
- **WHEN** the user answers anything other than `y` at the prompt
- **THEN** nothing is removed or modified and the script exits non-zero

#### Scenario: Non-interactive without --yes
- **WHEN** the script runs without a terminal and without `-y`
- **THEN** it aborts with an explanatory message and changes nothing

#### Scenario: Unattended removal
- **WHEN** the user runs `./uninstall-scrippy.sh --yes`
- **THEN** the removal happens without a prompt

#### Scenario: Nothing to remove
- **WHEN** neither `~/.scrippy` nor any old PATH line exists
- **THEN** it prints "No scrippy installation found." and exits 0

#### Scenario: jef install untouched
- **WHEN** `~/.jef` exists and its PATH line is in the rc file
- **THEN** the uninstaller leaves `~/.jef` and that line unchanged

### Requirement: Dispatcher help and unknown commands
The `jef` entry point SHALL list the available commands with one-line descriptions and exit 0 for `jef help`, `jef -h` and `jef --help`, and exit 2 when run with no command. `jef help <command>` SHALL show that command's help. For an unknown command it SHALL print "jef: unknown command '<name>'" followed by the command list and exit 127.

#### Scenario: Help listing
- **WHEN** the user runs `jef help`
- **THEN** every command and its description is listed and the exit status is 0

#### Scenario: No command
- **WHEN** the user runs `jef` with no arguments
- **THEN** the command list is printed and the exit status is 2

#### Scenario: Help for one command
- **WHEN** the user runs `jef help delete`
- **THEN** the output is the same as `jef delete --help`

#### Scenario: Unknown command
- **WHEN** the user runs `jef nonsense`
- **THEN** "jef: unknown command 'nonsense'" and the command list are printed and the exit status is 127

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
