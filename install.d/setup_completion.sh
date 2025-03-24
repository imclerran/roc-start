#!/usr/bin/env sh

# Get the directory of the current script
if [ -n "$ZSH_VERSION" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
else
    # POSIX-compliant way without using BASH_SOURCE
    # Use command line arg $0 instead
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# Function to update .bashrc
update_bashrc() {
  bashrc="$HOME/.bashrc"
  bash_completion_dir="$HOME/.bash_completion.d"
  completion_script="$SCRIPT_DIR/bash/roc-start_completion.sh"
  
  if [ -f "$SCRIPT_DIR/bash/.bashrc" ]; then
    bashrc_content=$(cat "$SCRIPT_DIR/bash/.bashrc")
  fi

  if [ -f "$bashrc" ]; then
    if ! grep -F "source ~/.bash_completion.d/roc-start_completion.sh" "$bashrc" > /dev/null 2>&1; then
      printf "\n%s\n" "$bashrc_content" >> "$bashrc"
    fi
    mkdir -p "$bash_completion_dir"
    cp "$completion_script" "$bash_completion_dir/roc-start_completion.sh"
    echo "Installed bash completions"
  fi
}

# Function to update .zshrc
update_zshrc() {
  zshrc="$HOME/.zshrc"
  zsh_completion_dir="$HOME/.zsh/completions"
  completion_script="$SCRIPT_DIR/zsh/_roc-start"
  
  if [ -f "$SCRIPT_DIR/zsh/.zshrc" ]; then
    zshrc_content=$(cat "$SCRIPT_DIR/zsh/.zshrc")
  fi

  if [ -f "$zshrc" ]; then
    if ! grep -F "fpath+=(~/.zsh/completions)" "$zshrc" > /dev/null 2>&1 || 
       ! grep -F "autoload -U compinit && compinit" "$zshrc" > /dev/null 2>&1; then
      printf "\n%s\n" "$zshrc_content" >> "$zshrc"
    fi
    mkdir -p "$zsh_completion_dir"
    cp "$completion_script" "$zsh_completion_dir/_roc-start"
    echo "Installed zsh completions"
  fi
}

# Run the update functions
update_bashrc
update_zshrc
