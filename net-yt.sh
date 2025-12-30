#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

URL="https://youtu.be/ipIpa8pJ61w"
INSTANCES=2                 # 2 recommended for mobile
MAX_GB=10                   # <-- change: 10 / 35 etc.
SLEEP_NO_NET=5              # seconds between retries when no net

# --- deps ---
pkg install -y yt-dlp pv coreutils >/dev/null 2>&1

MAX_BYTES=$((MAX_GB * 1024 * 1024 * 1024))
TMPDIR="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"

# FIFO for aggregation
PIPE="$TMPDIR/ytpipe.$$"
mkfifo "$PIPE"
cleanup() { rm -f "$PIPE" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# Helper: basic connectivity check (DNS + reachability)
has_net() {
  # try quick DNS + TCP reachability
  (timeout 3 sh -c 'getent hosts youtube.com >/dev/null 2>&1') && return 0
  return 1
}

echo "[*] Target: ${MAX_GB}GB | instances=${INSTANCES}"
echo "[*] Will retry on network loss. Stop earlier with Ctrl+C."

# Run pv to count bytes; stop when cap reached
# pv exits when input closes; we'll close input when cap reached
BYTES_COUNTED=0

# Start pv reader in background; we parse its byte counter via -n (numeric)
# -n prints number of bytes transferred to stderr periodically; we redirect & read it
PV_LOG="$TMPDIR/pvlog.$$"
: > "$PV_LOG"

# pv: output numeric byte count every 1s to PV_LOG
(pv -n -i 1 < "$PIPE" > /dev/null 2> "$PV_LOG") &
PV_PID=$!

start_batch() {
  for i in $(seq 1 "$INSTANCES"); do
    yt-dlp -f bestvideo[protocol=https]/bestvideo \
      --no-part --no-cache-dir -o - "$URL" 2>/dev/null >> "$PIPE" &
  done
}

while true; do
  # Update counted bytes from pv log
  if [[ -s "$PV_LOG" ]]; then
    BYTES_COUNTED=$(tail -n 1 "$PV_LOG" 2>/dev/null || echo 0)
  fi

  if (( BYTES_COUNTED >= MAX_BYTES )); then
    echo
    echo "[*] Reached cap: ${MAX_GB}GB. Stopping."
    break
  fi

  if ! has_net; then
    echo "[!] No internet. Waiting ${SLEEP_NO_NET}s..."
    sleep "$SLEEP_NO_NET"
    continue
  fi

  echo "[*] Net OK. Running batch..."
  start_batch
  wait || true

  # brief pause before next cycle (helps avoid tight-loop if throttled)
  sleep 1
done

# stop pv cleanly
kill "$PV_PID" >/dev/null 2>&1 || true
echo "Done."
