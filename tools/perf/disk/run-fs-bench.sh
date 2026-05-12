#!/usr/bin/env bash
set -euo pipefail

DEST="${1:?Usage: $0 /opt/data/sam/perf <label>}"
LABEL="${2:?Usage: $0 /opt/data/sam/perf <label>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE="$SCRIPT_DIR/fs-perf-suite.sh"

[[ -x "$SUITE" ]] || {
  echo "Missing executable: $SUITE" >&2
  exit 1
}

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="/tmp/fs-full-bench-$RUN_ID"
mkdir -p "$OUT_DIR"

echo "Full bench run: $RUN_ID"
echo "Dest:           $DEST"
echo "Label:          $LABEL"
echo "Output:         $OUT_DIR"

run_case() {
  local name="$1"
  shift

  echo
  echo "########################################"
  echo "CASE: $name"
  echo "########################################"

  "$SUITE" \
    --dest "$DEST" \
    --label "${LABEL}-${name}" \
    --out-dir "$OUT_DIR" \
    "$@" \
    2>&1 | tee "$OUT_DIR/${name}.log"
}

# Fast smoke check
run_case "smoke-none" \
  --runs 1 \
  --sync-policy none \
  --small-files 5000 \
  --small-size 4096 \
  --large-files 2 \
  --large-size 512M \
  --rename-files 5000

# Main realistic ingestor profile
run_case "ingestor-realistic-none" \
  --runs 3 \
  --sync-policy none \
  --small-files 50000 \
  --small-size 65536 \
  --large-files 8 \
  --large-size 1G \
  --rename-files 50000

# Conservative durability profile
run_case "ingestor-durable-after" \
  --runs 3 \
  --sync-policy after \
  --small-files 50000 \
  --small-size 65536 \
  --large-files 8 \
  --large-size 1G \
  --rename-files 50000

# Metadata-heavy stress
run_case "metadata-heavy-none" \
  --runs 3 \
  --sync-policy none \
  --small-files 100000 \
  --small-size 4096 \
  --large-files 2 \
  --large-size 1G \
  --rename-files 100000

# Large file throughput
run_case "large-io-none" \
  --runs 3 \
  --sync-policy none \
  --small-files 5000 \
  --small-size 4096 \
  --large-files 8 \
  --large-size 4G \
  --rename-files 5000

# Large durable write/copy pressure
run_case "large-io-after" \
  --runs 2 \
  --sync-policy after \
  --small-files 5000 \
  --small-size 4096 \
  --large-files 8 \
  --large-size 4G \
  --rename-files 5000

echo
echo "Done."
echo "Logs and TSV/JSON outputs under:"
echo "$OUT_DIR"
