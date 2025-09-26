# mkpr - GitHub PR Helper

A utility script for quickly opening GitHub pull request creation pages directly from the command line or by sourcing into your shell environment.

## Features

- Automatic GitHub repository detection from git remotes
- Smart base branch detection (main, master, develop)
- Support for both SSH and HTTPS remote formats
- URL encoding for branch names with special characters
- Can be used as standalone script or sourced into .bashrc
- Cross-platform browser opening (Linux/macOS)

## Usage

```bash
# As standalone script
./devex/github/mkpr.sh [base_branch] [head_branch]

# Or source into .bashrc for global 'mkpr' command
source /path/to/recodify-utils/devex/github/mkpr.sh
mkpr [base_branch] [head_branch]

Options:
  base_branch    Target branch for the PR (default: auto-detected from remote HEAD)
  head_branch    Source branch for the PR (default: current branch)
  -h, --help     Show help message
```

## Example Commands

```bash
# Create PR from current branch to default branch
mkpr

# Create PR from current branch to develop
mkpr develop

# Create PR from feature/foo to main
mkpr main feature/foo

# Show help
mkpr --help
```

## Installation for Shell Integration

Add to your .bashrc or .zshrc:
```bash
source /path/to/recodify-utils/devex/github/mkpr.sh
```