#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage:
  $(basename "$0") --files N --src CIFS_MOUNT --dest LOCAL_DEST [options]

Options:
  --files N             Number of files to rsync
  --src DIR             Mounted CIFS source root, read only
  --dest DIR            Local destination root

  --known-file PATH     Relative path under --src. Skips discovery
  --file-list FILE      Reuse an existing relative-path file list

  --select MODE         first|smallest|largest|median|random, default: first
  --min-size SIZE       Minimum source file size, e.g. 1M
  --max-size SIZE       Maximum source file size, e.g. 100M

  --out-dir DIR         Metrics/log output base dir, default: /tmp
  --label LABEL         Optional run label
  --delete-dest         Pass --delete to rsync
  --dry-run             Pass --dry-run to rsync
  -h, --help            Show help

Examples:
  ./rsync-cifs-perf.sh --files 100 --src /mnt/deepseainput/processed/20260430 --dest /opt/data/test-rsync --select median

  ./rsync-cifs-perf.sh --files 100 --src /mnt/deepseainput/processed/20260430 --dest /opt/data/test-rsync --select largest

  ./rsync-cifs-perf.sh --files 100 --src /mnt/deepseainput/processed/20260430 --dest /opt/data/test-rsync --min-size 1M --max-size 10M

  ./rsync-cifs-perf.sh --files 100 --src /mnt/deepseainput/processed/20260430 --dest /opt/data/test-rsync --file-list /tmp/previous/files.txt
EOF
}

FILES=""
SRC_ROOT=""
DEST_ROOT=""
KNOWN_FILE=""
INPUT_FILE_LIST=""
SELECT_MODE="first"
MIN_SIZE=""
MAX_SIZE=""
OUT_BASE="/tmp"
LABEL=""
DELETE_DEST=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --files) FILES="$2"; shift 2 ;;
    --src) SRC_ROOT="$2"; shift 2 ;;
    --dest) DEST_ROOT="$2"; shift 2 ;;
    --known-file) KNOWN_FILE="$2"; shift 2 ;;
    --file-list) INPUT_FILE_LIST="$2"; shift 2 ;;
    --select) SELECT_MODE="$2"; shift 2 ;;
    --min-size) MIN_SIZE="$2"; shift 2 ;;
    --max-size) MAX_SIZE="$2"; shift 2 ;;
    --out-dir) OUT_BASE="$2"; shift 2 ;;
    --label) LABEL="$2"; shift 2 ;;
    --delete-dest) DELETE_DEST=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$FILES" && -n "$SRC_ROOT" && -n "$DEST_ROOT" ]] || {
  usage
  exit 1
}

case "$SELECT_MODE" in
  first|smallest|largest|median|random) ;;
  *) echo "Unknown --select mode: $SELECT_MODE" >&2; exit 1 ;;
esac

for cmd in rsync find stat awk grep sort head tail cut wc numfmt date tee; do
  command -v "$cmd" >/dev/null || { echo "Missing command: $cmd" >&2; exit 1; }
done

SRC_ROOT="${SRC_ROOT%/}"
DEST_ROOT="${DEST_ROOT%/}"

[[ -d "$SRC_ROOT" ]] || { echo "Source does not exist or is not a directory: $SRC_ROOT" >&2; exit 1; }
mkdir -p "$DEST_ROOT"

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
WORK_DIR="$OUT_BASE/rsync-cifs-perf-$RUN_ID"
mkdir -p "$WORK_DIR"

FILE_LIST="$WORK_DIR/files.txt"
CANDIDATES="$WORK_DIR/candidates.tsv"
FIND_LOG="$WORK_DIR/find.err"
RSYNC_LOG="$WORK_DIR/rsync.log"
METRICS="$WORK_DIR/metrics.json"

now_ns() {
  date +%s%N
}

elapsed_ms() {
  local start="$1"
  local end="$2"
  echo $(( (end - start) / 1000000 ))
}

to_bytes() {
  numfmt --from=iec "$1"
}

json_escape() {
  sed 's/\\/\\\\/g; s/"/\\"/g'
}

GENERATED_CANDIDATES=""

TOTAL_START_NS="$(now_ns)"

