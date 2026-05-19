#!/usr/bin/env bash
# io_variance_test.sh
#
# Repro script to show why runs are sometimes fast and sometimes slow by capturing:
#   - metadata-heavy copy (tar pipe) throughput
#   - sequential write (dd oflag=direct) throughput
#   - iostat -x stats (latency/await/%util)
#   - Dirty/Writeback memory (writeback throttling signal)
#
# Usage examples:
#   sudo bash io_variance_test.sh --src /opt/data/library --dst-base /opt/data --runs 5
#   sudo bash io_variance_test.sh --src /opt/data/library --dst-base /opt/data --runs 5 --mountpoint /opt/data --mode nodiscard
#   sudo bash io_variance_test.sh --src /opt/data/library --dst-base /opt/data --runs 5 --mountpoint /opt/data --mode discard
#
set -euo pipefail

SRC=""
DST_BASE=""
RUNS=5

# keep = don't change mount options
# nodiscard/discard = try remounting (may not reflect in findmnt on some setups)
MODE="keep"
MOUNTPOINT=""

# device for iostat; auto-detect from dst-base if not provided
DEVICE=""

# sequential test size: bs * count = 64MiB * 256 = 16GiB
BS="64M"
COUNT=256

OUTDIR=""
TAR_EXTRACT_OPTS=(--no-same-owner --no-same-permissions)

usage() {
  cat <<'EOF'
Usage: sudo io_variance_test.sh --src <dir> --dst-base <dir> [options]

Required:
  --src <dir>         Source directory to copy (e.g. /opt/data/library)
  --dst-base <dir>    Parent directory for destinations (e.g. /opt/data)

Options:
  --runs <n>          Number of runs (default: 5)
  --mode <keep|nodiscard|discard>
                      Attempt to remount mountpoint before each run (default: keep)
  --mountpoint <mp>   Required if mode != keep (e.g. /opt/data)
  --device <dev>      Block device for iostat (e.g. /dev/sdd). If omitted, auto-detect.
  --outdir <dir>      Where to write logs (default: ./io_test_logs_<timestamp>)
  --count <n>         dd count with bs=64M (default: 256 => 16GiB)

What you get:
  - summary.csv with run timings + throughput
  - per-run iostat logs and Dirty/Writeback logs
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }

ts() { date +"%Y-%m-%d_%H-%M-%S"; }

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --src) SRC="${2:-}"; shift 2;;
    --dst-base) DST_BASE="${2:-}"; shift 2;;
    --runs) RUNS="${2:-}"; shift 2;;
    --mode) MODE="${2:-}"; shift 2;;
    --mountpoint) MOUNTPOINT="${2:-}"; shift 2;;
    --device) DEVICE="${2:-}"; shift 2;;
    --outdir) OUTDIR="${2:-}"; shift 2;;
    --count) COUNT="${2:-}"; shift 2;;
    -h|--help) usage; exit 0;;
    *) die "Unknown argument: $1";;
  esac
done

[[ -n "$SRC" ]] || { usage; die "--src is required"; }
[[ -n "$DST_BASE" ]] || { usage; die "--dst-base is required"; }
[[ -d "$SRC" ]] || die "Source dir not found: $SRC"
[[ -d "$DST_BASE" ]] || die "Dest base dir not found: $DST_BASE"
[[ "$MODE" =~ ^(keep|nodiscard|discard)$ ]] || die "--mode must be keep|nodiscard|discard"

need tar
need dd
need awk
need date
need sync
need df
need findmnt
need mount
need iostat || die "Missing iostat (sysstat). Install: sudo apt-get install -y sysstat"
need python3

if [[ "$MODE" != "keep" ]]; then
  [[ -n "$MOUNTPOINT" ]] || die "--mountpoint is required when --mode != keep"
  [[ -d "$MOUNTPOINT" ]] || die "Mountpoint not found: $MOUNTPOINT"
fi

if [[ -z "$OUTDIR" ]]; then
  OUTDIR="./io_test_logs_$(ts)"
fi
mkdir -p "$OUTDIR"

# Auto-detect DEVICE if not provided
if [[ -z "$DEVICE" ]]; then
  FSDEV="$(df -P "$DST_BASE" | tail -1 | awk '{print $1}')"
  # For dm/lvm, try to find underlying physical disk; fall back to FSDEV.
  if [[ "$FSDEV" =~ ^/dev/mapper/ || "$FSDEV" =~ ^/dev/dm- ]]; then
    PK="$(lsblk -ndo PKNAME "$FSDEV" 2>/dev/null | head -n1 || true)"
    if [[ -n "$PK" ]]; then
      DEVICE="/dev/$PK"
    else
      DEVICE="$FSDEV"
    fi
  else
    PK="$(lsblk -ndo PKNAME "$FSDEV" 2>/dev/null | head -n1 || true)"
    [[ -n "$PK" ]] && DEVICE="/dev/$PK" || DEVICE="$FSDEV"
  fi
fi

echo "== Config =="
echo "SRC       : $SRC"
echo "DST_BASE  : $DST_BASE"
echo "RUNS      : $RUNS"
echo "MODE      : $MODE"
echo "MOUNTPOINT: ${MOUNTPOINT:-<none>}"
echo "DEVICE    : $DEVICE"
echo "OUTDIR    : $OUTDIR"
echo

SUMMARY="$OUTDIR/summary.csv"
echo "run,mode,tar_dest,tar_seconds,tar_mibps,dd_seconds,dd_gibps,mount_opts" > "$SUMMARY"

