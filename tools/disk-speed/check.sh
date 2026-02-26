#!/usr/bin/env bash
set -euo pipefail

# -------- Config (override via env) --------
NFILES="${NFILES:-20000}"     # small file count
BIG_MB="${BIG_MB:-3072}"      # big file size in MB (default 3GB)
SMALL_BYTES="${SMALL_BYTES:-6}" # bytes per small file payload

# -------- Helpers --------
have() { command -v "$1" >/dev/null 2>&1; }

now_ns() {
  # date +%s%N is available on GNU coreutils, typical in Ubuntu WSL
  date +%s%N
}

dur_s_from_ns() {
  local start_ns="$1"
  local end_ns="$2"
  python3 - <<'PY'
import sys
start=int(sys.argv[1]); end=int(sys.argv[2])
print((end-start)/1e9)
PY
}

fmt() {
  python3 - <<'PY'
import sys
v=float(sys.argv[1])
if v >= 60:
  m=int(v//60); s=v-m*60
  print(f"{m}m{s:0.2f}s")
else:
  print(f"{v:0.2f}s")
PY
}

human_bytes() {
  python3 - <<'PY'
import sys
n=int(sys.argv[1])
units=["B","KB","MB","GB","TB"]
u=0
x=float(n)
while x>=1024 and u < len(units)-1:
  x/=1024
  u+=1
print(f"{x:.2f}{units[u]}")
PY
}

rate() {
  # rate(units, seconds) -> units per second
  python3 - <<'PY'
import sys
units=float(sys.argv[1]); sec=float(sys.argv[2])
if sec <= 0:
  print("inf")
else:
  print(units/sec)
PY
}

section() {
  echo
  echo "========================================"
  echo "$1"
  echo "========================================"
}

must_writable_tmp() {
  local f="/tmp/wsl_io_diag_write_test.$$"
  echo "test" > "$f"
  rm -f "$f"
}

dir_bytes() {
  # total bytes of regular files in dir
  # busybox du differs, use find+stat to be safe
  local d="$1"
  python3 - <<'PY'
import os, sys
root=sys.argv[1]
total=0
for base, _, files in os.walk(root):
  for f in files:
    p=os.path.join(base,f)
    try:
      st=os.stat(p)
      if os.path.isfile(p):
        total += st.st_size
    except FileNotFoundError:
      pass
print(total)
PY "$d"
}

count_files() {
  local d="$1"
  find "$d" -type f 2>/dev/null | wc -l | tr -d ' '
}

cleanup() {
  rm -rf /tmp/wsl_small_src /tmp/wsl_small_dst /tmp/wsl_big_test.bin /tmp/wsl_tar_test.tar 2>/dev/null || true
}
trap cleanup EXIT

# -------- Preflight --------
section "Preflight"

echo "Script settings:"
echo "  NFILES=${NFILES}"
echo "  BIG_MB=${BIG_MB} (MB)"
echo

for cmd in bash dd cp tar find wc uname df; do
  if ! have "$cmd"; then
    echo "Missing required command: $cmd"
    exit 1
  fi
done

if ! have python3; then
  echo "Missing required command: python3 (used for timings and formatting)"
  exit 1
fi

must_writable_tmp
echo "OK: /tmp is writable"

section "System and Disk Info"
uname -a || true
echo
echo "Filesystem usage (WSL view):"
df -hT || true

echo
if have powershell.exe; then
  echo "Windows C: free space (from PowerShell):"
  powershell.exe -NoProfile -Command "Get-PSDrive -Name C | Select-Object Used,Free,Name | Format-Table -AutoSize" 2>/dev/null || true
  echo
  echo "WSL distros and versions (from PowerShell):"
  powershell.exe -NoProfile -Command "wsl -l -v" 2>/dev/null || true
else
  echo "Note: powershell.exe not found, skipping Windows-side checks"
fi

# -------- Test 1: Big sequential write --------
section "Test 1: Big sequential write (dd to /tmp, fdatasync)"

rm -f /tmp/wsl_big_test.bin
start_ns="$(now_ns)"
dd if=/dev/zero of=/tmp/wsl_big_test.bin bs=1M count="${BIG_MB}" status=none conv=fdatasync
end_ns="$(now_ns)"

secs="$(dur_s_from_ns "$start_ns" "$end_ns")"
mbps="$(rate "$BIG_MB" "$secs")"

echo "Wrote ${BIG_MB}MB in $(fmt "$secs")"
python3 - <<PY
mbps=float("$mbps")
print(f"Throughput: {mbps:.2f} MB/s")
PY

rm -f /tmp/wsl_big_test.bin

# -------- Prepare small file sets --------
make_small_tree() {
  local dir="$1"
  rm -rf "$dir"
  mkdir -p "$dir"
  # Create NFILES with fixed payload without spawning 20k processes if possible
  # Still one redirection per file, but less overhead than echo each time in subshell
  local payload
  payload="$(python3 - <<PY
print("x"*int("${SMALL_BYTES}"))
PY
)"
  local i
  for ((i=1;i<=NFILES;i++)); do
    printf "%s" "$payload" > "${dir}/${i}.csv"
  done
}

