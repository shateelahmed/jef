# installation Specification

## Purpose
Installing scrippy on a user machine and dispatching `scrippy <command>` to the matching command script.

## Requirements
### Requirement: Unix installation
The installer SHALL, on Linux or macOS with git available, replace `~/.scrippy` with a fresh copy of the repository (excluding `.git` and `.gitignore`), make the command scripts executable with their `.sh` suffix removed, and add `~/.scrippy/commands` to PATH in the user's shell rc file if not already present.

#### Scenario: Fresh install
- **WHEN** the user runs `./install.sh` on macOS with zsh
- **THEN** `~/.scrippy/commands/scrippy-*` exist as executables and `~/.zshrc` exports the commands directory on PATH

#### Scenario: Re-install
- **WHEN** the commands directory is already on PATH in the rc file
- **THEN** the PATH line is not added again

#### Scenario: Git missing
- **WHEN** git is not installed
- **THEN** the installer prints that git is required and exits

### Requirement: Unsupported platforms
The installer SHALL refuse to install on Windows or unknown OS types with an explanatory message.

#### Scenario: Windows
- **WHEN** the installer runs under msys, cygwin or win32
- **THEN** it prints that Windows is not supported and exits

### Requirement: Command dispatch
The system SHALL provide a `scrippy` entry point that runs `scrippy-<command>` with the remaining arguments.

#### Scenario: Dispatch
- **WHEN** the user runs `scrippy find feature-x -c`
- **THEN** `scrippy-find feature-x -c` is executed
