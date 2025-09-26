# disable-capslock - Caps Lock Disabler

A portable script to disable or remap Caps Lock across different Linux desktop environments and distributions.

## Features

- Works with both X11 and Wayland sessions
- Supports GNOME desktop environment on Wayland
- Persistent configuration across reboots
- Option to remap Caps Lock to Ctrl instead of disabling
- Change detection to avoid unnecessary system reconfiguration
- Support for Debian/Ubuntu keyboard-configuration system

## Usage

```bash
./disable-capslock.sh [options]

Options:
  --as-ctrl      Map Caps Lock to Ctrl instead of disabling
  --layout <layout>  Override keyboard layout (default: gb)
  --model <model>    Override keyboard model (default: pc105)
  --no-persist   Apply only to current session, don't save system defaults
```

## Example Commands

```bash
# Disable Caps Lock (default behavior)
./disable-capslock.sh

# Map Caps Lock to Ctrl
./disable-capslock.sh --as-ctrl

# Use US layout instead of GB default
./disable-capslock.sh --layout us

# Apply only to current session without persisting
./disable-capslock.sh --no-persist
```

## How It Works

The script applies changes both immediately to the current session and persistently:

1. **Immediate application**: Uses `setxkbmap` for X11 or `gsettings` for Wayland GNOME
2. **Persistence**: Updates `/etc/default/keyboard` on Debian/Ubuntu systems and uses `localectl` where available
3. **Change detection**: Only updates system configuration when changes are detected

## Session Support

- **X11**: Requires `setxkbmap` command
- **Wayland**: Requires `gsettings` and GNOME desktop environment
- **Persistence**: Works on Debian/Ubuntu systems and systems with `localectl`

The script will check for required tools and capabilities before making any changes.