#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# ===== Settings (change if you want) =====
URL="https://youtu.be/ipIpa8pJ61w"
INSTANCES=3          # recommended: 2 (try 3 if stable)
DURATION=3000000         # seconds (5 min test). increase if you want
# ========================================

pkg install -y yt-dlp pv coreutils >/dev/null 2>&1

TMPDIR="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
PIPE="$TMPDIR/ytpipe.$$"

cleanup() {
  rm -f "$PIPE" >/dev/null 2>&1 || true
}
trap cleanup EXIT

mkfifo "$PIPE"

echo "[*] YouTube test: instances=$INSTANCES | duration=${DURATION}s"
echo "[*] Only pv output will be shown."

# Start pv reader (only visible output)
pv -brat -i 1 < "$PIPE" > /dev/null &
PV_PID=$!

# Start multiple yt-dlp writers (silenced), each limited by timeout
for i in $(seq 1 "$INSTANCES"); do
  timeout "$DURATION" yt-dlp \
    -f bestvideo[protocol=https]/bestvideo \
    --no-part --no-cache-dir \
    -o - "$URL" \
    2>/dev/null >> "$PIPE" &
done

# Wait writers to finish, then stop pv
wait || true
kill "$PV_PID" >/dev/null 2>&1 || true

echo "Done."
