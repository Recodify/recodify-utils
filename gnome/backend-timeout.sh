

echo $XDG_SESSION_TYPE

journalctl --user -b -p warning | tail -n 200

sudo apt update
sudo apt install xdg-desktop-portal xdg-desktop-portal-gnome

systemctl --user daemon-reload
systemctl --user restart xdg-desktop-portal xdg-desktop-portal-gnome 2>/dev/null || true

sudo mkdir -p /etc/xdg/xdg-desktop-portal
sudo tee /etc/xdg/xdg-desktop-portal/portals.conf >/dev/null <<'EOF'
[preferred]
default=gtk
EOF

systemctl --user reset-failed
systemctl --user restart xdg-desktop-portal xdg-desktop-portal-gtk


6  sudo cat  /home/sam/code/recodify-utils/gnome/backend-timeout.sh
    7  systemctl --user restart xdg-desktop-portal xdg-desktop-portal-gnome 2>/dev/null || true
    8  journalctl --user -b -p warning | tail -n 200
    9  if [ "$XDG_SESSION_TYPE" != "x11" ]; then   echo "⚠️  Wayland session detected" >&2; fi
   10  echo $XDG_SESSION_TYPE
   11  systemctl --user mask xdg-desktop-portal.service
   12  systemctl --user mask xdg-desktop-portal-gnome.service
   13  systemctl --user mask xdg-desktop-portal-gtk.service
   14  systemctl --user mask xdg-desktop-portal-kde.service
   15  sudo apt purge xdg-desktop-portal-gtk xdg-desktop-portal-kde
   16  systemctl --user status xdg-desktop-portal
   17  # Loaded: masked
   18  systemctl --user mask xdg-desktop-portal.service
   19  systemctl --user mask xdg-desktop-portal-gnome.service
   20  systemctl --user mask xdg-desktop-portal-gtk.service
   21  systemctl --user mask xdg-desktop-portal-kde.service
   22  systemctl --user mask xdg-desktop-portal.service
   23  systemctl --user mask xdg-desktop-portal-gnome.service
   24  systemctl --user mask xdg-desktop-portal-gtk.service
   25  systemctl --user mask xdg-desktop-portal-kde.service
   26  sudo apt purge xdg-desktop-portal-gtk xdg-desktop-portal-kde
   27  systemctl --user daemon-reexec
   28  systemctl --user mask xdg-desktop-portal.service
   29  sudo apt purge xdg-desktop-portal-gtk xdg-desktop-portal-kde
   30  echo $XDG_SESSION_TYPE
   31  history
