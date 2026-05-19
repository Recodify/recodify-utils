#!/usr/bin/env bash
set -euo pipefail

HOSTS="${1:-./hosts.csv}"
OUT="${2:-./reports/resources/resource-report$(date -u +"%Y%m%dT%H%M%SZ").csv}"

SSH_OPTS=(
  -q
  -o BatchMode=yes
  -o ConnectTimeout=8
  -o LogLevel=ERROR
)

status_ge() {
  local actual="${1:-}"
  local want="${2:-}"
  local tolerance_percent="${3:-0}"

  if [[ ! "$want" =~ ^[0-9]+$ ]]; then
    echo "N/A"
  elif [[ ! "$actual" =~ ^[0-9]+$ ]]; then
    echo "ERR"
  else
    local min_ok
    min_ok="$(
      awk -v want="$want" -v tol="$tolerance_percent" \
        'BEGIN { printf "%.0f", want * (1 - tol / 100) }'
    )"

    if (( actual >= min_ok )); then
      echo "OK"
    else
      echo "LOW"
    fi
  fi
}

csv_escape() {
  local s="${1:-}"
  s="${s//\"/\"\"}"
  printf '"%s"' "$s"
}

echo "host,ssh_alias,role,env,cpu_actual,cpu_want,cpu_status,ram_gb_actual,ram_gb_want,ram_status,opt_data_gb,opt_data_fs,disk_want_gb,disk_status,root_disk,large_mounts,error" > "$OUT"

printf "%-20s %-18s %-18s %-6s %8s %8s %-7s %8s %8s %-7s %12s %-8s %-8s %s\n" \
  "HOST" "SSH_ALIAS" "ROLE" "ENV" "CPU" "WANT" "STATUS" "RAM" "WANT" "STATUS" "OPT_DATA_GB" "FS" "DISK" "ERROR"

printf "%-20s %-18s %-18s %-6s %8s %8s %-7s %8s %8s %-7s %12s %-8s %-8s %s\n" \
  "----" "---------" "----" "---" "---" "----" "------" "---" "----" "------" "-----------" "--" "----" "-----"

tail -n +2 "$HOSTS" | while IFS=, read -r host ssh_alias role env want_cpu want_ram want_disk clickhouse_user; do
  [[ -z "${host// }" ]] && continue
  [[ "$host" =~ ^# ]] && continue

  ssh_target="${ssh_alias:-$host}"

  error=""
  cpu_actual=""
  ram_actual=""
  root_disk=""
  large_mounts=""
  opt_data_gb=""
  opt_data_fs=""
  disk_status="N/A"

  raw="$(
    ssh "${SSH_OPTS[@]}" "$ssh_target" 'bash -s' 2>/dev/null <<'REMOTE' || true
set -euo pipefail

cpu_actual="$(nproc)"

ram_gb_actual="$(
  awk '/MemTotal/ { printf "%.0f", $2/1024/1024 }' /proc/meminfo
)"

root_disk="$(
  df -hP / 2>/dev/null \
  | awk 'NR==2 {print $2 " total; " $4 " free; " $5 " used; fs=" $1}'
)"

large_mounts="$(
  df -hPT 2>/dev/null \
  | awk 'NR>1 && $2 ~ /ext4|xfs/ {
      print $7 ":" $2 ":" $3 " total:" $4 " used:" $5 " avail:" $6
    }' \
  | paste -sd '|' -
)"

opt_data_gb="$(
  df -BG -PT /opt/data 2>/dev/null \
  | awk 'NR==2 {
      size=$3
      gsub("G", "", size)
      print size+0
    }'
)"

opt_data_fs="$(
  df -PT /opt/data 2>/dev/null \
  | awk 'NR==2 { print $2 }'
)"

printf '__RESOURCE_REPORT__\t%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$cpu_actual" \
  "$ram_gb_actual" \
  "$root_disk" \
  "$large_mounts" \
  "$opt_data_gb" \
  "$opt_data_fs"
REMOTE
  )"

  line="$(printf '%s\n' "$raw" | grep '^__RESOURCE_REPORT__' | tail -n 1 || true)"

  if [[ -z "$line" ]]; then
    error="SSH or remote command failed"
    cpu_status="ERR"
    ram_status="ERR"
    disk_status="ERR"
  else
    IFS=$'\t' read -r _ cpu_actual ram_actual root_disk large_mounts opt_data_gb opt_data_fs <<< "$line"

    cpu_status="$(status_ge "$cpu_actual" "$want_cpu" 0)"
    ram_status="$(status_ge "$ram_actual" "$want_ram" 5)"

    if [[ "$want_disk" =~ ^[0-9]+$ ]]; then
      if [[ -z "${opt_data_fs:-}" ]]; then
        disk_status="MISSING"
      elif [[ "$opt_data_fs" =~ ^(ext4|xfs)$ ]]; then
        disk_status="$(status_ge "$opt_data_gb" "$want_disk" 5)"
      else
        disk_status="BAD_FS"
      fi
    fi
  fi

  {
    csv_escape "$host"; printf ","
    csv_escape "$ssh_alias"; printf ","
    csv_escape "$role"; printf ","
    csv_escape "$env"; printf ","
    csv_escape "$cpu_actual"; printf ","
    csv_escape "$want_cpu"; printf ","
    csv_escape "$cpu_status"; printf ","
    csv_escape "$ram_actual"; printf ","
    csv_escape "$want_ram"; printf ","
    csv_escape "$ram_status"; printf ","
    csv_escape "$opt_data_gb"; printf ","
    csv_escape "$opt_data_fs"; printf ","
    csv_escape "$want_disk"; printf ","
    csv_escape "$disk_status"; printf ","
    csv_escape "$root_disk"; printf ","
    csv_escape "$large_mounts"; printf ","
    csv_escape "$error"
    printf "\n"
  } >> "$OUT"

  printf "%-20s %-18s %-18s %-6s %8s %8s %-7s %8s %8s %-7s %12s %-8s %-8s %s\n" \
    "$host" \
    "${ssh_alias:-$host}" \
    "$role" \
    "$env" \
    "${cpu_actual:-?}" \
    "${want_cpu:-?}" \
    "$cpu_status" \
    "${ram_actual:-?}" \
    "${want_ram:-?}" \
    "$ram_status" \
    "${opt_data_gb:-?}" \
    "${opt_data_fs:-?}" \
    "$disk_status" \
    "$error"
done

echo
echo "CSV written to: $OUT"