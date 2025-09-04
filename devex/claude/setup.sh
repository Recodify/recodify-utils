#!/bin/bash

lncmd() {
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local COMMANDS_DIR="$SCRIPT_DIR/commands"
    local CLAUDE_DIR="./.claude"
    local TARGET_DIR="$CLAUDE_DIR/commands"

    echo "Setting up Claude Code commands..."

    # Create .claude/commands directory if it doesn't exist
    if [ ! -d "$TARGET_DIR" ]; then
        echo "Creating $TARGET_DIR directory..."
        mkdir -p "$TARGET_DIR"
    fi

    # Create symlinks for individual command files
    for cmd_file in "$COMMANDS_DIR"/*.md; do
        if [ -f "$cmd_file" ]; then
            local cmd_name=$(basename "$cmd_file")
            local target_link="$TARGET_DIR/$cmd_name"
            
            # Remove existing symlink if it exists
            if [ -L "$target_link" ]; then
                echo "Removing existing symlink: $cmd_name"
                rm "$target_link"
            elif [ -e "$target_link" ]; then
                echo "Warning: $target_link exists but is not a symlink, skipping..."
                continue
            fi
            
            echo "Creating symlink: $cmd_name"
            ln -s "$cmd_file" "$target_link"
        fi
    done

    echo "Claude Code commands setup complete!"
    echo "Commands are now available globally in any repository."
}

# If script is run directly (not sourced), execute the function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    lncmd
fi