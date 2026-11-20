#!/bin/bash

# Removes jef (~/.jef and its PATH line in shell rc files).

usage() {
    echo "Usage: $(basename "$0") [-y|--yes] [-h|--help]"
    echo "  Removes ~/.jef and the 'export PATH=...' lines pointing to /.jef/commands"
    echo "  from your shell rc files (backups are saved as <file>.jef-uninstall.bak)."
    echo "  Your ~/.jef/.env, if any, is saved to ~/.jef.env.bak."
    echo "  -y, --yes   skip the confirmation prompt"
    echo "  -h, --help  show this help"
}

assume_yes=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes) assume_yes=1 ;;
        -h|--help) usage; exit 0 ;;
        *) usage; exit 2 ;;
    esac
done

if [ -z "$HOME" ]; then
    echo "HOME is not set. Aborting."
    exit 1
fi

target_dir="$HOME/.jef"
env_backup="$HOME/.jef.env.bak"

# Collect candidate rc files (de-duplicated, existing files or symlinks only)
candidates="$HOME/.zshrc $HOME/.bashrc $HOME/.bash_profile $HOME/.profile"
if [ -n "$SHELL" ]; then
    candidates="$candidates $HOME/.$(basename "$SHELL")rc"
fi

rc_files=""
for f in $candidates; do
    if [ -f "$f" ] || [ -L "$f" ]; then
        case " $rc_files " in
            *" $f "*) ;;
            *) rc_files="$rc_files $f" ;;
        esac
    fi
done

# Keep only rc files that have matching lines
matched_files=""
report=""
for f in $rc_files; do
    lines="$(grep -nE '^[[:space:]]*export PATH=' "$f" 2> /dev/null | grep -F '/.jef/commands')"
    if [ -n "$lines" ]; then
        matched_files="$matched_files $f"
        report="$report$(printf '%s\n' "$lines" | sed "s|^|  $f:|")
"
    fi
done

have_dir=0
if [ -d "$target_dir" ] || [ -L "$target_dir" ]; then
    have_dir=1
fi

if [ "$have_dir" -eq 0 ] && [ -z "$matched_files" ]; then
    echo "No jef installation found."
    exit 0
fi

have_env=0
if [ "$have_dir" -eq 1 ] && [ -f "$target_dir/.env" ]; then
    have_env=1
fi

echo "The following will be removed:"
if [ "$have_dir" -eq 1 ]; then
    if [ -L "$target_dir" ]; then
        echo "  directory (symlink, only the link): $target_dir"
    else
        echo "  directory: $target_dir"
    fi
    if [ "$have_env" -eq 1 ]; then
        echo "  (your $target_dir/.env will be saved to $env_backup)"
    fi
fi
if [ -n "$matched_files" ]; then
    echo "  PATH lines (file:line:content):"
    printf '%s' "$report"
fi

if [ "$assume_yes" -ne 1 ]; then
    if [ ! -t 0 ]; then
        echo "Not running in a terminal. Re-run with --yes to confirm removal. Nothing was changed."
        exit 1
    fi
    printf 'Remove these? [y/N] '
    read -r answer
    case "$answer" in
        y|Y|yes) ;;
        *) echo "Aborted. Nothing was changed."; exit 1 ;;
    esac
fi

if [ "$have_env" -eq 1 ]; then
    cp "$target_dir/.env" "$env_backup" || { echo "Could not back up $target_dir/.env. Aborting."; exit 1; }
    echo "Saved your configuration to $env_backup"
fi

for f in $matched_files; do
    cp -p "$f" "$f.jef-uninstall.bak" || { echo "Could not back up $f. Aborting."; exit 1; }
    tmp="$(mktemp)" || exit 1
    grep -vE '^[[:space:]]*export PATH=.*/\.jef/commands' "$f" > "$tmp"
    cat "$tmp" > "$f"
    rm -f "$tmp"
    echo "Updated $f (backup: $f.jef-uninstall.bak)"
done

if [ "$have_dir" -eq 1 ]; then
    if [ -L "$target_dir" ]; then
        rm -f "$target_dir"
    else
        rm -rf "$target_dir"
    fi
    echo "Removed $target_dir"
fi

echo "Done."
for f in $matched_files; do
    echo "Restart your terminal or run: source $f"
done
