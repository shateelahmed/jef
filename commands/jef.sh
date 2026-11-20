#!/bin/bash
command="$1"
shift

# Try to execute the command with the "jef-" prefix
"jef-$command" "$@"
