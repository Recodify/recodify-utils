#!/usr/bin/env bash

set -e

echo "==============================="
echo "WSL / Filesystem Diagnostics"
echo "==============================="

echo
echo "---- System Info ----"
uname -a || true
echo
echo "WSL version info from Windows:"
powershell.exe -Command "wsl -l -v" 2>/dev/null || true

echo
echo "---- Disk Usage ----"
df -hT

echo
echo "==============================="
echo "1. Large Sequential Write Test"
echo "==============================="
rm -f /tmp/wsl_big_test.bin
time dd if=/dev/zero of=/tmp/wsl_big_test.bin bs=1M count=3072 status=progress conv=fdatasync
rm -f /tmp/wsl_big_test.bin

echo
echo "==============================="
echo "2. Small File Creation Test"
echo "==============================="
rm -rf /tmp/wsl_small_src /tmp/wsl_small_dst
mkdir -p /tmp/wsl_small_src /tmp/wsl_small_dst

echo "Creating 20k small files..."
time bash -c 'for i in {1..20000}; do echo "hello" > /tmp/wsl_small_src/$i.csv; done'

echo
echo "Copying 20k small files with cp..."
time cp -a /tmp/wsl_small_src/. /tmp/wsl_small_dst/

rm -rf /tmp/wsl_small_src /tmp/wsl_small_dst

echo
echo "==============================="
echo "3. Rsync Test on 20k Files"
echo "==============================="
mkdir -p /tmp/wsl_small_src /tmp/wsl_small_dst
for i in {1..20000}; do echo "hello" > /tmp/wsl_small_src/$i.csv; done

time rsync -a --whole-file --no-compress /tmp/wsl_small_src/ /tmp/wsl_small_dst/

rm -rf /tmp/wsl_small_src /tmp/wsl_small_dst

echo
echo "==============================="
echo "4. Tar Stream Test on 20k Files"
echo "==============================="
mkdir -p /tmp/wsl_small_src /tmp/wsl_small_dst
for i in {1..20000}; do echo "hello" > /tmp/wsl_small_src/$i.csv; done

time bash -c 'cd /tmp/wsl_small_src && tar -cf - . | (cd /tmp/wsl_small_dst && tar -xf -)'

rm -rf /tmp/wsl_small_src /tmp/wsl_small_dst

echo
echo "==============================="
echo "Done"
echo "==============================="