## MODIFIED Requirements

### Requirement: Unix installation
The installer SHALL, on Linux or macOS with git available, replace `~/.jef` with a fresh copy of the repository (excluding `.git` and `.gitignore`), make the command scripts executable with their `.sh` suffix removed, and add `~/.jef/commands` to PATH in the user's shell rc file if not already present.

#### Scenario: Fresh install
- **WHEN** the user runs `./install.sh` on macOS with zsh
- **THEN** `~/.jef/commands/jef` and `~/.jef/commands/jef-*` exist as executables and `~/.zshrc` exports the commands directory on PATH

#### Scenario: Re-install
- **WHEN** the commands directory is already on PATH in the rc file
- **THEN** the PATH line is not added again

#### Scenario: Git missing
- **WHEN** git is not installed
- **THEN** the installer prints that git is required and exits

### Requirement: Command dispatch
The system SHALL provide a `jef` entry point that runs `jef-<command>` with the remaining arguments.

#### Scenario: Dispatch
- **WHEN** the user runs `jef find feature-x -c`
- **THEN** `jef-find feature-x -c` is executed

## ADDED Requirements

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
