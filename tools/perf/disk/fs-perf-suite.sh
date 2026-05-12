#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage:
  $(basename "$0") --dest /opt/data/perf [options]

Options:
  --dest DIR              Target test directory
  --label LABEL           Optional label
  --out-dir DIR           Default: /tmp
  --runs N                Default: 1

  --small-files N         Default: 20000
  --small-size BYTES      Default: 4096
  --large-files N         Default: 4
  --large-size SIZE       Default: 1G
  --rename-files N        Default: 20000

  --sync-policy POLICY    none|before|after|both, default: none
  --keep                  Do not delete final work dir
  -h, --help              Show help
EOF
}

DEST=""
LABEL=""
OUT_BASE="/tmp"
RUNS=1

SMALL_FILES=20000
SMALL_SIZE=4096
LARGE_FILES=4
LARGE_SIZE="1G"
RENAME_FILES=20000

SYNC_POLICY="none"
KEEP=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest) DEST="$2"; shift 2 ;;
    --label) LABEL="$2"; shift 2 ;;
    --out-dir) OUT_BASE="$2"; shift 2 ;;
    --runs) RUNS="$2"; shift 2 ;;
    --small-files) SMALL_FILES="$2"; shift 2 ;;
    --small-size) SMALL_SIZE="$2"; shift 2 ;;
    --large-files) LARGE_FILES="$2"; shift 2 ;;
    --large-size) LARGE_SIZE="$2"; shift 2 ;;
    --rename-files) RENAME_FILES="$2"; shift 2 ;;
    --sync-policy) SYNC_POLICY="$2"; shift 2 ;;
    --keep) KEEP=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$DEST" ]] || { usage; exit 1; }

case "$SYNC_POLICY" in
  none|before|after|both) ;;
  *) echo "Invalid --sync-policy: $SYNC_POLICY" >&2; exit 1 ;;
esac

for cmd in awk find stat dd cp mv rm numfmt df date sync column findmnt; do
  command -v "$cmd" >/dev/null || { echo "Missing command: $cmd" >&2; exit 1; }
done

DEST="${DEST%/}"
mkdir -p "$DEST"

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$OUT_BASE/fs-perf-suite-$RUN_ID"
mkdir -p "$OUT"

RESULTS="$OUT/results.tsv"
SUMMARY="$OUT/summary.json"

now_ns() {
  date +%s%N
}

elapsed_ms() {
  echo $(( ($2 - $1) / 1000000 ))
}

bytes_to_num() {
  numfmt --from=iec "$1"
}

maybe_sync_before() {
  case "$SYNC_POLICY" in
    before|both) sync ;;
  esac
}

maybe_sync_after() {
  case "$SYNC_POLICY" in
    after|both) sync ;;
  esac
}

record() {
  local run="$1"
  local test="$2"
  local status="$3"
  local ms="$4"
  local ops="$5"
  local bytes="$6"
  local notes="${7:-}"

  local ops_per_sec=""
  local ms_per_op=""
  local mib_per_sec=""

  if [[ "$status" == "ok" ]]; then
    ops_per_sec="$(awk -v ops="$ops" -v ms="$ms" 'BEGIN { if (ms > 0 && ops > 0) printf "%.3f", ops / (ms / 1000); else print "" }')"
    ms_per_op="$(awk -v ops="$ops" -v ms="$ms" 'BEGIN { if (ops > 0) printf "%.6f", ms / ops; else print "" }')"
    mib_per_sec="$(awk -v b="$bytes" -v ms="$ms" 'BEGIN { if (ms > 0 && b > 0) printf "%.3f", (b / 1048576) / (ms / 1000); else print "" }')"
  fi

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$run" "$test" "$status" "$ms" "$ops" "$bytes" "$ops_per_sec" "$ms_per_op" "$mib_per_sec" "$notes" >> "$RESULTS"
}

run_test() {
  local name="$1"
  shift

  echo "== $name ==" >&2

  local start end ms

  maybe_sync_before
  start="$(now_ns)"

  if "$@"; then
    maybe_sync_after
    end="$(now_ns)"
    ms="$(elapsed_ms "$start" "$end")"
    echo "$ms"
    return 0
  else
    maybe_sync_after
    end="$(now_ns)"
    ms="$(elapsed_ms "$start" "$end")"
    echo "$ms"
    return 1
  fi
}

test_reflink_support() {
  local dir="$1/reflink-check"
  mkdir -p "$dir"

  echo "test" > "$dir/a"

  if cp --reflink=always "$dir/a" "$dir/b" 2>/dev/null; then
    rm -rf "$dir"
    echo "supported"
  else
    rm -rf "$dir"
    echo "unsupported"
  fi
}

