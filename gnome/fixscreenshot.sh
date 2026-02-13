for k in screenshot screenshot-clip area-screenshot area-screenshot-clip window-screenshot window-screenshot-clip; do
  gsettings set org.gnome.settings-daemon.plugins.media-keys "$k" "[]" 2>/dev/null || true
done

#sudo apt update
#sudo apt install -y flameshot
flameshot gui -c


set -euo pipefail

schema="org.gnome.settings-daemon.plugins.media-keys"
base="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"

list="$(gsettings get "$schema" custom-keybindings)"
list="${list#@as }"

i=0
while [[ "$list" == *"custom${i}/"* ]]; do i=$((i+1)); done
path="${base}custom${i}/"

if [[ "$list" == "[]" ]]; then
  newlist="['$path']"
else
  newlist="${list%]},"" '$path']"
fi

gsettings set "$schema" custom-keybindings "$newlist"
gsettings set "${schema}.custom-keybinding:${path}" name "Flameshot area to clipboard"
gsettings set "${schema}.custom-keybinding:${path}" command "flameshot gui -c"
gsettings set "${schema}.custom-keybinding:${path}" binding "<Ctrl><Shift>Print"