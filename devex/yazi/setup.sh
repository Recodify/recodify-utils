wget https://github.com/sxyazi/yazi/releases/download/v26.1.22/yazi-x86_64-unknown-linux-musl.deb
sudo dpkg -i yazi-x86_64-unknown-linux-musl.deb

# add this to bashrc:

export EDITOR=nano
export VISUAL=nano

# install fonts:

../hack/setup.sh

# optional, have termimal track yazi on exit. add this to bashrc and invoke yazi with `y`
y() {
  local tmp="$(mktemp -t yazi-cwd.XXXXXX)"
  yazi "$@" --cwd-file="$tmp"
  if [ -f "$tmp" ]; then
    cd "$(cat "$tmp")"
    rm -f "$tmp"
  fi
}