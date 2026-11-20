## MODIFIED Requirements

### Requirement: Optional proxy clearing
Commands that contact a remote (including `jef fetch`) SHALL accept `-c`/`--clear-proxy`, and when given SHALL unset `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY` (upper and lower case) before running git and print "Cleared proxy". When the flag is not given, no command SHALL change the proxy variables or print "Cleared proxy".

#### Scenario: Proxy cleared
- **WHEN** the user runs a remote-contacting command with `--clear-proxy`
- **THEN** proxy variables are unset for that run and "Cleared proxy" is printed

#### Scenario: Fetch with proxy clearing
- **WHEN** the user runs `jef fetch -c`
- **THEN** proxy variables are unset before fetching and "Cleared proxy" is printed

#### Scenario: Flag omitted
- **WHEN** the user runs any jef command (for example `jef fetch` or `jef which`) without `-c`/`--clear-proxy` while `HTTPS_PROXY` is set
- **THEN** `HTTPS_PROXY` stays set for git and "Cleared proxy" is not printed
