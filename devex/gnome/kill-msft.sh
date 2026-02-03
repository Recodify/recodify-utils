#!/usr/bin/env bash
set -euo pipefail

# Fix GNOME on Ubuntu 24+: disable Ubuntu "Tiling Assistant" annoyances
# - Stop "fill the other side" popup after Super+Left/Right
# - Stop "raise the whole tile group" when focusing one tiled window

schema="org.gnome.shell.extensions.tiling-assistant"

need_cmd() { command -v "$1" >/dev/null 2>&1; }

say() { printf '%s\n' "$*"; }

if ! need_cmd gsettings; then
  echo "ERROR: gsettings not found (are you on GNOME?)" >&2
  exit 1
fi

# Only apply if the schema exists on this machine
if ! gsettings list-schemas | grep -qx "$schema"; then
  say "Schema not found: $schema"
  say "Nothing to do. (You might not have Ubuntu's Tiling Assistant installed.)"
  exit 0
fi

apply_if_key_exists() {
  local key="$1"
  local value="$2"
  if gsettings list-keys "$schema" | grep -qx "$key"; then
    gsettings set "$schema" "$key" "$value"
    say "Set: $schema $key = $(gsettings get "$schema" "$key")"
  else
    say "Skip: $schema has no key '$key' on this system"
  fi
}

say "Applying GNOME tiling sanity tweaks…"

apply_if_key_exists "enable-tiling-popup" "false"
apply_if_key_exists "enable-raise-tile-group" "false"

say "Done."
say "If it still feels weird, list current settings with:"
say "  gsettings list-recursively $schema"