write_small_files() {
  local work="$1"
  local dir="$work/small-write"
  mkdir -p "$dir"

  for i in $(seq 1 "$SMALL_FILES"); do
    printf -v f "%s/file_%08d.bin" "$dir" "$i"
    dd if=/dev/zero of="$f" bs="$SMALL_SIZE" count=1 status=none
  done
}

stat_small_files() {
  local work="$1"
  find "$work/small-write" -type f -exec stat -c '%n %s' {} \; >/dev/null
}

copy_small_default() {
  local work="$1"
  mkdir -p "$work/small-copy-default"
  cp -a "$work/small-write/." "$work/small-copy-default/"
}

copy_small_reflink_never() {
  local work="$1"
  mkdir -p "$work/small-copy-reflink-never"
  cp -a --reflink=never "$work/small-write/." "$work/small-copy-reflink-never/"
}

copy_small_reflink_always() {
  local work="$1"
  mkdir -p "$work/small-copy-reflink-always"
  cp -a --reflink=always "$work/small-write/." "$work/small-copy-reflink-always/"
}

delete_small_default() {
  local work="$1"
  rm -rf "$work/small-copy-default"
}

delete_small_reflink_never() {
  local work="$1"
  rm -rf "$work/small-copy-reflink-never"
}

delete_small_reflink_always() {
  local work="$1"
  rm -rf "$work/small-copy-reflink-always"
}

rename_create_and_rename() {
  local work="$1"
  local dir="$work/rename"
  mkdir -p "$dir"

  for i in $(seq 1 "$RENAME_FILES"); do
    printf -v f "%s/file_%08d.tmp" "$dir" "$i"
    : > "$f"
  done

  for i in $(seq 1 "$RENAME_FILES"); do
    printf -v src "%s/file_%08d.tmp" "$dir" "$i"
    printf -v dst "%s/file_%08d.done" "$dir" "$i"
    mv "$src" "$dst"
  done
}

delete_many_small_files() {
  local work="$1"
  local dir="$work/delete-many"
  mkdir -p "$dir"

  for i in $(seq 1 "$SMALL_FILES"); do
    printf -v f "%s/file_%08d.bin" "$dir" "$i"
    : > "$f"
  done

  find "$dir" -type f -delete
}

delete_nested_tree() {
  local work="$1"
  local dir="$work/delete-tree"
  mkdir -p "$dir"

  for d in $(seq 1 100); do
    mkdir -p "$dir/dir_$d"
    for f in $(seq 1 100); do
      : > "$dir/dir_$d/file_$f.tmp"
    done
  done

  rm -rf "$dir"
}

write_large_buffered() {
  local work="$1"
  local dir="$work/large-write-buffered"
  mkdir -p "$dir"

  for i in $(seq 1 "$LARGE_FILES"); do
    printf -v f "%s/large_%04d.bin" "$dir" "$i"
    dd if=/dev/zero of="$f" bs="$LARGE_SIZE" count=1 status=none
  done
}

write_large_fsync() {
  local work="$1"
  local dir="$work/large-write-fsync"
  mkdir -p "$dir"

  for i in $(seq 1 "$LARGE_FILES"); do
    printf -v f "%s/large_%04d.bin" "$dir" "$i"
    dd if=/dev/zero of="$f" bs="$LARGE_SIZE" count=1 conv=fsync status=none
  done
}

copy_large_default() {
  local work="$1"
  mkdir -p "$work/large-copy-default"
  cp -a "$work/large-write-fsync/." "$work/large-copy-default/"
}

copy_large_reflink_never() {
  local work="$1"
  mkdir -p "$work/large-copy-reflink-never"
  cp -a --reflink=never "$work/large-write-fsync/." "$work/large-copy-reflink-never/"
}

copy_large_reflink_always() {
  local work="$1"
  mkdir -p "$work/large-copy-reflink-always"
  cp -a --reflink=always "$work/large-write-fsync/." "$work/large-copy-reflink-always/"
}

delete_large_default() {
  local work="$1"
  rm -rf "$work/large-copy-default"
}

delete_large_reflink_never() {
  local work="$1"
  rm -rf "$work/large-copy-reflink-never"
}

delete_large_reflink_always() {
  local work="$1"
  rm -rf "$work/large-copy-reflink-always"
}

tree_walk() {
  local work="$1"
  find "$work" -type f >/dev/null
}

cleanup_all() {
  local work="$1"
  rm -rf "$work"
}

echo -e "run\ttest\tstatus\tms\tops\tbytes\tops_per_sec\tms_per_op\tmib_per_sec\tnotes" > "$RESULTS"

