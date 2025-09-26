#!/usr/bin/env bash
set -euo pipefail

# --- Config you might change ---
SCRIPT_SRC="./chat-paste.sh"     # path to your existing script
SRC_KEYCODE=134                 # 134 is Right Win on many ISO boards. Use `xev | grep keycode` to verify
TARGET_KEYSYM="F24"             # or F35 if you prefer
REQUIRED_PKGS=(xbindkeys xdotool xclip)

# --- Abort on Wayland ---
if [ "${XDG_SESSION_TYPE:-}" != "x11" ]; then
  echo "❌ This setup only works under X11, not Wayland."
  echo "Current session type: ${XDG_SESSION_TYPE:-unknown}"
  exit 1
fi

# --- Install dependencies if missing ---
MISSING_PKGS=()
for pkg in "${REQUIRED_PKGS[@]}"; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    MISSING_PKGS+=("$pkg")
  fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
  echo "Installing missing packages: ${MISSING_PKGS[*]}"
  sudo apt update
  sudo apt install -y "${MISSING_PKGS[@]}"
else
  echo "✅ Required packages already installed: ${REQUIRED_PKGS[*]}"
fi

# --- Paths ---
AUTOSTART_DIR="$HOME/.config/autostart"
DESKTOP_FILE="$AUTOSTART_DIR/xbindkeys.desktop"
BIN_DIR="$HOME/bin"
SCRIPT_FILE="$BIN_DIR/$SCRIPT_SRC"
XBINDSRC="$HOME/.xbindkeysrc"

# --- Sanity check: keycode exists ---
if ! xmodmap -pk | awk '{print $1}' | grep -qx "$SRC_KEYCODE"; then
  echo "⚠️  Warning: keycode $SRC_KEYCODE not found in current X keymap. Proceeding anyway."
fi

# --- Apply Xmodmap remap now and persist ---
mkdir -p "$AUTOSTART_DIR" "$BIN_DIR"
echo "keycode $SRC_KEYCODE = $TARGET_KEYSYM" > "$HOME/.Xmodmap"
xmodmap "$HOME/.Xmodmap"

# --- Copy your script into ~/bin and make executable ---
cp "$SCRIPT_SRC" "$SCRIPT_FILE"
chmod +x "$SCRIPT_FILE"

# --- Ensure xbindkeys binding exists ---
if ! grep -q "$SCRIPT_FILE" "$XBINDSRC" 2>/dev/null; then
  cat >> "$XBINDSRC" <<EOF

# Remapped key runs chatpaste
"$SCRIPT_FILE"
    $TARGET_KEYSYM
EOF
fi

# --- Autostart entry: load remap then start xbindkeys on login ---
cat > "$DESKTOP_FILE" <<'EOF'
[Desktop Entry]
Type=Application
Exec=sh -c 'xmodmap ~/.Xmodmap; xbindkeys'
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=XBindKeys
Comment=Start xbindkeys for keyboard macros
EOF

# --- Restart xbindkeys now ---
pkill -x xbindkeys 2>/dev/null || true
xbindkeys &

echo "✅ Copied $SCRIPT_SRC -> $SCRIPT_FILE"
echo "✅ Remapped keycode $SRC_KEYCODE -> $TARGET_KEYSYM via ~/.Xmodmap"
echo "✅ Bound $TARGET_KEYSYM -> $SCRIPT_FILE in ~/.xbindkeysrc"
echo "✅ Autostart created: $DESKTOP_FILE"
echo "✅ xbindkeys restarted"

echo "Tip: press the remapped key now to test. If nothing happens, confirm the keycode with: xev | grep keycode"
