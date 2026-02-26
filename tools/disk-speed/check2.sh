
#!/usr/bin/env bash
set -euo pipefail

NFILES="${NFILES:-20000}"
BIG_MB="${BIG_MB:-3072}"
SMALL_BYTES="${SMALL_BYTES:-6}"

have() { command -v "$1" >/dev/null 2>&1; }

now_ns() { date +%s%N; }

dur_s() {
  python3 -c "import sys; s=int(sys.argv[1]); e=int(sys.argv[2]); print((e-s)/1e9)" "$1" "$2"
}

fmt_s() {
  python3 -c "import sys; v=float(sys.argv[1]); print(f'{int(v//60)}m{v%60:0.2f}s' if v>=60 else f'{v:0.2f}s')" "$1"
}

rate() {
  python3 -c "import sys; u=float(sys.argv[1]); s=float(sys.argv[2]); print('inf' if s<=0 else u/s)" "$1" "$2"
}

human_bytes() {
  python3 -c "import sys; n=int(sys.argv[1]); u=['B','KB','MB','GB','TB']; i=0; x=float(n)
while x>=1024 and i<len(u)-1:
    x/=1024
    i+=1
print(f'{x:.2f}{u[i]}')" "$1"
}

section() {
  echo
  echo "========================================"
  echo "$1"
  echo "========================================"
}

cleanup() {
  rm -rf /tmp/wsl_small_src /tmp/wsl_small_dst /tmp/wsl_big_test.bin 2>/dev/null || true
}
trap cleanup EXIT

must_writable_tmp() {
  local f="/tmp/wsl_io_diag_write_test.$$"
  echo "test" > "$f"
  rm -f "$f"
}

dir_bytes() {
  python3 -c "import os,sys; root=sys.argv[1]; t=0
for b,_,fs in os.walk(root):
    for f in fs:
        p=os.path.join(b,f)
        try:
            st=os.stat(p)
            if os.path.isfile(p):
                t+=st.st_size
        except FileNotFoundError:
            pass
print(t)" "$1"
}

count_files() {
  find "$1" -type f 2>/dev/null | wc -l | tr -d ' '
}

make_small_tree() {
  local dir="$1"
  rm -rf "$dir"
  mkdir -p "$dir"
  local payload
  payload="$(python3 -c "print('x'*int('${SMALL_BYTES}'))")"
  local i
  for ((i=1;i<=NFILES;i++)); do
    printf "%s" "$payload" > "${dir}/${i}.csv"
  done
}

section "Preflight"
echo "Settings: NFILES=${NFILES}, BIG_MB=${BIG_MB}MB, SMALL_BYTES=${SMALL_BYTES}"
for cmd in bash dd cp tar find wc uname df date; do
  have "$cmd" || { echo "Missing required command: $cmd"; exit 1; }
done
have python3 || { echo "Missing required command: python3"; exit 1; }
must_writable_tmp
echo "OK: /tmp is writable"

section "System and Disk Info"
uname -a || true
echo
df -hT || true

echo
if have powershell.exe; then
  echo "Windows C: free space (PowerShell):"
  powershell.exe -NoProfile -Command "Get-PSDrive -Name C | Select-Object Used,Free,Name | Format-Table -AutoSize" 2>/dev/null || true
  echo
  echo "WSL distros and versions (PowerShell):"
  powershell.exe -NoProfile -Command "wsl -l -v" 2>/dev/null || true
else
  echo "Note: powershell.exe not found, skipping Windows-side checks"
fi

section "Test 1: Big sequential write (dd to /tmp, fdatasync)"
rm -f /tmp/wsl_big_test.bin
s="$(now_ns)"
dd if=/dev/zero of=/tmp/wsl_big_test.bin bs=1M count="${BIG_MB}" status=none conv=fdatasync
e="$(now_ns)"
secs="$(dur_s "$s" "$e")"
mbps="$(rate "$BIG_MB" "$secs")"
echo "Wrote ${BIG_MB}MB in $(fmt_s "$secs")"
python3 -c "import sys; print(f'Throughput: {float(sys.argv[1]):.2f} MB/s')" "$mbps"
rm -f /tmp/wsl_big_test.bin

section "Test 2: Create ${NFILES} small files in /tmp"
s="$(now_ns)"
make_small_tree "/tmp/wsl_small_src"
e="$(now_ns)"
secs="$(dur_s "$s" "$e")"
ops="$(rate "$NFILES" "$secs")"
bytes="$(dir_bytes "/tmp/wsl_small_src")"
hbytes="$(human_bytes "$bytes")"
echo "Created $(count_files /tmp/wsl_small_src) files, total payload ${hbytes}, in $(fmt_s "$secs")"
python3 -c "import sys; print(f'Create rate: {float(sys.argv[1]):.2f} files/s')" "$ops"

section "Test 3: Copy ${NFILES} small files using cp -a"
rm -rf /tmp/wsl_small_dst
mkdir -p /tmp/wsl_small_dst
s="$(now_ns)"
cp -a /tmp/wsl_small_src/. /tmp/wsl_small_dst/
e="$(now_ns)"
secs="$(dur_s "$s" "$e")"
ops="$(rate "$NFILES" "$secs")"
bytes2="$(dir_bytes "/tmp/wsl_small_dst")"
hbytes2="$(human_bytes "$bytes2")"
echo "Copied $(count_files /tmp/wsl_small_dst) files, total payload ${hbytes2}, in $(fmt_s "$secs")"
python3 -c "import sys; print(f'Copy rate (cp): {float(sys.argv[1]):.2f} files/s')" "$ops"
rm -rf /tmp/wsl_small_dst

section "Test 4: rsync local copy (optional)"
if have rsync; then
  mkdir -p /tmp/wsl_small_dst
  s="$(now_ns)"
  rsync -a --whole-file --no-compress --stats /tmp/wsl_small_src/ /tmp/wsl_small_dst/ | sed 's/\\r$//' || true
  e="$(now_ns)"
  secs="$(dur_s "$s" "$e")"
  ops="$(rate "$NFILES" "$secs")"
  echo "rsync wall time: $(fmt_s "$secs")"
  python3 -c "import sys; print(f'Copy rate (rsync): {float(sys.argv[1]):.2f} files/s')" "$ops"
  rm -rf /tmp/wsl_small_dst
else
  echo "Skipping rsync test, rsync not installed"
fi

section "Test 5: tar stream (tar | tar)"
mkdir -p /tmp/wsl_small_dst
s="$(now_ns)"
bash -c 'cd /tmp/wsl_small_src && tar -cf - . | (cd /tmp/wsl_small_dst && tar -xf -)'
e="$(now_ns)"
secs="$(dur_s "$s" "$e")"
ops="$(rate "$NFILES" "$secs")"
echo "tar stream wall time: $(fmt_s "$secs")"
python3 -c "import sys; print(f'Copy rate (tar stream): {float(sys.argv[1]):.2f} files/s')" "$ops"

rm -rf /tmp/wsl_small_src /tmp/wsl_small_dst

section "Done"
echo "If big-file throughput is high but small-file rates are low, this is metadata interception overhead."
"""

file_path = "/mnt/data/wsl_io_diag.sh"
with open(file_path, "w", newline="\n") as f:
    f.write(script_content)

file_path