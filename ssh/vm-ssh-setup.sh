#!/usr/bin/env bash
set -euo pipefail

setup_ssh_host() {
  local host_alias="$1"
  local host_name="$2"
  local host_user="${3:-$USER}"

  local ssh_dir="$HOME/.ssh"
  local ssh_key="$ssh_dir/id_${host_alias}"
  local ssh_config="$ssh_dir/config"

  if [[ -z "$host_alias" || -z "$host_name" ]]; then
    echo "Usage: ssh-setup <alias> <hostname> [user]" >&2
    exit 1
  fi

  echo "== SSH key + config setup for host: $host_alias =="

  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"

  if [[ ! -f "$ssh_key" ]]; then
    echo "Generating SSH key: $ssh_key"
    ssh-keygen -t ed25519 -f "$ssh_key" -C "$host_user@$host_alias" -N ""
  else
    echo "SSH key already exists: $ssh_key"
  fi

  touch "$ssh_config"
  chmod 600 "$ssh_config"

  if ! grep -qE "^Host[[:space:]]+$host_alias\$" "$ssh_config"; then
    echo "Adding SSH config entry for $host_alias..."

    cat >> "$ssh_config" <<EOF

Host $host_alias
  HostName $host_name
  User $host_user
  IdentityFile $ssh_key
  IdentitiesOnly yes
EOF
  else
    echo "SSH config entry for $host_alias already exists."
  fi

  echo "Copying SSH key to VM, you may be prompted once..."
  ssh-copy-id -i "${ssh_key}.pub" "$host_alias"

  echo "Testing SSH connection..."
  ssh -o BatchMode=yes "$host_alias" "echo 'SSH OK'"

  echo
  echo "Done. Connect with: ssh $host_alias"
}

setup_ssh_host "$@"