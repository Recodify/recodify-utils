sudo apt update
sudo apt install -y tmux


#4) Make tmux session driven, not window spam
# Create a little launcher in ~/.local/bin/t:
#!/usr/bin/env bash
set -euo pipefail

name="${1:-main}"

if tmux has-session -t "$name" 2>/dev/null; then
  exec tmux attach -t "$name"
fi

exec tmux new -s "$name"

# install it
mkdir -p ~/.local/bin
nano ~/.local/bin/t
chmod +x ~/.local/bin/t

# Make sure ~/.local/bin is on PATH, add to ~/.bashrc if needed:
export PATH="$HOME/.local/bin:$PATH"

#5) Optional, auto attach when you open a terminal

#Add to the bottom of ~/.bashrc:

if command -v tmux >/dev/null 2>&1; then
  if [ -z "${TMUX:-}" ] && [ -t 1 ]; then
    tmux attach -t main 2>/dev/null || tmux new -s main
  fi
fi

# install x-clip
sudo apt update
sudo apt install -y xclip

# install tmp (tmux plugin manager)
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm


# install plugins from cnf

*prefix shift+I



