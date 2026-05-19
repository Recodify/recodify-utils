#!/usr/bin/env bash
set -euo pipefail

HOSTS="${HOSTS:-./hosts.csv}"
TESTS="${1:-./connectivity-tests.csv}"
RESULTS_FILE="${2:-./connectivity-results.csv}"

SOURCE_USER="${SOURCE_USER:-shiles}"
REMOTE_USER="${REMOTE_USER:-sv_np_ingt_ancoregas}"

USER_FILES="${USER_FILES:-/opt/data/clickhouse/user_files}"
DB="${DB:-ancore_gas_raw}"

LOG_DIR="${LOG_DIR:-/tmp/connectivity-report-logs}"
mkdir -p "$LOG_DIR"

declare -A SSH_ALIAS
declare -A CLICKHOUSE_USER
declare -A CLICKHOUSE_PASSWORD

clean_log() {
  local file="$1"
  grep -v '^EDF Trading: Authorized users only' "$file" 2>/dev/null || true
}

while IFS=, read -r host ssh_alias role env want_cpu want_ram want_disk ch_user ch_password; do
  host="${host//$'\r'/}"
  ssh_alias="${ssh_alias//$'\r'/}"
  ch_user="${ch_user//$'\r'/}"
  ch_password="${ch_password//$'\r'/}"

  [[ "$host" == "host" ]] && continue
  [[ -z "${host// }" ]] && continue

  SSH_ALIAS["$host"]="$ssh_alias"
  CLICKHOUSE_USER["$host"]="$ch_user"
  CLICKHOUSE_PASSWORD["$host"]="$ch_password"
done < "$HOSTS"

csv_escape() {
  local value="${1:-}"
  value="${value//\"/\"\"}"
  printf '"%s"' "$value"
}

echo "env,source_host,destination_host,description,expected_replica,ch_user,source_rsync,destination_shell_read,clickhouse_file_read,clickhouse_file_write,macro_config,overall_status,failure" > "$RESULTS_FILE"

printf "%-6s %-18s %-18s %-34s %-8s %-8s %-8s %-8s %-8s %-8s %s\n" \
  "ENV" "SOURCE" "DESTINATION" "DESCRIPTION" "RSYNC" "SHELL" "READ" "WRITE" "MACROS" "OVERALL" "FAILURE"

printf "%-6s %-18s %-18s %-34s %-8s %-8s %-8s %-8s %-8s %-8s %s\n" \
  "---" "------" "-----------" "-----------" "-----" "-----" "----" "-----" "------" "-------" "-------"

