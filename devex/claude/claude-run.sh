#!/bin/bash

claude_run_usage() {
    echo "Claude Run - Execute Claude command files without the REPL - https://github.com/recodify/recodify-utils"
    echo ""
    echo "Usage: claude-run <command-name> [args...]"
    echo "Arguments:"
    echo "  <command-name>       Name of the command file (without .md extension)"
    echo "  [args...]            Arguments to substitute into the command (\$1, \$2, etc. and \$ARGUMENTS)"
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Environment:"
    echo "  CLAUDE_BIN           Path to claude binary (default: claude)"
    echo ""
    echo "Description:"
    echo "  Executes Claude command files (.md) with argument substitution."
    echo "  Searches for commands in project (.claude/commands/) and user (~/.claude/commands/) directories."
    echo ""
    echo "Examples:"
    echo "  claude-run commit \"Fix bug in parser\""
    echo "  claude-run review main..feature-branch"

    # Exit with 0 if help was requested, 1 if usage was shown due to an error
    if [ "$1" = "help" ]; then
        return 0
    else
        return 1
    fi
}

claude-run() {
    echo "DEBUG: Entering claude-run function with $# args" >&2

    # Show usage if no arguments provided
    if [ $# -eq 0 ]; then
        echo "DEBUG: No args, showing usage" >&2
        claude_run_usage
        return 1
    fi

    echo "DEBUG: Setting options" >&2
    # Set options only for this function - disable 'set -e' to prevent shell exit
    local -
    set -uo pipefail

    local CLAUDE_BIN="${CLAUDE_BIN:-claude}"

    # Local helper functions
    err() { printf '%s\n' "$*" >&2; }
    die() { echo "DEBUG: die() called with: $*" >&2; err "$*"; return 1; }

    # Show help if requested
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        echo "DEBUG: Showing help" >&2
        claude_run_usage "help"
        return 0
    fi

    echo "DEBUG: Processing arguments" >&2
    local name="${1:-}"; shift || true
    echo "DEBUG: Command name: '$name'" >&2
    [[ -n "$name" ]] || die "Usage: claude-run <command-name> [args...]"

    echo "DEBUG: Validating command name" >&2
    # Validate command name to prevent path traversal
    if [[ "$name" =~ [./] || "$name" =~ ^- ]]; then
        die "Invalid command name: '$name' (no paths, dots, or leading dashes allowed)"
    fi

    # 1) Find project root that contains .claude/commands by walking up
    find_project_root() {
        local dir="$PWD"
        while [[ "$dir" != "/" ]]; do
            if [[ -d "$dir/.claude/commands" ]]; then
                printf '%s\n' "$dir"
                return 0
            fi
            dir="$(dirname "$dir")"
        done
        return 1
    }

    local project_root="$(find_project_root || true)"

    # 2) Resolve command file: project-level first, then user-level
    echo "DEBUG: Looking for command file" >&2
    local cmd_file=""
    if [[ -n "$project_root" ]] && [[ -f "$project_root/.claude/commands/$name.md" ]]; then
        cmd_file="$project_root/.claude/commands/$name.md"
        echo "DEBUG: Found project command: $cmd_file" >&2
    elif [[ -f "$HOME/.claude/commands/$name.md" ]]; then
        cmd_file="$HOME/.claude/commands/$name.md"
        echo "DEBUG: Found user command: $cmd_file" >&2
    else
        echo "DEBUG: Command not found, calling die" >&2
        die "Command not found: $name. Searched: ${project_root:-<no project>}/.claude/commands/$name.md and $HOME/.claude/commands/$name.md"
    fi

    # 3) Parse front-matter (optional) and body
    # Front-matter format:
    # ---
    # model: claude-3.5-sonnet
    # allowed-tools: Bash(git status:*), Bash(git diff:*)
    # ---
    # <prompt text using $1, $2, $ARGUMENTS>
    parse_cmd_file() {
        local file="$1"
        local in_fm=0
        local fm model="" tools="" mode=""
        local body=''

        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ $in_fm -eq 0 && $line == '---' ]]; then
                in_fm=1
                continue
            fi
            if [[ $in_fm -eq 1 && $line == '---' ]]; then
                in_fm=2
                continue
            fi
            if [[ $in_fm -eq 1 ]]; then
                fm+="$line"$'\n'
            else
                body+="$line"$'\n'
            fi
        done < "$file"

        # Extract simple keys from fm if present
        if [[ -n "${fm:-}" ]]; then
            # crude YAML parsing good enough for simple k: v lines
            while IFS= read -r kv || [[ -n "$kv" ]]; do
                # skip empties and comments
                [[ -z "$kv" || "$kv" =~ ^[[:space:]]*# ]] && continue

                # Validate line format (key: value)
                [[ "$kv" =~ ^[[:space:]]*[a-zA-Z][a-zA-Z0-9_-]*[[:space:]]*:[[:space:]]*.* ]] || continue

                key="${kv%%:*}"
                val="${kv#*:}"
                key="$(printf '%s' "$key" | tr -d '[:space:]')"
                val="$(printf '%s' "$val" | sed 's/^[[:space:]]*//')"

                # Validate key contains only safe characters
                [[ "$key" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]] || continue

                case "$key" in
                    model)
                        # Validate model name format
                        [[ "$val" =~ ^[a-zA-Z0-9._-]+$ ]] && model="$val" ;;
                    allowed-tools)
                        # Basic validation for tools format
                        tools="$val" ;;
                    mode)
                        # Store mode for execution flags
                        mode="$val" ;;
                esac
            done <<< "$fm"
        fi

        printf '%s\n' "$model"
        printf '%s\n' "$tools"
        printf '%s\n' "$mode"
        printf '%s'   "$body"
    }

    mapfile -t parsed < <(parse_cmd_file "$cmd_file")
    local model="${parsed[0]}"
    local allowed_tools="${parsed[1]}"
    local mode="${parsed[2]}"
    # Join the remainder back as body (handles newlines)
    local body="$(printf '%s\n' "${parsed[@]:3}")"

    # 4) Hydrate arguments: $1..$N and $ARGUMENTS
    local args=( "$@" )
    local prompt="$body"

    # Safe argument substitution function
    safe_substitute() {
        local text="$1" placeholder="$2" replacement="$3"
        # Use printf to safely handle special characters
        printf '%s\n' "$text" | awk -v placeholder="$placeholder" -v replacement="$replacement" '{
            gsub(placeholder, replacement)
            print
        }'
    }

    # Replace positional arguments safely
    for i in "${!args[@]}"; do
        local n=$((i+1))
        prompt="$(safe_substitute "$prompt" "\\$${n}" "${args[$i]}")"
    done

    # Replace $ARGUMENTS safely
    local all_args="${*:-}"
    prompt="$(safe_substitute "$prompt" '\\$ARGUMENTS' "$all_args")"

    # 5) Safety checks
    [[ -n "${prompt//[[:space:]]/}" ]] || die "Hydrated prompt is empty. Check your front-matter markers and body."
    command -v "$CLAUDE_BIN" >/dev/null 2>&1 || die "Cannot find '$CLAUDE_BIN' in PATH."

    # Validate prompt length (prevent excessive prompts)
    if [[ ${#prompt} -gt 1000000 ]]; then
        die "Prompt too large (${#prompt} chars). Maximum 1MB allowed."
    fi

    # Validate model name if specified
    if [[ -n "$model" && ! "$model" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        die "Invalid model name: '$model'"
    fi

    # 6) Build flags and run
    local flags=( -p )
    [[ -n "$model" ]] && flags+=( --model "$model" )

    # Add mode-specific flags
    echo "DEBUG: --permission-mode $mode"
    flags+=( --permission-mode $mode )

    # Some CLAUDE CLIs use --allowedTools, others don't. Pass only if set.
    if [[ -n "$allowed_tools" ]]; then
        flags+=( --allowedTools "$allowed_tools" )
    fi

    err "→ Using: $cmd_file"
    err "→ Model: ${model:-default}"
    err "→ Tools: ${allowed_tools:-none}"
    err "→ Mode: ${mode:-default}"
    err "→ Prompt chars: ${#prompt}"

    echo "DEBUG: About to execute Claude" >&2

    # Create a temporary file for capturing output
    local temp_output=$(mktemp)
    local temp_error=$(mktemp)

    # Start Claude in background with output redirection
    "$CLAUDE_BIN" "${flags[@]}" "$prompt" > "$temp_output" 2> "$temp_error" &
    local claude_pid=$!

    # Show progress while Claude runs
    local spinner_chars="/-\|"
    local spinner_pos=0
    echo -n "Processing" >&2

    while kill -0 "$claude_pid" 2>/dev/null; do
        printf "\rProcessing %c" "${spinner_chars:$spinner_pos:1}" >&2
        spinner_pos=$(( (spinner_pos + 1) % 4 ))
        sleep 0.5

        # Show any error output immediately
        if [[ -s "$temp_error" ]]; then
            echo >&2  # New line after spinner
            cat "$temp_error" >&2
            > "$temp_error"  # Clear the temp file
        fi
    done

    # Wait for Claude to finish and get exit code
    wait "$claude_pid"
    local claude_exit_code=$?

    echo >&2  # New line after spinner

    # Show final output
    if [[ -s "$temp_output" ]]; then
        cat "$temp_output"
    fi

    # Show any remaining error output
    if [[ -s "$temp_error" ]]; then
        cat "$temp_error" >&2
    fi

    # Cleanup
    rm -f "$temp_output" "$temp_error"

    if [[ $claude_exit_code -ne 0 ]]; then
        echo "DEBUG: Claude exited with code $claude_exit_code" >&2
        return 0  # Always return success to prevent shell exit
    fi
    echo "DEBUG: Claude completed successfully" >&2
}

# If script is run directly (not sourced), execute the function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    claude-run "$@"
fi