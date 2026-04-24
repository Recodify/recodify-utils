#!/usr/bin/env bash
set -euo pipefail

# Synthetic copy workload generator + benchmark
#
# Default profile approximates:
#   24,854 files
#   ~12.685 GB total
#
# Usage examples:
#   ./wsl-copy-bench.sh generate
#   ./wsl-copy-bench.sh bench
#   ./wsl-copy-bench.sh all
#
# Custom paths:
#   SRC_ROOT=/tmp/wsl-bench/src DST_ROOT=/tmp/wsl-bench/dst ./wsl-copy-bench.sh all
#
# Custom profile:
#   FILE_COUNT=24854 TOTAL_BYTES=12685043176 ./wsl-copy-bench.sh generate
#
# Nested tree:
#   TREE_MODE=nested ./wsl-copy-bench.sh generate
#
# Notes:
# - Generated content is synthetic and non-sensitive.
# - By default, files are created with sparse-friendly size allocation plus a small
#   CSV header/body so the workload stresses file count and write path.
# - If you want full real bytes written into source as well, set FILL_MODE=full.

FILE_COUNT="${FILE_COUNT:-24854}"
TOTAL_BYTES="${TOTAL_BYTES:-12685043176}"   # ~12.685 GB
SRC_ROOT="${SRC_ROOT:-/tmp/wsl-copy-bench/src}"
DST_ROOT="${DST_ROOT:-/tmp/wsl-copy-bench/dst}"
TREE_MODE="${TREE_MODE:-flat}"              # flat | nested
FILL_MODE="${FILL_MODE:-sparse}"            # sparse | full
BENCH_TAR="${BENCH_TAR:-1}"                 # 1=yes, 0=no

RSYNC_BIN="${RSYNC_BIN:-rsync}"
TIME_BIN="${TIME_BIN:-/usr/bin/time}"

# Derived values
AVG_SIZE=$(( TOTAL_BYTES / FILE_COUNT ))
REMAINDER=$(( TOTAL_BYTES % FILE_COUNT ))

msg() {
  printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

human_bytes() {
  python3 - <<'PY' "$1"
import sys
n=int(sys.argv[1])
units=["B","KB","MB","GB","TB"]
i=0
v=float(n)
while v >= 1024 and i < len(units)-1:
    v/=1024
    i+=1
print(f"{v:.2f} {units[i]}")
PY
}

print_config() {
  cat <<EOF
Configuration
-------------
FILE_COUNT : $FILE_COUNT
TOTAL_BYTES: $TOTAL_BYTES ($(human_bytes "$TOTAL_BYTES"))
AVG_SIZE   : $AVG_SIZE ($(human_bytes "$AVG_SIZE"))
REMAINDER  : $REMAINDER
SRC_ROOT   : $SRC_ROOT
DST_ROOT   : $DST_ROOT
TREE_MODE  : $TREE_MODE
FILL_MODE  : $FILL_MODE
BENCH_TAR  : $BENCH_TAR
EOF
}

make_dirs() {
  mkdir -p "$SRC_ROOT" "$DST_ROOT"
}

cleanup_dst() {
  rm -rf "$DST_ROOT"
  mkdir -p "$DST_ROOT"
}

cleanup_all() {
  rm -rf "$(dirname "$SRC_ROOT")" "$(dirname "$DST_ROOT")"
}

# Generate a small CSV payload, then extend file size to target.
write_csv_file() {
  local path="$1"
  local size="$2"
  local idx="$3"

  # Small synthetic CSV content
  {
    printf 'id,group,value,stamp,text\n'
    printf '%d,%d,%d,%(%Y-%m-%dT%H:%M:%S)T,"synthetic row %d"\n' \
      "$idx" "$((idx % 100))" "$((idx * 17 % 100000))" -1 "$idx"
  } > "$path"

  local current
  current=$(stat -c %s "$path")

  if (( size < current )); then
    : > "$path"
    head -c "$size" /dev/zero | tr '\0' 'x' > "$path"
    return
  fi

  if [[ "$FILL_MODE" == "full" ]]; then
    # Fill with actual bytes.
    dd if=/dev/zero bs=1 count=$((size - current)) status=none >> "$path"
  else
    # Create a sparse file up to target size.
    truncate -s "$size" "$path"
  fi
}

generate_flat() {
  msg "Generating flat dataset..."
  local i size path

  for (( i=1; i<=FILE_COUNT; i++ )); do
    size="$AVG_SIZE"
    if (( i <= REMAINDER )); then
      ((size++))
    fi

    # Mix .csv and .CSV
    if (( i % 7 == 0 )); then
      path="$SRC_ROOT/file_$(printf '%05d' "$i").CSV"
    else
      path="$SRC_ROOT/file_$(printf '%05d' "$i").csv"
    fi

    write_csv_file "$path" "$size" "$i"

    if (( i % 2000 == 0 )); then
      msg "Created $i / $FILE_COUNT files"
    fi
  done
}

generate_nested() {
  msg "Generating nested dataset..."
  local i size subdir path

  for (( i=1; i<=FILE_COUNT; i++ )); do
    size="$AVG_SIZE"
    if (( i <= REMAINDER )); then
      ((size++))
    fi

    subdir="$SRC_ROOT/part_$(( (i-1) / 500 ))/batch_$(( (i-1) / 50 ))"
    mkdir -p "$subdir"

    if (( i % 7 == 0 )); then
      path="$subdir/file_$(printf '%05d' "$i").CSV"
    else
      path="$subdir/file_$(printf '%05d' "$i").csv"
    fi

    write_csv_file "$path" "$size" "$i"

    if (( i % 2000 == 0 )); then
      msg "Created $i / $FILE_COUNT files"
    fi
  done
}

generate_dataset() {
  require_cmd stat
  require_cmd truncate
  require_cmd find
  require_cmd du
  require_cmd awk
  require_cmd python3

  rm -rf "$SRC_ROOT"
  mkdir -p "$SRC_ROOT"

  print_config

  case "$TREE_MODE" in
    flat) generate_flat ;;
    nested) generate_nested ;;
    *)
      echo "Invalid TREE_MODE: $TREE_MODE (use flat or nested)" >&2
      exit 1
      ;;
  esac

  msg "Dataset complete"
  echo "File count: $(find "$SRC_ROOT" -type f | wc -l)"
  echo "Disk usage : $(du -sh "$SRC_ROOT" | awk '{print $1}')"
  echo "Apparent   : $(du -sh --apparent-size "$SRC_ROOT" | awk '{print $1}')"
}

