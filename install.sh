#!/bin/bash

# Function to install on Linux and MacOS
install_unix() {
    echo "Detected Unix-based OS. Installing..."

    # Ensure git is installed
    if ! command -v git &> /dev/null; then
        echo "Git is required. Please install Git first."
        exit 1
    fi

    # Define installation directory in the user's home directory
    installation_directory="$HOME/.jef"
    # Define the commands directory in the user's home directory
    commands_directory="$installation_directory/commands"

    # Remove the installation directory if it exists
    rm -rf "$installation_directory"

    # Create the directory if it doesn't exist
    mkdir -p "$installation_directory"

    # Copy scripts to the installation directory
    rsync -av --exclude '.git/' --exclude '.gitignore' . "$installation_directory" # copy all files to the installation directory

    chmod +x "$commands_directory"/jef*.sh # Make the jef prefixed scripts executable

    # Strip the .sh extension so the scripts run as commands (jef, jef-push, ...)
    for file in "$commands_directory"/jef*.sh; do
        mv "$file" "${file%.sh}"
    done

    default_shell="$(basename "$SHELL")"
    shell_config="$HOME/.${default_shell}rc"  # Modify based on the user's shell (e.g., .zshrc for zsh)

    # Notify (never modify) if a legacy scrippy install is present
    if [ -d "$HOME/.scrippy" ] || { [ -f "$shell_config" ] && grep -qF ".scrippy/commands" "$shell_config"; }; then
        echo ""
        echo "NOTICE: A legacy scrippy installation was detected (the tool is now called jef)."
        echo "  Recommended: run ./uninstall-scrippy.sh from this repository to remove it."
        echo "  Manual fallback:"
        echo "    rm -rf ~/.scrippy"
        echo "    and remove the old 'export PATH=...~/.scrippy/commands' line from $shell_config"
        echo ""
    fi

    # Add the installation directory to PATH if it's not already there
    if [ ! -f "$shell_config" ] || ! grep -q "$commands_directory" "$shell_config"; then
        echo "export PATH=\"\$PATH:$commands_directory\"" >> "$shell_config"
        echo "Added $commands_directory to PATH in $shell_config. Please restart your terminal or source the file to use the scripts."
    else
        echo "$commands_directory is already in PATH."
    fi

    echo "Installation complete. You can run the scripts globally after restarting your terminal or running 'source $shell_config'."
}

# Function to install on Windows
install_windows() {
    # echo "Detected Windows OS. Installing..."
    echo "Detected Windows OS. No supported at the moment"
    exit

    # Check if PowerShell is available
    if ! command -v powershell.exe &> /dev/null; then
        echo "PowerShell is required but not found. Please install PowerShell."
        exit 1
    fi

    # Invoke the PowerShell script for installation on Windows
    powershell.exe -ExecutionPolicy Bypass -File ./install.ps1
}

# Detect OS
case "$OSTYPE" in
    linux* | darwin*)
        install_unix
        ;;
    msys* | cygwin* | win32)
        install_windows
        ;;
    *)
        echo "Unsupported OS: $OSTYPE"
        exit 1
        ;;
esac
