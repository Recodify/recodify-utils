#!/usr/bin/env bash
set -euo pipefail

SCALE_EXTERNAL="1.25"
SCALE_LAPTOP="1.0"

if xrandr --query | grep -q '^DP-5 connected'; then
    current="$(gsettings get org.gnome.desktop.interface text-scaling-factor)"
    if [ "$current" != "$SCALE_EXTERNAL" ]; then
        gsettings set org.gnome.desktop.interface text-scaling-factor "$SCALE_EXTERNAL"
    fi
else
    current="$(gsettings get org.gnome.desktop.interface text-scaling-factor)"
    if [ "$current" != "$SCALE_LAPTOP" ]; then
        gsettings set org.gnome.desktop.interface text-scaling-factor "$SCALE_LAPTOP"
    fi
fi