#!/usr/bin/env bash

mkpr_azdo_usage() {
  echo "mkpr-azdo - Open Azure DevOps Pull Request create page"
  echo ""
  echo "Usage: mkpr-azdo [base_branch] [head_branch]"
  echo "       source /path/to/mkpr-azdo.sh"
  echo ""
  echo "Defaults:"
  echo "  base_branch = remote HEAD (or main/master/develop fallback)"
  echo "  head_branch = current branch"
  echo ""
}

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

mkpr_azdo() {

  [[ "$1" == "-h" || "$1" == "--help" ]] && { mkpr_azdo_usage; return 0; }

  git rev-parse --git-dir >/dev/null 2>&1 || { echo "Not a git repo."; return 1; }

  local origin
  origin=$(git remote get-url --push origin 2>/dev/null || git remote get-url origin) || {
    echo "Couldn't read remote origin URL."
    return 1
  }

  origin=${origin%$'\n'}

  local org project repo host

  # SSH format: git@ssh.dev.azure.com:v3/org/project/repo
  if [[ "$origin" =~ ^git@ssh\.dev\.azure\.com:v3/([^/]+)/([^/]+)/([^/]+)(\.git)?$ ]]; then
    org="${BASH_REMATCH[1]}"
    project="${BASH_REMATCH[2]}"
    repo="${BASH_REMATCH[3]}"
    host="dev.azure.com"

  # HTTPS: https://dev.azure.com/org/project/_git/repo
  elif [[ "$origin" =~ ^https?://([^/]+)/([^/]+)/([^/]+)/_git/([^/]+)$ ]]; then
    host="${BASH_REMATCH[1]}"
    org="${BASH_REMATCH[2]}"
    project="${BASH_REMATCH[3]}"
    repo="${BASH_REMATCH[4]}"

  # Legacy VisualStudio.com: https://org.visualstudio.com/project/_git/repo
  elif [[ "$origin" =~ ^https?://([^.]+)\.visualstudio\.com/([^/]+)/_git/([^/]+)$ ]]; then
    host="${BASH_REMATCH[1]}.visualstudio.com"
    org="${BASH_REMATCH[1]}"
    project="${BASH_REMATCH[2]}"
    repo="${BASH_REMATCH[3]}"

  elif [[ "$origin" =~ ^https?://([^/]+)/tfs/([^/]+)/([^/]+)/_git/([^/]+)$ ]]; then
    host="${BASH_REMATCH[1]}"
    collection="${BASH_REMATCH[2]}"
    project="${BASH_REMATCH[3]}"
    repo="${BASH_REMATCH[4]}"

  else
    echo "Unrecognised Azure DevOps remote URL:"
    echo "  $origin"
    return 1
  fi

  repo="${repo%.git}"

  local branch
  if ! branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null); then
    echo "Detached HEAD — cannot determine source branch."
    return 1
  fi

  local base
  base=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')
  [[ -z "$base" ]] && {
    if git show-ref --verify --quiet refs/remotes/origin/main; then base="main";
    elif git show-ref --verify --quiet refs/remotes/origin/master; then base="master";
    elif git show-ref --verify --quiet refs/remotes/origin/develop; then base="develop";
    else base="main";
    fi
  }

  [[ -n "$1" ]] && base="$1"
  [[ -n "$2" ]] && branch="$2"

  if [[ "$branch" == "$base" ]]; then
    echo "Source and target branch are the same ($branch)."
    return 1
  fi

  local src_enc tgt_enc
  src_enc=$(_urlencode "$branch")
  tgt_enc=$(_urlencode "$base")

  if [[ -n "$collection" ]]; then
    # On-prem TFS URL
    url="https://$host/tfs/$collection/$project/_git/$repo/pullrequestcreate?sourceRef=$src_enc&targetRef=$tgt_enc"
  else
    # Azure DevOps Services URL
    url="https://$host/$org/$project/_git/$repo/pullrequestcreate?sourceRef=$src_enc&targetRef=$tgt_enc"
  fi

  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" >/dev/null 2>&1 &
  elif command -v open >/dev/null 2>&1; then
    open "$url" >/dev/null 2>&1 &
  else
    echo "$url"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  mkpr_azdo "$@"
fi
