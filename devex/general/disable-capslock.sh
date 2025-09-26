#!/usr/bin/env bash
set -euo pipefail

# Disable or remap Caps Lock in a portable way.
# Applies immediately to the current session (X11 or Wayland GNOME),
# and persists where supported (Debian/Ubuntu keyboard-configuration, or localectl if present).
#
# Usage:
#   ./capskill.sh                # disable Caps Lock
#   ./capskill.sh --as-ctrl      # map Caps to Ctrl
#   ./capskill.sh --layout us    # override layout (default gb)
#   ./capskill.sh --model pc105  # override model
#   ./capskill.sh --no-persist   # apply now, don't touch system defaults

CAPS_OPT="caps:none"
LAYOUT="gb"
MODEL="pc105"
PERSIST=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --as-ctrl) CAPS_OPT="caps:ctrl_modifier"; shift ;;
    --layout)  LAYOUT="${2:-$LAYOUT}"; shift 2 ;;
    --model)   MODEL="${2:-$MODEL}"; shift 2 ;;
    --no-persist) PERSIST=false; shift ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }
need_sudo() { if [[ $EUID -ne 0 ]]; then sudo "$@"; else "$@"; fi; }

SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
IS_DEBIAN=false
[[ -f /etc/debian_version ]] && IS_DEBIAN=true

# --- Capability checks (no changes yet) ---
CAN_APPLY_X11=false
CAN_APPLY_WAYLAND=false

if [[ "$SESSION_TYPE" == "x11" ]] && have setxkbmap; then
  CAN_APPLY_X11=true
fi

# Only GNOME reliably honors gsettings xkb-options
if [[ "$SESSION_TYPE" == "wayland" ]] && have gsettings; then
  if gsettings list-schemas 2>/dev/null | grep -q '^org\.gnome\.desktop\.input-sources$'; then
    CAN_APPLY_WAYLAND=true
  fi
fi

if [[ "$CAN_APPLY_X11" == false && "$CAN_APPLY_WAYLAND" == false ]]; then
  echo "❌ ERROR: Cannot apply in this session."
  echo "   Session type: '$SESSION_TYPE'"
  echo "   Needed tools:"
  echo "     - X11: setxkbmap"
  echo "     - Wayland GNOME: gsettings (org.gnome.desktop.input-sources), optionally ibus"
  echo "   Aborting without making changes."
  exit 1
fi

# --- Apply immediately to the running session ---
apply_now_x11() {
  # Clear any prior XKB options, then set desired caps behavior
  setxkbmap -option || true
  echo "setxkbmap -option $CAPS_OPT"
  setxkbmap -option "$CAPS_OPT"
}

apply_now_wayland() {
  gsettings set org.gnome.desktop.input-sources xkb-options "['$CAPS_OPT']"
  if have ibus; then ibus restart || true; fi
}

echo "→ Session: $SESSION_TYPE"
if [[ "$CAN_APPLY_X11" == true ]]; then
  echo "→ Applying to current X11 session..."
  apply_now_x11
elif [[ "$CAN_APPLY_WAYLAND" == true ]]; then
  echo "→ Applying to current Wayland (GNOME) session..."
  apply_now_wayland
fi

# --- Persistence (optional and safe) ---
if [[ "$PERSIST" == true ]]; then
  # 0) Keep GNOME in sync (affects both Wayland and X11 sessions under GNOME)
  if have gsettings && gsettings list-schemas 2>/dev/null | grep -q '^org\.gnome\.desktop\.input-sources$'; then
    echo "→ Persisting user setting via gsettings (GNOME)…"
    gsettings set org.gnome.desktop.input-sources xkb-options "['$CAPS_OPT']" || true
  fi

  # 1) Debian/Ubuntu persistence via /etc/default/keyboard (change-detect)
  if [[ "$IS_DEBIAN" == true ]]; then
    echo "→ Persisting via /etc/default/keyboard (Debian/Ubuntu, change-detected only)…"
    tmpfile="$(mktemp)"
    cat >"$tmpfile" <<EOF
XKBMODEL="$MODEL"
XKBLAYOUT="$LAYOUT"
XKBVARIANT=""
XKBOPTIONS="$CAPS_OPT"
BACKSPACE="guess"
EOF
    if ! sudo cmp -s "$tmpfile" /etc/default/keyboard; then
      echo "   Change detected → updating /etc/default/keyboard"
      sudo mv "$tmpfile" /etc/default/keyboard
      if have dpkg-reconfigure; then
        sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure keyboard-configuration || true
      fi
      if have udevadm; then
        sudo udevadm trigger --subsystem-match=input --action=change || true
      fi
      if have setupcon; then
        sudo setupcon || true
      fi
    else
      echo "   No change → skipping reconfigure"
      rm -f "$tmpfile"
    fi
  fi

  # 2) If localectl exists, set X11 defaults (no effect on current session)
  if have localectl; then
    echo "→ Persisting X11 defaults via localectl…"
    sudo localectl set-x11-keymap "$LAYOUT" "$MODEL" "" "$CAPS_OPT" || true
  fi
else
  echo "→ Skipping persistence (--no-persist)."
fi

# --- Re-apply to current session AFTER persistence so nothing re-enables Caps ---
if [[ "$CAN_APPLY_X11" == true ]]; then
  echo "→ Re-applying to current X11 session…"
  setxkbmap -option || true
  setxkbmap -option "$CAPS_OPT"
elif [[ "$CAN_APPLY_WAYLAND" == true ]]; then
  echo "→ Re-applying to current Wayland (GNOME) session…"
  gsettings set org.gnome.desktop.input-sources xkb-options "['$CAPS_OPT']" || true
  have ibus && ibus restart || true
fi


echo "✅ Done. Caps behavior set to '$CAPS_OPT'."
echo "   Layout: $LAYOUT  Model: $MODEL"
echo "   Re-login may be required for DEs that cache input settings."
