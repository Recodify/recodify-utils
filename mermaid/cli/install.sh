npm install -g @mermaid-js/mermaid-cli
export PUPPETEER_EXECUTABLE_PATH=/opt/google/chrome/chrome

sudo apt update
sudo apt install -y librsvg2-bin chafa

rsvg-convert -w 180 -o /tmp/diag.png docs/imgs/architecture_m1.svg && chafa -s 180x0 /tmp/diag.png

svg_to_ansi_file () {
  local svg="${1:?svg path required}"
  local cols="${2:-160}"
  local out="${3:-${svg}.ansi}"
  local tmp
  tmp="$(mktemp --suffix=.png)"
  rsvg-convert -w $((cols * 8)) -o "$tmp" "$svg" || { rm -f "$tmp"; return 1; }
  chafa -s "${cols}x0" "$tmp" > "$out"
  rm -f "$tmp"
}




svgansi docs/imgs/architecture_m1.svg 160