# -------- Test 2: Small file creation --------
section "Test 2: Create ${NFILES} small files in /tmp (metadata pressure)"

start_ns="$(now_ns)"
make_small_tree "/tmp/wsl_small_src"
end_ns="$(now_ns)"

secs="$(dur_s_from_ns "$start_ns" "$end_ns")"
ops="$(rate "$NFILES" "$secs")"
bytes="$(dir_bytes "/tmp/wsl_small_src")"
hbytes="$(human_bytes "$bytes")"

echo "Created $(count_files /tmp/wsl_small_src) files, total payload ${hbytes}, in $(fmt "$secs")"
python3 - <<PY
ops=float("$ops")
print(f"Create rate: {ops:.2f} files/s")
PY

# -------- Test 3: cp -a small files --------
section "Test 3: Copy ${NFILES} small files using cp -a"

rm -rf /tmp/wsl_small_dst
mkdir -p /tmp/wsl_small_dst

start_ns="$(now_ns)"
cp -a /tmp/wsl_small_src/. /tmp/wsl_small_dst/
end_ns="$(now_ns)"

secs="$(dur_s_from_ns "$start_ns" "$end_ns")"
ops="$(rate "$NFILES" "$secs")"
bytes2="$(dir_bytes "/tmp/wsl_small_dst")"
hbytes2="$(human_bytes "$bytes2")"

echo "Copied $(count_files /tmp/wsl_small_dst) files, total payload ${hbytes2}, in $(fmt "$secs")"
python3 - <<PY
ops=float("$ops")
print(f"Copy rate (cp): {ops:.2f} files/s")
PY

rm -rf /tmp/wsl_small_dst

# -------- Test 4: rsync small files --------
section "Test 4: rsync -a --whole-file --no-compress (local copy)"

if ! have rsync; then
  echo "Skipping: rsync not installed"
else
  mkdir -p /tmp/wsl_small_dst
  start_ns="$(now_ns)"
  # Capture rsync stats for context
  rsync -a --whole-file --no-compress --stats /tmp/wsl_small_src/ /tmp/wsl_small_dst/ | sed 's/\r$//' || true
  end_ns="$(now_ns)"

  secs="$(dur_s_from_ns "$start_ns" "$end_ns")"
  ops="$(rate "$NFILES" "$secs")"
  echo "rsync wall time: $(fmt "$secs")"
  python3 - <<PY
ops=float("$ops")
print(f"Copy rate (rsync): {ops:.2f} files/s")
PY
  rm -rf /tmp/wsl_small_dst
fi

# -------- Test 5: tar stream --------
section "Test 5: tar stream (tar | tar), avoids rsync scanning overhead"

mkdir -p /tmp/wsl_small_dst
start_ns="$(now_ns)"
bash -c 'cd /tmp/wsl_small_src && tar -cf - . | (cd /tmp/wsl_small_dst && tar -xf -)'
end_ns="$(now_ns)"

secs="$(dur_s_from_ns "$start_ns" "$end_ns")"
ops="$(rate "$NFILES" "$secs")"

echo "tar stream wall time: $(fmt "$secs")"
python3 - <<PY
ops=float("$ops")
print(f"Copy rate (tar stream): {ops:.2f} files/s")
PY

rm -rf /tmp/wsl_small_src /tmp/wsl_small_dst

section "Done"
echo "If big-file throughput is high but small-file rates are low, this is metadata interception overhead (common on corp machines)."