# Parse pv last line like: "9.06GiB 0:00:19 [ 480MiB/s] ..."
parse_pv_mibps() {
  local line="$1"
  python3 - <<PY
import re
s = """$line"""
m = re.search(r"\[\s*([0-9.]+)\s*(MiB/s|GiB/s)\s*\]", s)
if not m:
    print("NA")
else:
    v = float(m.group(1))
    u = m.group(2)
    if u == "GiB/s":
        v *= 1024.0
    print(f"{v:.2f}")
PY
}

remount_mode() {
  local mode="$1"
  local mp="$2"
  [[ "$mode" == "keep" ]] && return 0
  echo "Remounting $mp with $mode ..."
  # Some kernels/XFS stacks may not reflect this in findmnt; we still record behavior.
  mount -o "remount,$mode" "$mp" >/dev/null 2>&1 || echo "WARN: remount returned non-zero"
  echo "Mount opts now: $(findmnt -no OPTIONS "$mp" 2>/dev/null || echo '?')"
}

start_monitors() {
  local tag="$1"
  local iolog="$OUTDIR/iostat_${tag}.log"
  local memlog="$OUTDIR/mem_${tag}.log"

  ( iostat -x 1 "$DEVICE" ) >"$iolog" 2>&1 &
  echo $! >"$OUTDIR/iostat_${tag}.pid"

  ( while true; do
      printf "%s " "$(date +%H:%M:%S)"
      grep -E '^(Dirty|Writeback):' /proc/meminfo | tr '\n' ' '
      echo
      sleep 1
    done ) >"$memlog" 2>&1 &
  echo $! >"$OUTDIR/mem_${tag}.pid"
}

stop_monitors() {
  local tag="$1"
  for p in "$OUTDIR/iostat_${tag}.pid" "$OUTDIR/mem_${tag}.pid"; do
    [[ -f "$p" ]] || continue
    pid="$(cat "$p" || true)"
    if [[ -n "${pid:-}" ]]; then
      kill "$pid" >/dev/null 2>&1 || true
      wait "$pid" >/dev/null 2>&1 || true
    fi
    rm -f "$p"
  done
}

run_one() {
  local run="$1"
  local mode="$2"

  local tag="run${run}_${mode}_$(ts)"
  local dest="$DST_BASE/library2_${mode}_${run}_$(date +%s)"
  local pvlog="$OUTDIR/pv_${tag}.log"

  echo "=== Run $run/$RUNS mode=$mode ==="
  echo "Dest: $dest"

  sync
  if [[ "$mode" != "keep" ]]; then
    remount_mode "$mode" "$MOUNTPOINT"
  fi

  mkdir -p "$dest"
  start_monitors "$tag"

  # TAR PIPE
  local tar_start tar_end tar_sec tar_mibps
  tar_start="$(date +%s.%N)"

  if command -v pv >/dev/null 2>&1; then
    # pv progress goes to stderr -> capture it
    ( cd "$SRC" && tar -cf - . ) | pv | ( cd "$dest" && tar -xpf - "${TAR_EXTRACT_OPTS[@]}" ) 2>"$pvlog"
    last="$(tail -n 1 "$pvlog" | tr -d '\r')"
    tar_mibps="$(parse_pv_mibps "$last")"
  else
    echo "pv not installed; tar throughput not parsed" >"$pvlog"
    ( cd "$SRC" && tar -cf - . ) | ( cd "$dest" && tar -xpf - "${TAR_EXTRACT_OPTS[@]}" )
    tar_mibps="NA"
  fi

  tar_end="$(date +%s.%N)"
  tar_sec="$(python3 - <<PY
s=float("$tar_end")-float("$tar_start")
print(f"{s:.3f}")
PY
)"

  sync

  # SEQUENTIAL WRITE (dd)
  local ddfile="$DST_BASE/seq_${mode}_${run}.test"
  local dd_start dd_end dd_sec dd_gibps
  dd_start="$(date +%s.%N)"
  dd if=/dev/zero of="$ddfile" bs="$BS" count="$COUNT" oflag=direct status=none
  sync
  rm -f "$ddfile"
  dd_end="$(date +%s.%N)"
  dd_sec="$(python3 - <<PY
s=float("$dd_end")-float("$dd_start")
print(f"{s:.3f}")
PY
)"
  dd_gibps="$(python3 - <<PY
sec=float("$dd_sec")
gib=(($COUNT*64)/1024)  # 64MiB * count => MiB -> GiB
print(f"{gib/sec:.2f}")
PY
)"

  stop_monitors "$tag"

  local opts
  if [[ -n "${MOUNTPOINT:-}" ]]; then
    opts="$(findmnt -no OPTIONS "$MOUNTPOINT" 2>/dev/null | head -c 200 || true)"
  else
    opts="$(findmnt -no OPTIONS "$DST_BASE" 2>/dev/null | head -c 200 || true)"
  fi

  echo "TAR: ${tar_sec}s @ ${tar_mibps} MiB/s"
  echo "DD : ${dd_sec}s @ ${dd_gibps} GiB/s"
  echo

  echo "$run,$mode,$dest,$tar_sec,$tar_mibps,$dd_sec,$dd_gibps,\"$opts\"" >> "$SUMMARY"
}

for r in $(seq 1 "$RUNS"); do
  run_one "$r" "$MODE"
done

echo "Done. Logs in: $OUTDIR"
echo "Summary: $SUMMARY"
echo
if command -v column >/dev/null 2>&1; then
  column -s, -t "$SUMMARY" | sed 's/\"//g'
else
  cat "$SUMMARY"
fi