echo "Run:        $RUN_ID"
echo "Label:      $LABEL"
echo "Source:     $SRC_ROOT"
echo "Dest:       $DEST_ROOT"
echo "Files:      $FILES"
echo "Select:     $SELECT_MODE"
echo "Min size:   ${MIN_SIZE:-none}"
echo "Max size:   ${MAX_SIZE:-none}"
echo "Work dir:   $WORK_DIR"
echo

DISCOVERY_START_NS="$(now_ns)"

if [[ -n "$INPUT_FILE_LIST" ]]; then
  [[ -f "$INPUT_FILE_LIST" ]] || { echo "File list not found: $INPUT_FILE_LIST" >&2; exit 1; }

  echo "Using supplied file list: $INPUT_FILE_LIST"
  head -n "$FILES" "$INPUT_FILE_LIST" > "$FILE_LIST"

elif [[ -n "$KNOWN_FILE" ]]; then
  echo "Using known file, skipping discovery"
  KNOWN_FILE="${KNOWN_FILE#/}"
  printf '%s\n' "$KNOWN_FILE" > "$FILE_LIST"

else
  echo "Discovering candidate files from CIFS source..."

  find "$SRC_ROOT" -type f -printf '%s\t%P\n' > "$CANDIDATES" 2>"$FIND_LOG"
  GENERATED_CANDIDATES="$CANDIDATES"

  if [[ -n "$MIN_SIZE" || -n "$MAX_SIZE" ]]; then
    min_bytes=0
    max_bytes=999999999999999999

    [[ -n "$MIN_SIZE" ]] && min_bytes="$(to_bytes "$MIN_SIZE")"
    [[ -n "$MAX_SIZE" ]] && max_bytes="$(to_bytes "$MAX_SIZE")"

    awk -F '\t' -v min="$min_bytes" -v max="$max_bytes" \
      '$1 >= min && $1 <= max { print }' "$CANDIDATES" > "$CANDIDATES.filtered"

    mv "$CANDIDATES.filtered" "$CANDIDATES"
  fi

  candidate_count="$(wc -l < "$CANDIDATES" | tr -d ' ')"

  if [[ "$candidate_count" -eq 0 ]]; then
    echo "No candidate files found after filtering." >&2
    echo "Find log: $FIND_LOG" >&2
    exit 1
  fi

  case "$SELECT_MODE" in
    first)
      head -n "$FILES" "$CANDIDATES" | cut -f2- > "$FILE_LIST"
      ;;
    smallest)
      sort -n -k1,1 "$CANDIDATES" | head -n "$FILES" | cut -f2- > "$FILE_LIST"
      ;;
    largest)
      sort -nr -k1,1 "$CANDIDATES" | head -n "$FILES" | cut -f2- > "$FILE_LIST"
      ;;
    median)
      total="$candidate_count"
      start=$(( total / 2 - FILES / 2 ))
      [[ "$start" -lt 1 ]] && start=1
      sort -n -k1,1 "$CANDIDATES" | tail -n +"$start" | head -n "$FILES" | cut -f2- > "$FILE_LIST"
      ;;
    random)
      shuf "$CANDIDATES" | head -n "$FILES" | cut -f2- > "$FILE_LIST"
      ;;
  esac
fi

DISCOVERY_END_NS="$(now_ns)"
DISCOVERY_MS="$(elapsed_ms "$DISCOVERY_START_NS" "$DISCOVERY_END_NS")"

ACTUAL_FILES="$(wc -l < "$FILE_LIST" | tr -d ' ')"

if [[ "$ACTUAL_FILES" -eq 0 ]]; then
  echo "No files selected." >&2
  exit 1
fi

echo "Selected:   $ACTUAL_FILES files"
echo "Discovery:  ${DISCOVERY_MS}ms"
echo

echo "Measuring source file sizes..."
STAT_START_NS="$(now_ns)"

SIZE_LIST="$WORK_DIR/selected-sizes.tsv"

while IFS= read -r rel; do
  size="$(stat -c '%s' "$SRC_ROOT/$rel")"
  printf "%s\t%s\n" "$size" "$rel"
done < "$FILE_LIST" > "$SIZE_LIST"

