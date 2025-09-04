usage() {
    echo "Usage: pr [base_branch] [head_branch]"
    echo "       source /path/to/github-pullrequest.sh"
    echo ""
    echo "A utility to quickly open GitHub pull request creation pages"
    echo ""
    echo "Options:"
    echo "  base_branch    Target branch for the PR (default: auto-detected from remote HEAD)"
    echo "  head_branch    Source branch for the PR (default: current branch)"
    echo ""
    echo "Examples:"
    echo "  pr                    # Create PR from current branch to default branch"
    echo "  pr develop            # Create PR from current branch to develop"
    echo "  pr main feature/foo   # Create PR from feature/foo to main"
    echo ""
    echo "Note: This script can be sourced in .bashrc or run directly"
    echo "      When sourced, it provides the 'pr' function globally"
}

# percent-encode for URLs
_urlencode() {
  local s="$1" out="" c i
  for (( i=0; i<${#s}; i++ )); do
    c=${s:i:1}
    case "$c" in
      [a-zA-Z0-9.~_-]) out+="$c" ;;
      *) out+=$(printf '%%%02X' "'$c") ;;
    esac
  done
  printf '%s' "$out"
}

pr() {
  git rev-parse --git-dir >/dev/null 2>&1 || { echo "Not a git repo."; return 1; }

  # Get remote URL and sanitize
  local origin
  origin=$(git remote get-url --push origin 2>/dev/null || git remote get-url origin) || {
    echo "Couldn't read remote 'origin' URL."; return 1;
  }
  origin=${origin%$'\n'}  # just in case of stray newline

  # Parse owner/repo from SSH or HTTPS, then strip .git
  local owner repo
  if [[ "$origin" =~ ^git@[^:]+:([^/]+)/([^/]+)(\.git)?$ ]]; then
    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"
  elif [[ "$origin" =~ ^https?://[^/]+/([^/]+)/([^/]+)(\.git)?$ ]]; then
    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"
  else
    echo "Unrecognised remote format: $origin"
    echo "Supported formats: git@host:owner/repo.git or https://host/owner/repo.git"
    return 1
  fi
  repo="${repo%.git}"

  # Branch name – bail if detached
  local branch
  if ! branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null); then
    echo "Detached HEAD. You're not on a branch, so no PR can be opened."
    return 1
  fi

  # Default base branch from remote HEAD, fallback to common defaults
  local base
  base=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')
  if [[ -z "$base" ]]; then
    # Try common default branches
    if git show-ref --verify --quiet refs/remotes/origin/main; then
      base="main"
    elif git show-ref --verify --quiet refs/remotes/origin/master; then
      base="master"
    elif git show-ref --verify --quiet refs/remotes/origin/develop; then
      base="develop"
    else
      base="main"  # Final fallback
    fi
  fi

  # Handle help flag
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    return 0
  fi

  # Optional overrides: pr <base> <head>
  [[ -n "$1" ]] && base="$1"
  [[ -n "$2" ]] && branch="$2"

  # Bail if source and target are the same
  if [[ "$branch" == "$base" ]]; then
    echo "Current branch ($branch) is the same as base ($base). Nothing to PR."
    return 1
  fi

  # Encode head for URL
  local branch_enc
  branch_enc=$(_urlencode "$branch")

  # Debug if you want:
  # echo "origin=$origin"; echo "owner=$owner"; echo "repo=$repo"; echo "base=$base"; echo "branch=$branch"

  local url="https://github.com/$owner/$repo/compare/$base...$branch_enc"

  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" >/dev/null 2>&1 &
  elif command -v open >/dev/null 2>&1; then
    open "$url" >/dev/null 2>&1 &
  else
    echo "$url"
  fi
}

# If script is run directly (not sourced), execute the function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  pr "$@"
fi