FS_TYPE="$(findmnt -no FSTYPE --target "$DEST")"
SOURCE_DEV="$(findmnt -no SOURCE --target "$DEST")"
MOUNT_OPTS="$(findmnt -no OPTIONS --target "$DEST")"
DF_LINE="$(df -T "$DEST" | tail -1)"

SMALL_TOTAL_BYTES=$((SMALL_FILES * SMALL_SIZE))
LARGE_SIZE_BYTES="$(bytes_to_num "$LARGE_SIZE")"
LARGE_TOTAL_BYTES=$((LARGE_FILES * LARGE_SIZE_BYTES))

SUITE_START_NS="$(now_ns)"

echo "Run id:       $RUN_ID"
echo "Label:        $LABEL"
echo "Dest:         $DEST"
echo "FS type:      $FS_TYPE"
echo "Device:       $SOURCE_DEV"
echo "Sync policy:  $SYNC_POLICY"
echo "Runs:         $RUNS"
echo "Results:      $RESULTS"
echo
echo "Small:        $SMALL_FILES files x $SMALL_SIZE bytes"
echo "Large:        $LARGE_FILES files x $LARGE_SIZE"

for run in $(seq 1 "$RUNS"); do
  WORK="$DEST/fs-perf-suite-$RUN_ID-run-$run"
  mkdir -p "$WORK"

  REFLINK_SUPPORT="$(test_reflink_support "$WORK")"

  echo
  echo "######## RUN $run ########"
  echo "Work:         $WORK"
  echo "Reflink:      $REFLINK_SUPPORT"

  ms="$(run_test "small_write" write_small_files "$WORK")"
  record "$run" "small_write" "ok" "$ms" "$SMALL_FILES" "$SMALL_TOTAL_BYTES"

  ms="$(run_test "small_stat" stat_small_files "$WORK")"
  record "$run" "small_stat" "ok" "$ms" "$SMALL_FILES" "$SMALL_TOTAL_BYTES"

  ms="$(run_test "small_copy_default" copy_small_default "$WORK")"
  record "$run" "small_copy_default" "ok" "$ms" "$SMALL_FILES" "$SMALL_TOTAL_BYTES"

  ms="$(run_test "small_copy_reflink_never" copy_small_reflink_never "$WORK")"
  record "$run" "small_copy_reflink_never" "ok" "$ms" "$SMALL_FILES" "$SMALL_TOTAL_BYTES"

  if [[ "$REFLINK_SUPPORT" == "supported" ]]; then
    ms="$(run_test "small_copy_reflink_always" copy_small_reflink_always "$WORK")"
    record "$run" "small_copy_reflink_always" "ok" "$ms" "$SMALL_FILES" "$SMALL_TOTAL_BYTES"
  else
    record "$run" "small_copy_reflink_always" "unsupported" 0 "$SMALL_FILES" "$SMALL_TOTAL_BYTES" "cp --reflink=always not supported"
  fi

  ms="$(run_test "delete_small_copy_default" delete_small_default "$WORK")"
  record "$run" "delete_small_copy_default" "ok" "$ms" "$SMALL_FILES" "$SMALL_TOTAL_BYTES"

  ms="$(run_test "delete_small_copy_reflink_never" delete_small_reflink_never "$WORK")"
  record "$run" "delete_small_copy_reflink_never" "ok" "$ms" "$SMALL_FILES" "$SMALL_TOTAL_BYTES"

  if [[ "$REFLINK_SUPPORT" == "supported" ]]; then
    ms="$(run_test "delete_small_copy_reflink_always" delete_small_reflink_always "$WORK")"
    record "$run" "delete_small_copy_reflink_always" "ok" "$ms" "$SMALL_FILES" "$SMALL_TOTAL_BYTES"
  else
    record "$run" "delete_small_copy_reflink_always" "unsupported" 0 "$SMALL_FILES" "$SMALL_TOTAL_BYTES" "no reflink copy created"
  fi

  ms="$(run_test "rename_create_and_rename" rename_create_and_rename "$WORK")"
  record "$run" "rename_create_and_rename" "ok" "$ms" "$RENAME_FILES" 0

  ms="$(run_test "delete_many_small_files" delete_many_small_files "$WORK")"
  record "$run" "delete_many_small_files" "ok" "$ms" "$SMALL_FILES" 0

  ms="$(run_test "delete_nested_tree_100x100" delete_nested_tree "$WORK")"
  record "$run" "delete_nested_tree_100x100" "ok" "$ms" 10000 0

  ms="$(run_test "large_write_buffered" write_large_buffered "$WORK")"
  record "$run" "large_write_buffered" "ok" "$ms" "$LARGE_FILES" "$LARGE_TOTAL_BYTES"

  rm -rf "$WORK/large-write-buffered"

  ms="$(run_test "large_write_fsync" write_large_fsync "$WORK")"
  record "$run" "large_write_fsync" "ok" "$ms" "$LARGE_FILES" "$LARGE_TOTAL_BYTES"

  ms="$(run_test "large_copy_default" copy_large_default "$WORK")"
  record "$run" "large_copy_default" "ok" "$ms" "$LARGE_FILES" "$LARGE_TOTAL_BYTES"

  ms="$(run_test "large_copy_reflink_never" copy_large_reflink_never "$WORK")"
  record "$run" "large_copy_reflink_never" "ok" "$ms" "$LARGE_FILES" "$LARGE_TOTAL_BYTES"

  if [[ "$REFLINK_SUPPORT" == "supported" ]]; then
    ms="$(run_test "large_copy_reflink_always" copy_large_reflink_always "$WORK")"
    record "$run" "large_copy_reflink_always" "ok" "$ms" "$LARGE_FILES" "$LARGE_TOTAL_BYTES"
  else
    record "$run" "large_copy_reflink_always" "unsupported" 0 "$LARGE_FILES" "$LARGE_TOTAL_BYTES" "cp --reflink=always not supported"
  fi

  ms="$(run_test "delete_large_copy_default" delete_large_default "$WORK")"
  record "$run" "delete_large_copy_default" "ok" "$ms" "$LARGE_FILES" "$LARGE_TOTAL_BYTES"

  ms="$(run_test "delete_large_copy_reflink_never" delete_large_reflink_never "$WORK")"
  record "$run" "delete_large_copy_reflink_never" "ok" "$ms" "$LARGE_FILES" "$LARGE_TOTAL_BYTES"

  if [[ "$REFLINK_SUPPORT" == "supported" ]]; then
    ms="$(run_test "delete_large_copy_reflink_always" delete_large_reflink_always "$WORK")"
    record "$run" "delete_large_copy_reflink_always" "ok" "$ms" "$LARGE_FILES" "$LARGE_TOTAL_BYTES"
  else
    record "$run" "delete_large_copy_reflink_always" "unsupported" 0 "$LARGE_FILES" "$LARGE_TOTAL_BYTES" "no reflink copy created"
  fi

  total_files="$(find "$WORK" -type f | wc -l | tr -d ' ')"

  ms="$(run_test "tree_walk" tree_walk "$WORK")"
  record "$run" "tree_walk" "ok" "$ms" "$total_files" 0

  if [[ "$KEEP" -eq 0 ]]; then
    ms="$(run_test "cleanup_all" cleanup_all "$WORK")"
    record "$run" "cleanup_all" "ok" "$ms" "$total_files" 0
  fi
