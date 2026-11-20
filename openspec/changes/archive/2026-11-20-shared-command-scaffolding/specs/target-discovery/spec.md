## ADDED Requirements

### Requirement: Command help and usage
Every jef command SHALL accept `-h`/`--help`, print its usage (synopsis, options, one-line description) to stdout and exit 0 without touching any repository, whether or not a target directory is configured. An unrecognised option SHALL print a message and the command's usage to stderr and exit with status 2.

#### Scenario: Help requested
- **WHEN** the user runs `jef checkout --help` with no target directory configured
- **THEN** the usage is printed and the exit status is 0

#### Scenario: Unknown option
- **WHEN** the user runs `jef which --bogus`
- **THEN** an "unknown option" message and the usage are printed and the exit status is 2

#### Scenario: Option not supported by the command
- **WHEN** the user runs `jef checkout -c`, a command that has no proxy option
- **THEN** it is treated as an unknown option with exit status 2
