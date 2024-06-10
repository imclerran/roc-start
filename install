#!/bin/zsh
LOCAL_BIN="$HOME/.local/bin"

YELLOW="\033[33m"
MAGENTA="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"

# Check if $LOCAL_BIN exists and create it if it does not
[ ! -d "$LOCAL_BIN" ] && mkdir -p "$LOCAL_BIN"

# Parse arguments
OPTIMIZE="--optimize"
if [ "$1" = "-f" ] || [ "$1" = "--fast" ] || [ "$1" = "--no-optimize" ]; then
    OPTIMIZE=""
fi

# Notify user that roc-start build process is starting
echo -e "Building ${MAGENTA}roc-start${RESET}...\n"
roc build src/main.roc --output roc-start $OPTIMIZE > /dev/null 2>&1

# If build succeeds, copy the executable to $LOCAL_BIN and notify user
if [ $? -eq 0 ]; then
    mv ./roc-start $LOCAL_BIN
    echo -e "${MAGENTA}roc-start${RESET} installed to $LOCAL_BIN"
fi

# Check if the GitHub CLI (gh) is installed
if ! command -v gh > /dev/null 2>&1; then
    echo -e "${YELLOW}- NOTE: ${MAGENTA}roc-start${RESET} requires ${CYAN}gh${RESET} to be installed. Please install the GitHub CLI: https://cli.github.com"
    exit 1
fi

# Check if $LOCAL_BIN is in the PATH
if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    echo -e "${YELLOW}- NOTE:${RESET} $LOCAL_BIN is not in your PATH. Please make sure to add it to your shell's configuration file (e.g. ~/.zshrc, ~/.bashrc, etc.)"
fi
