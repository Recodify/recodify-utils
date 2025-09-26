# Claude Code Commands

A collection of custom Claude Code commands that can be globally available across repositories.

## Features

- Reusable commands for common development workflows
- Global availability through symlink setup
- Consistent command behavior across projects

## Available Commands

- **commit** - Crafts commit messages and runs `git commit` with staged changes

## Installation

### Automated Setup

Run the setup script from within any repository to make commands available for that project:

```bash
/path/to/recodify-utils/devex/claude/setup.sh
```

### Manual Setup

Alternatively, create the symlink manually from within your target repository:

```bash
# Create .claude/commands directory if it doesn't exist
mkdir -p .claude/commands

# Symlink commands to global subfolder
ln -s /path/to/recodify-utils/devex/claude/commands .claude/commands/global
```

Once installed in a repository, these commands will be available to Claude Code for that project.