tail -n +2 "$TESTS" | while IFS=, read -r env description source_host dest_host; do
  env="${env//$'\r'/}"
  description="${description//$'\r'/}"
  source_host="${source_host//$'\r'/}"
  dest_host="${dest_host//$'\r'/}"

  [[ -z "${source_host// }" ]] && continue
  [[ -z "${dest_host// }" ]] && continue
  [[ "$source_host" =~ ^# ]] && continue

  source_alias="${SSH_ALIAS[$source_host]:-$source_host}"
  expected_replica="$dest_host"

  ch_user="${CLICKHOUSE_USER[$dest_host]:-}"
  ch_password="${CLICKHOUSE_PASSWORD[$dest_host]:-}"

  TEST_FILE="rsync_matrix_test_${source_host}_${dest_host}.csv"
  MACROS_FILE="rsync_matrix_macros_${source_host}_${dest_host}.json"

  safe_id="${source_host}_${dest_host}"
  step1_log="$LOG_DIR/${safe_id}_step1_rsync.log"
  step2_log="$LOG_DIR/${safe_id}_step2_shell.log"
  step3_log="$LOG_DIR/${safe_id}_step3_ch_read.log"
  step4_log="$LOG_DIR/${safe_id}_step4_ch_write.log"
  cleanup_log="$LOG_DIR/${safe_id}_cleanup.log"

  step_source_rsync="FAIL"
  step_dest_shell_read="FAIL"
  step_ch_file_read="FAIL"
  step_ch_file_write="FAIL"
  step_macro_config="FAIL"
  failure=""

  ch_client() {
    cat <<EOF
clickhouse-client \
  -h localhost \
  --user '$ch_user' \
  --password '$ch_password'
EOF
  }

  run_on_dest_via_source() {
    local script="$1"

    ssh \
            -o ConnectTimeout=10 \
      "${SOURCE_USER}@${source_alias}" \
      bash -s -- \
      "$REMOTE_USER" \
      "$dest_host" <<SOURCE_SCRIPT
set -euo pipefail

remote_user="\$1"
dest_host="\$2"

ssh \
    -o ConnectTimeout=10 \
  "\${remote_user}@\${dest_host}" \
  bash -s <<'DEST_SCRIPT'
set -euo pipefail

$script

DEST_SCRIPT
SOURCE_SCRIPT
  }

  cleanup() {
    run_on_dest_via_source "
      rm -f '$USER_FILES/$TEST_FILE' '$USER_FILES/$MACROS_FILE'

      
    " >"$cleanup_log" 2>&1 || true
  }

  overall_status() {
    if [[ "$step_source_rsync" == "PASS" \
       && "$step_dest_shell_read" == "PASS" \
       && "$step_ch_file_read" == "PASS" \
       && "$step_ch_file_write" == "PASS" \
       && "$step_macro_config" == "PASS" ]]; then
      echo "PASS"
    else
      echo "FAIL"
    fi
  }

  print_result_row() {
    local status
    status="$(overall_status)"

    {
      csv_escape "$env"; printf ','
      csv_escape "$source_host"; printf ','
      csv_escape "$dest_host"; printf ','
      csv_escape "$description"; printf ','
      csv_escape "$expected_replica"; printf ','
      csv_escape "$ch_user"; printf ','
      csv_escape "$step_source_rsync"; printf ','
      csv_escape "$step_dest_shell_read"; printf ','
      csv_escape "$step_ch_file_read"; printf ','
      csv_escape "$step_ch_file_write"; printf ','
      csv_escape "$step_macro_config"; printf ','
      csv_escape "$status"; printf ','
      csv_escape "$failure"
      printf '\n'
    } >> "$RESULTS_FILE"

    printf "%-6s %-18s %-18s %-34s %-8s %-8s %-8s %-8s %-8s %-8s %s\n" \
      "$env" \
      "$source_host" \
      "$dest_host" \
      "$description" \
      "$step_source_rsync" \
      "$step_dest_shell_read" \
      "$step_ch_file_read" \
      "$step_ch_file_write" \
      "$step_macro_config" \
      "$status" \
      "$failure"
  }

  if [[ -z "$ch_user" || -z "$ch_password" ]]; then
    failure="missing ClickHouse user/password for destination host in hosts.csv"
    print_result_row
    continue
  fi

  if ssh \
            -o ConnectTimeout=10 \
      "${SOURCE_USER}@${source_alias}" \
      bash -s -- \
      "$REMOTE_USER" \
      "$dest_host" \
      "$USER_FILES" \
      "$TEST_FILE" <<'SOURCE_SCRIPT' >"$step1_log" 2>&1
set -euo pipefail

remote_user="$1"
dest_host="$2"
user_files="$3"
test_file="$4"

echo "hello world from rsync via $(hostname) to $dest_host" > "/tmp/$test_file"

rsync -az \
  "/tmp/$test_file" \
  "$remote_user@$dest_host:$user_files/$test_file"

rm -f "/tmp/$test_file"
SOURCE_SCRIPT
  then
    step_source_rsync="PASS"
  else
    failure="source SSH or rsync to destination failed"
    clean_log "$step1_log" >&2
    cleanup
    print_result_row
    continue
  fi

  if run_on_dest_via_source "
    test -s '$USER_FILES/$TEST_FILE'
  " >"$step2_log" 2>&1; then
    step_dest_shell_read="PASS"
  else
    failure="destination shell read via source failed"
    clean_log "$step2_log" >&2
    cleanup
    print_result_row
    continue
  fi

  if run_on_dest_via_source "
    $(ch_client) --query \"
      CREATE TABLE IF NOT EXISTS $DB.rsync_matrix_test
      (
        name String
      )
      ENGINE = MergeTree
      ORDER BY name
    \"

    $(ch_client) --query \"
      TRUNCATE TABLE $DB.rsync_matrix_test
    \"

    $(ch_client) --query \"
      INSERT INTO $DB.rsync_matrix_test
      SELECT *
      FROM file('$TEST_FILE', CSV, 'name String')
    \"

    $(ch_client) --query \"
      SELECT count()
      FROM $DB.rsync_matrix_test
    \"
  " >"$step3_log" 2>&1; then
    step_ch_file_read="PASS"
  else
    failure="ClickHouse file read or table write failed"
    clean_log "$step3_log" >&2
    cleanup
    print_result_row
    continue
  fi

  if run_on_dest_via_source "
    rm -f '$USER_FILES/$MACROS_FILE'

    $(ch_client) --query \"
      INSERT INTO FUNCTION file('$MACROS_FILE', 'JSONEachRow')
      SELECT *
      FROM system.macros
    \"

    test -s '$USER_FILES/$MACROS_FILE'
  " >"$step4_log" 2>&1; then
    step_ch_file_write="PASS"
  else
    failure="ClickHouse file write failed"
    clean_log "$step4_log" >&2
    cleanup
    print_result_row
    continue
  fi

  macro_output="$(
    run_on_dest_via_source "
      $(ch_client) --format TSV --query \"
        SELECT macro, substitution
        FROM system.macros
        WHERE macro IN ('cluster', 'replica', 'shard')
        ORDER BY macro
      \"
    " 2>&1
  )"

  macro_query_status=$?

  macro_output="$(printf '%s\n' "$macro_output" | grep -v '^EDF Trading: Authorized users only' || true)"

  if [[ "$macro_query_status" -ne 0 ]]; then
    failure="macro query failed"
    cleanup
    print_result_row
    continue
  fi

  if ! grep -q $'cluster\tAnCore_Cluster' <<< "$macro_output"; then
    failure="cluster macro incorrect"
  elif ! grep -q $'replica\t'"$expected_replica" <<< "$macro_output"; then
    failure="replica macro incorrect, expected $expected_replica"
  elif ! grep -q $'shard\t01' <<< "$macro_output"; then
    failure="shard macro incorrect"
  else
    step_macro_config="PASS"
  fi

  cleanup
  print_result_row
done

echo
echo "CSV written to: $RESULTS_FILE"