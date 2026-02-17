#!/usr/bin/env bash

# Render Mermaid code blocks in Markdown to SVGs in ./imgs next to each .md
# and inject <img src="imgs/<name>.svg"> after each mermaid block if missing.
#
# Usage:
#   ./render-mermaid.sh path/to/file.md
#   ./render-mermaid.sh path/to/docs
#   ./render-mermaid.sh path/to/docs path/to/other.md
#
# Notes:
# - SVG names are: <md_basename>_m<index>.svg  (index starts at 1 per file)
# - Only renders if SVG is missing
# -#!/usr/bin/env bash
set -euo pipefail

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 2; }; }
need_cmd awk
need_cmd perl
need_cmd mmdc

collect_md_files() {
  local p
  for p in "$@"; do
    if [[ -d "$p" ]]; then
      find "$p" -type f -name '*.md' -print
    elif [[ -f "$p" ]]; then
      echo "$p"
    else
      echo "Path not found: $p" >&2
      exit 2
    fi
  done
}

render_one_file() {
  local md="$1"
  local dir base imgs
  dir="$(cd "$(dirname "$md")" && pwd)"
  base="$(basename "$md" .md)"
  imgs="$dir/imgs"
  mkdir -p "$imgs"

  (
    set -euo pipefail
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "${tmpdir:-}"' EXIT

  # Extract each ```mermaid block into tmpdir/block_<n>.mmd
 # Extract each mermaid fenced block into tmpdir/block_<n>.mmd
count="$(
  awk -v outdir="$tmpdir" '
    function ltrim(s){ sub(/^[ \t]+/, "", s); return s }
    BEGIN { inblock=0; idx=0; fence="" }

    {
      line = $0
      t = ltrim(line)

      # Opening fence: ```mermaid or ````mermaid (3+ backticks), allow indentation
      if (!inblock && t ~ /^`{3,}mermaid[ \t]*$/) {
        inblock = 1
        idx++
        match(t, /^`{3,}/)
        fence = substr(t, RSTART, RLENGTH)
        next
      }

      # Closing fence: same number of backticks as opener (or more), allow indentation
      if (inblock) {
        tt = ltrim(line)

        # Close if line is backticks only, length >= opener fence length
        if (tt ~ /^`{3,}[ \t]*$/) {
          match(tt, /^`{3,}/)
          closer = substr(tt, RSTART, RLENGTH)
          if (length(closer) >= length(fence)) {
            inblock = 0
            fence = ""
            next
          }
        }

        print line > (outdir "/block_" idx ".mmd")
      }
    }

    END { print idx }
  ' "$md"
)"

  if [[ "${count:-0}" -eq 0 ]]; then
    return 0
  fi

  # Render missing SVGs
  local i mmd svg
  for i in $(seq 1 "$count"); do
    mmd="$tmpdir/block_${i}.mmd"
    svg="$imgs/${base}_m${i}.svg"
    if [[ ! -s "$svg" ]]; then
      echo "Render: $md block $i -> $svg"
      #mmdc -i "$mmd" -o "$svg" >/dev/null
      mmdc -c "${MERMAID_CONFIG:-$dir/mermaid-config.json}" -i "$mmd" -o "$svg" >/dev/null

    fi
  done

  # Inject <img> after each mermaid block if not already present immediately after
  local tmpout
  tmpout="$tmpdir/out.md"

  MD_BASE="$base" perl -0777 -pe '
    my $base = $ENV{MD_BASE};
    my $n = 0;

    s{
      ```mermaid[ \t]*\n
      (.*?)
      ```[ \t]*\n
    }{
      $n++;
      my $block = $1;
      my $img = qq{<img src="imgs/${base}_m${n}.svg" alt="mermaid diagram ${n}">\n};

      my $replacement = "```mermaid\n$block```\n";

      # Peek at what follows this block in the original string.
      # If the next non-empty line is already this exact img tag, do nothing.
      my $pos = pos($_) // 0;
      my $rest = substr($_, $pos);

      if ($rest =~ /^\s*\Q$img\E/s) {
        $replacement
      } else {
        $replacement . $img
      }
    }gsex
  ' "$md" > "$tmpout"

  if ! cmp -s "$md" "$tmpout"; then
    echo "Update: $md (inject img tags)"
    mv "$tmpout" "$md"
  fi
  )
}

main() {
  if [[ "${#@}" -lt 1 ]]; then
    echo "Usage: $0 <md file or dir> ..." >&2
    exit 2
  fi

  local f
  while IFS= read -r f; do
    render_one_file "$f"
  done < <(collect_md_files "$@")
}

main "$@"
