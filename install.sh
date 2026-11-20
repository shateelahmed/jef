#!/bin/bash

# Installs jef to ~/.jef (commands/, lib/ and .env only) and puts ~/.jef/commands on PATH.

# Function to install on Linux and MacOS
install_unix() {
    echo "Detected Unix-based OS. Installing..."

    # Ensure git is installed
    if ! command -v git &> /dev/null; then
        echo "Git is required. Please install Git first."
        exit 1
    fi

    # The repository this script lives in (works from any working directory)
    source_directory="$(cd "$(dirname "$0")" && pwd)" || exit 1

    # Define installation directory in the user's home directory
    installation_directory="$HOME/.jef"
    # Define the commands directory in the user's home directory
    commands_directory="$installation_directory/commands"
    env_backup="$HOME/.jef.env.bak"

    # Keep the installed .env around: the old installation is removed below
    saved_env=""
    if [ -f "$installation_directory/.env" ]; then
        saved_env="$(mktemp)" || exit 1
        cp "$installation_directory/.env" "$saved_env" || exit 1
    fi

    # Remove the installation directory if it exists
    rm -rf "$installation_directory"

    # Create the directory if it doesn't exist
    mkdir -p "$installation_directory"

    # Copy only what jef needs at runtime
    cp -R "$source_directory/commands" "$source_directory/lib" "$installation_directory/" || exit 1
    if [ -f "$source_directory/.env" ]; then
        cp "$source_directory/.env" "$installation_directory/.env" || exit 1
    fi

    # Preserve the user's configuration across re-installs
    if [ -n "$saved_env" ]; then
        if [ ! -f "$installation_directory/.env" ]; then
            cp "$saved_env" "$installation_directory/.env"
            echo "Kept your existing configuration: $installation_directory/.env"
        elif ! cmp -s "$saved_env" "$installation_directory/.env"; then
            cp "$saved_env" "$env_backup"
            echo "Installed the .env from this repository. Your previous configuration was backed up to $env_backup"
        fi
        rm -f "$saved_env"
    fi

    chmod +x "$commands_directory"/jef*.sh # Make the jef prefixed scripts executable

    # Strip the .sh extension so the scripts run as commands (jef, jef-push, ...)
    for file in "$commands_directory"/jef*.sh; do
        mv "$file" "${file%.sh}"
    done

    path_line="export PATH=\"\$PATH:$commands_directory\""

    # Pick the shell rc file from the user's login shell
    default_shell="$(basename "$SHELL")"
    shell_config=""
    case "$default_shell" in
        zsh)
            shell_config="$HOME/.zshrc"
            ;;
        bash)
            case "$OSTYPE" in
                darwin*) shell_config="$HOME/.bash_profile" ;;
                *) shell_config="$HOME/.bashrc" ;;
            esac
            ;;
    esac

    # Notify (never modify) if a legacy scrippy install is present
    if [ -d "$HOME/.scrippy" ] || { [ -n "$shell_config" ] && [ -f "$shell_config" ] && grep -qF ".scrippy/commands" "$shell_config"; }; then
        echo ""
        echo "NOTICE: A legacy scrippy installation was detected (the tool is now called jef)."
        echo "  Recommended: run ./uninstall-scrippy.sh from this repository to remove it."
        echo "  Manual fallback:"
        echo "    rm -rf ~/.scrippy"
        echo "    and remove the old 'export PATH=...~/.scrippy/commands' line from your shell rc file"
        echo ""
    fi

    if [ -z "$shell_config" ]; then
        echo "Unrecognised shell '$default_shell': your shell configuration was not modified."
        echo "Add this line to your shell's startup file to use the scripts globally:"
        echo "  $path_line"
        echo "Installation complete."
        return 0
    fi

    # Add the installation directory to PATH if it's not already there
    if [ ! -f "$shell_config" ] || ! grep -qF "$commands_directory" "$shell_config"; then
        echo "$path_line" >> "$shell_config"
        echo "Added $commands_directory to PATH in $shell_config. Please restart your terminal or source the file to use the scripts."
    else
        echo "$commands_directory is already in PATH."
    fi

    echo "Installation complete. You can run the scripts globally after restarting your terminal or running 'source $shell_config'."
}

# Detect OS
case "$OSTYPE" in
    linux* | darwin*)
        install_unix
        ;;
    msys* | cygwin* | win32)
        echo "Detected Windows OS. Windows is not supported yet."
        exit 1
        ;;
    *)
        echo "Unsupported OS: $OSTYPE"
        exit 1
        ;;
esac
