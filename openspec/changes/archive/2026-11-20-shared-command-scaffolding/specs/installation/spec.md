## ADDED Requirements

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
