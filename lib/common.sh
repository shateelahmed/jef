# Loads the libraries every command needs, once its options are parsed
# (lib/cli.sh is sourced first so --help and usage errors work without a target).
#
# Deliberately NOT sourced here: lib/spinner.sh (installs signal traps; only
# find and which source it) and lib/clear-proxy.sh (must run after the banner).
# shellcheck disable=SC2154 # script_location is set by the sourcing command
source "$script_location/lib/load-env.sh"
source "$script_location/lib/target-directory.sh"
source "$script_location/lib/verify-git-repo.sh"
source "$script_location/lib/directory-name.sh"
source "$script_location/lib/skip-directory.sh"
source "$script_location/lib/terminal-color-codes.sh"
source "$script_location/lib/max-length.sh"
source "$script_location/lib/repos.sh"