done

SUITE_END_NS="$(now_ns)"
SUITE_MS="$(elapsed_ms "$SUITE_START_NS" "$SUITE_END_NS")"

echo
echo "==== RESULTS ===="
column -t -s $'\t' "$RESULTS"

echo
echo "==== AVERAGES BY TEST ===="
awk '
BEGIN { FS="\t" }
NR == 1 { next }
$3 == "ok" {
  count[$2]++
  total_ms[$2] += $4
  total_ops_s[$2] += $7
  total_mib_s[$2] += $9
}
END {
  printf "%-36s %12s %16s %16s\n", "test", "avg_ms", "avg_ops_s", "avg_mib_s"
  for (t in count) {
    printf "%-36s %12.3f %16.3f %16.3f\n", t, total_ms[t] / count[t], total_ops_s[t] / count[t], total_mib_s[t] / count[t]
  }
}
' "$RESULTS" | sort

cat > "$SUMMARY" <<EOF
{
  "run_id": "$RUN_ID",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "label": "$LABEL",
  "dest": "$DEST",
  "fs_type": "$FS_TYPE",
  "source_device": "$SOURCE_DEV",
  "mount_options": "$MOUNT_OPTS",
  "df": "$DF_LINE",
  "sync_policy": "$SYNC_POLICY",
  "runs": $RUNS,
  "small_files": $SMALL_FILES,
  "small_size_bytes": $SMALL_SIZE,
  "large_files": $LARGE_FILES,
  "large_size": "$LARGE_SIZE",
  "large_size_bytes": $LARGE_SIZE_BYTES,
  "suite_ms": $SUITE_MS,
  "results_tsv": "$RESULTS"
}
EOF

echo
echo "Suite ms: $SUITE_MS"
echo "TSV:      $RESULTS"
echo "JSON:     $SUMMARY"