TOTAL_BYTES="$(awk -F '\t' '{s += $1} END {print s + 0}' "$SIZE_LIST")"
MIN_SELECTED_BYTES="$(awk -F '\t' 'NR == 1 || $1 < min {min = $1} END {print min + 0}' "$SIZE_LIST")"
MAX_SELECTED_BYTES="$(awk -F '\t' 'NR == 1 || $1 > max {max = $1} END {print max + 0}' "$SIZE_LIST")"
AVG_SELECTED_BYTES="$(awk -F '\t' '{s += $1; n++} END {if (n > 0) printf "%.0f", s / n; else print 0}' "$SIZE_LIST")"

STAT_END_NS="$(now_ns)"
STAT_MS="$(elapsed_ms "$STAT_START_NS" "$STAT_END_NS")"

echo "Bytes:      $TOTAL_BYTES"
echo "Min file:   $MIN_SELECTED_BYTES"
echo "Avg file:   $AVG_SELECTED_BYTES"
echo "Max file:   $MAX_SELECTED_BYTES"
echo "Stat time:  ${STAT_MS}ms"
echo

RSYNC_ARGS=(
  -a
  --files-from="$FILE_LIST"
  --info=stats2,progress2
  --human-readable
)

[[ "$DELETE_DEST" -eq 1 ]] && RSYNC_ARGS+=(--delete)
[[ "$DRY_RUN" -eq 1 ]] && RSYNC_ARGS+=(--dry-run)

echo "Running rsync..."
RSYNC_START_NS="$(now_ns)"

set +e
rsync "${RSYNC_ARGS[@]}" "$SRC_ROOT/" "$DEST_ROOT/" 2>&1 | tee "$RSYNC_LOG"
RSYNC_EXIT="${PIPESTATUS[0]}"
set -e

RSYNC_END_NS="$(now_ns)"
RSYNC_MS="$(elapsed_ms "$RSYNC_START_NS" "$RSYNC_END_NS")"

TOTAL_END_NS="$(now_ns)"
TOTAL_MS="$(elapsed_ms "$TOTAL_START_NS" "$TOTAL_END_NS")"

bytes_sent="$(grep -E "Total bytes sent:" "$RSYNC_LOG" | tail -1 | awk -F: '{gsub(/[, ]/, "", $2); print $2}' || true)"
bytes_received="$(grep -E "Total bytes received:" "$RSYNC_LOG" | tail -1 | awk -F: '{gsub(/[, ]/, "", $2); print $2}' || true)"
literal_data="$(grep -E "Literal data:" "$RSYNC_LOG" | tail -1 | awk -F: '{gsub(/[, ]/, "", $2); print $2}' || true)"
matched_data="$(grep -E "Matched data:" "$RSYNC_LOG" | tail -1 | awk -F: '{gsub(/[, ]/, "", $2); print $2}' || true)"
file_list_size="$(grep -E "File list size:" "$RSYNC_LOG" | tail -1 | awk -F: '{gsub(/[, ]/, "", $2); print $2}' || true)"
speedup="$(grep -E "speedup is" "$RSYNC_LOG" | tail -1 | awk '{print $NF}' || true)"
transferred_files="$(grep -E "Number of regular files transferred:" "$RSYNC_LOG" | tail -1 | awk -F: '{gsub(/[, ]/, "", $2); print $2}' || true)"

avg_discovery_ms_per_file="$(awk -v ms="$DISCOVERY_MS" -v n="$ACTUAL_FILES" 'BEGIN { if (n > 0) printf "%.3f", ms / n; else print "" }')"
avg_stat_ms_per_file="$(awk -v ms="$STAT_MS" -v n="$ACTUAL_FILES" 'BEGIN { if (n > 0) printf "%.3f", ms / n; else print "" }')"
avg_rsync_ms_per_file="$(awk -v ms="$RSYNC_MS" -v n="$ACTUAL_FILES" 'BEGIN { if (n > 0) printf "%.3f", ms / n; else print "" }')"
avg_total_ms_per_file="$(awk -v ms="$TOTAL_MS" -v n="$ACTUAL_FILES" 'BEGIN { if (n > 0) printf "%.3f", ms / n; else print "" }')"

