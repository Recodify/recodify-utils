# sudo apt install pipx
# pipx install coolname

plan() {
  local slug  
  local dir="${1:-./plans}"
  slug="$(coolname)"  
  touch "$dir/${slug}.md"
  echo "created: $(realpath "./${slug}.md")"
}

follow() {
  local slug
  local dir="${1:-./plans}"  
  slug="${2:?usage: follow <plandir>  <slug>}"
  touch "$dir /${slug}.followup.md"
  echo "created: $(realpath "./${slug}.followup.md")"
}
