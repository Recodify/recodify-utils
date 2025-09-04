#!/usr/bin/env bash
set -euo pipefail

# Resolve this script's real dir and index.sh absolute path
SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INDEX_ABS="$SCRIPT_DIR/index.sh"
ROOT_DIR="$(dirname -- "$INDEX_ABS")"

# Choose profile
if [ -n "${ZSH_VERSION:-}" ] || [[ "${SHELL:-}" =~ zsh$ ]]; then
  PROFILE_FILE="$HOME/.zshrc"
elif [ -n "${BASH_VERSION:-}" ] || [[ "${SHELL:-}" =~ bash$ ]]; then
  PROFILE_FILE="$HOME/.bashrc"
else
  # Fallback to .profile for unknown login shells
  PROFILE_FILE="$HOME/.profile"
fi

echo "Installing recodify-utils to $PROFILE_FILE..."

# Markers so we can update in place without dupes
BEGIN="# >>> recodify-utils begin >>>"
END="# <<< recodify-utils end <<<"

BLOCK="$BEGIN
# Set root and source utils (POSIX)
export RECODIFY_ROOT='${ROOT_DIR}'
if [ -f \"\$RECODIFY_ROOT/index.sh\" ]; then
  . \"\$RECODIFY_ROOT/index.sh\"
fi
$END"

# If a previous block exists, replace it; else append
if grep -Fqx "$BEGIN" "$PROFILE_FILE" 2>/dev/null; then
  # Replace everything between markers
  tmpfile="$(mktemp)"
  awk -v begin="$BEGIN" -v end="$END" -v block="$BLOCK" '
    BEGIN { inblock=0 }
    $0==begin { print block; inblock=1; next }
    $0==end { inblock=0; next }
    inblock==0 { print }
  ' "$PROFILE_FILE" >"$tmpfile"
  mv "$tmpfile" "$PROFILE_FILE"
else
  {
    echo ""
    echo "$BLOCK"
  } >> "$PROFILE_FILE"
fi

echo "Done. Reload with: . \"$PROFILE_FILE\""
