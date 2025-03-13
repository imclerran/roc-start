#!/bin/bash

# Get the directory of the current script
if [ -n "$ZSH_VERSION" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Check if the script is running on macOS or Linux
OS_TYPE=$(uname)
if [ "$OS_TYPE" = "Darwin" ]; then
    LINKER="--linker=legacy"
elif [ "$OS_TYPE" = "Linux" ]; then
    LINKER="--linker=surgical"
else
    echo "Unsupported OS: $OS_TYPE"
    exit 1
fi

LOCAL_BIN="$HOME/.local/bin"

YELLOW="\033[33m"
RED="\033[31m"
MAGENTA="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"

# Check if $LOCAL_BIN exists and create it if it does not
[ ! -d "$LOCAL_BIN" ] && mkdir -p "$LOCAL_BIN"

OPTIMIZE="--optimize"
if [ "$1" = "-f" ] || [ "$1" = "--fast" ] || [ "$1" = "--dev" ] || [ "$1" = "--no-optimize" ] || [ "$OS_TYPE" = "Linux" ]; then
    OPTIMIZE=""
fi

SRC_DIR="src"

# Notify user that roc-start build process is starting
echo -en "Building ${MAGENTA}roc-start${RESET}..."
echo -e "${OPTIMIZE:+ (please be patient, this may take a minute or two)}"
[ -z "$OPTIMIZE" ] && echo -e "${YELLOW}WARNING:${RESET} using dev build is not recommended for general use"

roc build $SRC_DIR/main.roc --output roc-start $LINKER $OPTIMIZE > /dev/null 2>&1
# If build succeeded, copy the executable to $LOCAL_BIN and notify user
if [ -f "./roc-start" ]; then
    chmod +x ./roc-start
    mv ./roc-start $LOCAL_BIN
    echo -e "Installed ${MAGENTA}roc-start${RESET} to $LOCAL_BIN"

    # Prompt the user to install shell completions
    read -p "Do you want to install shell completions? (Y/n): " install_completions
    if [[ "$install_completions" =~ ^[Yy]$ || -z "$install_completions" ]]; then
        source "$SCRIPT_DIR/install.d/setup_completion.sh"
    fi
else
    echo -e "${RED}ERROR: ${MAGENTA}roc-start${RESET} build failed."
    exit 1
fi

# Check if the GitHub CLI (gh) is installed
if ! command -v gh > /dev/null 2>&1; then
    echo -e "${YELLOW}- NOTE: ${MAGENTA}roc-start${RESET} requires ${CYAN}gh${RESET} to be installed. Please install the GitHub CLI: https://cli.github.com"
    exit 1
fi

# Check if $LOCAL_BIN or ~/.local/bin is in the PATH
if [[ ":$PATH:" != *":$LOCAL_BIN:"* && ":$PATH:" != *":~/.local/bin:"* ]]; then
    echo -e "${YELLOW}- NOTE:${RESET} $LOCAL_BIN is not in your PATH. Please make sure to add it to your shell's configuration file (e.g. ~/.zshrc, ~/.bashrc, etc.)"
fi
