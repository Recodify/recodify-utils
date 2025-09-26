#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
CLICK_SUBMIT="${CLICK_SUBMIT:-0}"   # 0 = use Enter (default), 1 = click button
CLICK_OFFSET_X=70                   # pixels from right edge (if CLICK_SUBMIT=1)
CLICK_OFFSET_Y=70                   # pixels from bottom edge (if CLICK_SUBMIT=1)

# --- Get selection (PRIMARY then CLIPBOARD) ---
SEL="$(xclip -o -selection primary 2>/dev/null || true)"
if [ -z "${SEL:-}" ]; then
  SEL="$(xclip -o -selection clipboard 2>/dev/null || true)"
fi
if [ -z "${SEL:-}" ]; then
  notify-send "ChatPaste" "No selection to send"
  exit 0
fi

# --- Focus or open ChatGPT window ---
if ! xdotool search --onlyvisible --name "ChatGPT" windowactivate; then
  xdg-open "https://chat.openai.com/" >/dev/null 2>&1 &
  sleep 2
  xdotool search --onlyvisible --name "ChatGPT" windowactivate || true
  sleep 0.2
fi

# --- Paste into input box ---
printf %s "$SEL" | xclip -selection clipboard
xdotool key --clearmodifiers ctrl+v
sleep 0.08

# --- Submit ---
if [ "$CLICK_SUBMIT" -eq 1 ]; then
  # Click the Send button (brittle, only if explicitly requested)
  WIN_ID="$(xdotool getactivewindow)"
  eval "$(xdotool getmouselocation --shell)"
  MOUSE_X_SAVE="$X"; MOUSE_Y_SAVE="$Y"

  eval "$(xdotool getwindowgeometry --shell "$WIN_ID")"
  CX=$((WIDTH - CLICK_OFFSET_X))
  CY=$((HEIGHT - CLICK_OFFSET_Y))

  xdotool mousemove --window "$WIN_ID" "$CX" "$CY" click 1
  xdotool mousemove "$MOUSE_X_SAVE" "$MOUSE_Y_SAVE" || true
else
  # Safer default: just press Enter
  xdotool key --clearmodifiers Return
fi
