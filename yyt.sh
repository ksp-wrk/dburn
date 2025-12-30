#!/data/data/com.termux/files/usr/bin/bash
set -u

URL="https://youtu.be/ipIpa8pJ61w"
INSTANCES=2
CHECK_INTERVAL=5

pkg install -y yt-dlp pv coreutils >/dev/null 2>&1

TMPDIR="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
PIPE_TOTAL="$TMPDIR/yt_total.$$"
PIPE1="$TMPDIR/yt_1.$$"
PIPE2="$TMPDIR/yt_2.$$"

cleanup() {
  rm -f "$PIPE_TOTAL" "$PIPE1" "$PIPE2" 2>/dev/null
}
trap cleanup EXIT

mkfifo "$PIPE_TOTAL" "$PIPE1" "$PIPE2"

# -------- net check (reliable) ----------
has_net() {
  curl -s --max-time 3 -I https://clients3.google.com/generate_204 >/dev/null 2>&1
}

echo "[*] YouTube live test started"
echo "[*] Instances: $INSTANCES"
echo "[*] Ctrl+C to stop"
echo

# -------- PV DISPLAY ----------
(
  pv -brat -i 1 < "$PIPE_TOTAL" > /dev/null
) &

(
  pv -brat -i 1 < "$PIPE1" > /dev/null | sed 's/^/[I1] /'
) &

(
  pv -brat -i 1 < "$PIPE2" > /dev/null | sed 's/^/[I2] /'
) &

# -------- MAIN LOOP ----------
while true; do
  if ! has_net; then
    echo "[!] No internet. Waiting..."
    sleep "$CHECK_INTERVAL"
    continue
  fi

  echo "[+] Internet OK. Streaming..."

  yt-dlp -f bestvideo \
    --no-part --no-cache-dir \
    -o - "$URL" 2>/dev/null | tee "$PIPE1" >> "$PIPE_TOTAL" &

  yt-dlp -f bestvideo \
    --no-part --no-cache-dir \
    -o - "$URL" 2>/dev/null | tee "$PIPE2" >> "$PIPE_TOTAL" &

  wait
  echo "[!] Stream stopped. Retrying..."
  sleep 2
done