if [[ "$RSYNC_MS" -gt 0 ]]; then
  source_mib_per_sec="$(awk -v b="$TOTAL_BYTES" -v ms="$RSYNC_MS" 'BEGIN { printf "%.3f", (b / 1048576) / (ms / 1000) }')"
else
  source_mib_per_sec=""
fi

cat > "$METRICS" <<EOF
{
  "run_id": "$RUN_ID",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "label": "$(printf '%s' "$LABEL" | json_escape)",
  "source": "$(printf '%s' "$SRC_ROOT" | json_escape)",
  "destination": "$(printf '%s' "$DEST_ROOT" | json_escape)",
  "requested_files": $FILES,
  "actual_files": $ACTUAL_FILES,
  "select_mode": "$SELECT_MODE",
  "min_size": "$(printf '%s' "$MIN_SIZE" | json_escape)",
  "max_size": "$(printf '%s' "$MAX_SIZE" | json_escape)",
  "known_file": "$(printf '%s' "$KNOWN_FILE" | json_escape)",
  "input_file_list": "$(printf '%s' "$INPUT_FILE_LIST" | json_escape)",
  "generated_candidates": "$(printf '%s' "$GENERATED_CANDIDATES" | json_escape)",
  "source_total_bytes": $TOTAL_BYTES,
  "min_selected_bytes": $MIN_SELECTED_BYTES,
  "avg_selected_bytes": $AVG_SELECTED_BYTES,
  "max_selected_bytes": $MAX_SELECTED_BYTES,
  "discovery_ms": $DISCOVERY_MS,
  "stat_ms": $STAT_MS,
  "rsync_ms": $RSYNC_MS,
  "total_ms": $TOTAL_MS,
  "avg_discovery_ms_per_file": $avg_discovery_ms_per_file,
  "avg_stat_ms_per_file": $avg_stat_ms_per_file,
  "avg_rsync_ms_per_file": $avg_rsync_ms_per_file,
  "avg_total_ms_per_file": $avg_total_ms_per_file,
  "source_mib_per_sec_by_rsync_time": "${source_mib_per_sec}",
  "rsync_exit_code": $RSYNC_EXIT,
  "rsync_regular_files_transferred": "${transferred_files}",
  "rsync_total_bytes_sent": "${bytes_sent}",
  "rsync_total_bytes_received": "${bytes_received}",
  "rsync_literal_data": "${literal_data}",
  "rsync_matched_data": "${matched_data}",
  "rsync_file_list_size": "${file_list_size}",
  "rsync_speedup": "${speedup}",
  "dry_run": $DRY_RUN,
  "delete_dest": $DELETE_DEST,
  "file_list": "$(printf '%s' "$FILE_LIST" | json_escape)",
  "size_list": "$(printf '%s' "$SIZE_LIST" | json_escape)",
  "find_log": "$(printf '%s' "$FIND_LOG" | json_escape)",
  "rsync_log": "$(printf '%s' "$RSYNC_LOG" | json_escape)"
}
EOF

echo
echo "==== SUMMARY ===="
echo "Files selected:       $ACTUAL_FILES"
echo "Files transferred:    ${transferred_files:-unknown}"
echo "Bytes selected:       $TOTAL_BYTES"
echo "Min/avg/max file:     $MIN_SELECTED_BYTES / $AVG_SELECTED_BYTES / $MAX_SELECTED_BYTES"
echo "Discovery:            ${DISCOVERY_MS}ms"
echo "Stat:                 ${STAT_MS}ms"
echo "Rsync:                ${RSYNC_MS}ms"
echo "Total:                ${TOTAL_MS}ms"
echo "Avg discovery/file:   ${avg_discovery_ms_per_file}ms"
echo "Avg stat/file:        ${avg_stat_ms_per_file}ms"
echo "Avg rsync/file:       ${avg_rsync_ms_per_file}ms"
echo "Avg total/file:       ${avg_total_ms_per_file}ms"
echo "MiB/s by rsync time:  ${source_mib_per_sec:-n/a}"
echo "Exit code:            $RSYNC_EXIT"
echo "Metrics:              $METRICS"
echo "File list:            $FILE_LIST"
echo "Size list:            $SIZE_LIST"
echo "Rsync log:            $RSYNC_LOG"

exit "$RSYNC_EXIT"