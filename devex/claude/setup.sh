#!/bin/bash

lncmd() {
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local COMMANDS_DIR="$SCRIPT_DIR/commands"
    local CLAUDE_DIR="$HOME/.claude"
    local TARGET_DIR="$CLAUDE_DIR/commands"

    echo "Setting up Claude Code commands..."

    # Create .claude/commands directory if it doesn't exist
    if [ ! -d "$TARGET_DIR" ]; then
        echo "Creating $TARGET_DIR directory..."
        mkdir -p "$TARGET_DIR"
    fi

    # Create symlink to global commands
    local GLOBAL_LINK="$TARGET_DIR/global"

    if [ -L "$GLOBAL_LINK" ]; then
        echo "Removing existing global symlink..."
        rm "$GLOBAL_LINK"
    elif [ -e "$GLOBAL_LINK" ]; then
        echo "Error: $GLOBAL_LINK exists but is not a symlink"
        return 1
    fi

    echo "Creating symlink: $GLOBAL_LINK -> $COMMANDS_DIR"
    ln -s "$COMMANDS_DIR" "$GLOBAL_LINK"

    echo "Claude Code commands setup complete!"
    echo "Commands are now available globally in any repository."
}

# If script is run directly (not sourced), execute the function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    lncmd
fi