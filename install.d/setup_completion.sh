#!/bin/bash

# Get the directory of the current script
if [ -n "$ZSH_VERSION" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Function to update .bashrc
update_bashrc() {
  local bashrc="$HOME/.bashrc"
  local bash_completion_dir="$HOME/.bash_completion.d"
  local completion_script="$SCRIPT_DIR/bash/roc-start_completion.sh"
  local bashrc_content

  if [ -f "$SCRIPT_DIR/bash/.bashrc" ]; then
    bashrc_content=$(cat "$SCRIPT_DIR/bash/.bashrc")
  fi

  if [ -f "$bashrc" ]; then
    if ! grep -Fxq "source ~/.bash_completion.d/roc-start_completion.sh" "$bashrc"; then
      echo -e "\n$bashrc_content" >> "$bashrc"
    fi
    mkdir -p "$bash_completion_dir"
    cp "$completion_script" "$bash_completion_dir/roc-start_completion.sh"
    echo "Installed bash completions"
  fi
}

# Function to update .zshrc
update_zshrc() {
  local zshrc="$HOME/.zshrc"
  local zsh_completion_dir="$HOME/.zsh/completions"
  local completion_script="$SCRIPT_DIR/zsh/_roc-start"
  local zshrc_content

  if [ -f "$SCRIPT_DIR/zsh/.zshrc" ]; then
    zshrc_content=$(cat "$SCRIPT_DIR/zsh/.zshrc")
  fi

  if [ -f "$zshrc" ]; then
    if ! grep -Fxq "fpath+=(~/.zsh/completions)" "$zshrc" || ! grep -Fxq "autoload -U compinit && compinit" "$zshrc"; then
      echo -e "\n$zshrc_content" >> "$zshrc"
    fi
    mkdir -p "$zsh_completion_dir"
    cp "$completion_script" "$zsh_completion_dir/_roc-start"
    echo "Installed zsh completions"
  fi
}

# Run the update functions
update_bashrc
update_zshrc
