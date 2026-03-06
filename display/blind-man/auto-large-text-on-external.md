```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/auto-large-text.sh <<'EOF'
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
EOF

chmod +x ~/.local/bin/auto-large-text.sh
```


Service
```
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/auto-large-text.service <<'EOF'
[Unit]
Description=Auto toggle GNOME text scaling for external display

[Service]
Type=simple
ExecStart=/bin/bash -lc 'while true; do ~/.local/bin/auto-large-text.sh; sleep 3; done'
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
EOF
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now auto-large-text.service
systemctl --user status auto-large-text.service
```