bench_rsync() {
  require_cmd "$RSYNC_BIN"
  cleanup_dst
  msg "Benchmark: rsync"

  set +e
  "$TIME_BIN" -v "$RSYNC_BIN" -a --stats \
    --include='*.csv' \
    --include='*.CSV' \
    --exclude='*' \
    "$SRC_ROOT"/ "$DST_ROOT"/
  local rc=$?
  set -e

  echo "rsync exit code: $rc"
  echo "dst files: $(find "$DST_ROOT" -type f | wc -l)"
  echo "dst size : $(du -sh --apparent-size "$DST_ROOT" | awk '{print $1}')"
}

bench_rsync_recursive() {
  require_cmd "$RSYNC_BIN"
  cleanup_dst
  msg "Benchmark: rsync (recursive dir include)"

  set +e
  "$TIME_BIN" -v "$RSYNC_BIN" -a --stats \
    --include='*/' \
    --include='*.csv' \
    --include='*.CSV' \
    --exclude='*' \
    "$SRC_ROOT"/ "$DST_ROOT"/
  local rc=$?
  set -e

  echo "rsync recursive exit code: $rc"
  echo "dst files: $(find "$DST_ROOT" -type f | wc -l)"
  echo "dst size : $(du -sh --apparent-size "$DST_ROOT" | awk '{print $1}')"
}

bench_cp() {
  cleanup_dst
  msg "Benchmark: cp"

  if [[ "$TREE_MODE" == "flat" ]]; then
    set +e
    "$TIME_BIN" -v bash -c '
      shopt -s nullglob nocaseglob
      cp "'"$SRC_ROOT"'"/*.csv "'"$DST_ROOT"'"/
    '
    local rc=$?
    set -e
  else
    set +e
    "$TIME_BIN" -v bash -c '
      find "'"$SRC_ROOT"'" -type f \( -iname "*.csv" \) -exec cp --parents -t "'"$DST_ROOT"'" -- {} +
    '
    local rc=$?
    set -e
  fi

  echo "cp exit code: $rc"
  echo "dst files: $(find "$DST_ROOT" -type f | wc -l)"
  echo "dst size : $(du -sh --apparent-size "$DST_ROOT" | awk '{print $1}')"
}

bench_tar() {
  (( BENCH_TAR == 1 )) || return 0
  cleanup_dst
  msg "Benchmark: tar stream"

  if [[ "$TREE_MODE" == "flat" ]]; then
    set +e
    "$TIME_BIN" -v bash -c '
      cd "'"$SRC_ROOT"'" &&
      tar cf - -- *.csv *.CSV 2>/dev/null | (cd "'"$DST_ROOT"'" && tar xf -)
    '
    local rc=$?
    set -e
  else
    set +e
    "$TIME_BIN" -v bash -c '
      cd "'"$SRC_ROOT"'" &&
      find . -type f \( -iname "*.csv" \) -print0 |
      tar --null -T - -cf - |
      (cd "'"$DST_ROOT"'" && tar xf -)
    '
    local rc=$?
    set -e
  fi

  echo "tar exit code: $rc"
  echo "dst files: $(find "$DST_ROOT" -type f | wc -l)"
  echo "dst size : $(du -sh --apparent-size "$DST_ROOT" | awk '{print $1}')"
}

bench_all() {
  print_config
  echo "Source files: $(find "$SRC_ROOT" -type f | wc -l)"
  echo "Source size : $(du -sh --apparent-size "$SRC_ROOT" | awk '{print $1}')"

  bench_rsync
  if [[ "$TREE_MODE" == "nested" ]]; then
    bench_rsync_recursive
  fi
  bench_cp
  bench_tar
}

usage() {
  cat <<EOF
Usage:
  $0 generate   Create synthetic dataset
  $0 bench      Benchmark copy methods using existing dataset
  $0 all        Generate dataset, then benchmark

Environment overrides:
  FILE_COUNT=24854
  TOTAL_BYTES=12685043176
  SRC_ROOT=/tmp/wsl-bench/src
  DST_ROOT=/tmp/wsl-bench/dst
  TREE_MODE=flat|nested
  FILL_MODE=sparse|full
  BENCH_TAR=1|0

Examples:
  $0 all
  TREE_MODE=nested $0 all
  FILL_MODE=full FILE_COUNT=10000 TOTAL_BYTES=$((5*1024*1024*1024)) $0 all
EOF
}

main() {
  make_dirs

  case "${1:-}" in
    generate) generate_dataset ;;
    bench) bench_all ;;
    all)
      generate_dataset
      bench_all
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
