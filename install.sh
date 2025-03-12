#!/bin/zsh
LOCAL_BIN="$HOME/.local/bin"

YELLOW="\033[33m"
RED="\033[31m"
MAGENTA="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"

# Check if $LOCAL_BIN exists and create it if it does not
[ ! -d "$LOCAL_BIN" ] && mkdir -p "$LOCAL_BIN"

OPTIMIZE="--optimize"
if [ "$1" = "-f" ] || [ "$1" = "--fast" ] || [ "$1" = "--dev" ] || [ "$1" = "--no-optimize" ]; then
    OPTIMIZE=""
fi

SRC_DIR="src"

# Notify user that roc-start build process is starting
echo -en "Building ${MAGENTA}roc-start${RESET}..."
echo -e "${OPTIMIZE:+ (please be patient, this may take a minute or two)}"
[ -z "$OPTIMIZE" ] && echo -e "${YELLOW}WARNING:${RESET} using dev build is not recommended for general use"

roc build $SRC_DIR/main.roc --output roc-start $OPTIMIZE > /dev/null 2>&1
# If build succeeded, copy the executable to $LOCAL_BIN and notify user
if [ -f "./roc-start" ]; then
    mv ./roc-start $LOCAL_BIN
    echo -e "Installed ${MAGENTA}roc-start${RESET} to $LOCAL_BIN"
else
    echo -e "${RED}ERROR: ${MAGENTA}roc-start${RESET} build failed."
    exit 1
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
