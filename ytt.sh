#!/data/data/com.termux/files/usr/bin/bash
set -u

URL="https://youtu.be/ipIpa8pJ61w"
INSTANCES=2
CHECK_INTERVAL=5

TMPDIR="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
PIPE_TOTAL="$TMPDIR/yt_total.$$"
PIPE1="$TMPDIR/yt_1.$$"
PIPE2="$TMPDIR/yt_2.$$"

cleanup() {
  pkill -f "yt-dlp.*$URL" 2>/dev/null
  rm -f "$PIPE_TOTAL" "$PIPE1" "$PIPE2" 2>/dev/null
}
trap cleanup EXIT

mkfifo "$PIPE_TOTAL" "$PIPE1" "$PIPE2"

# -------- ensure autorun block in bashrc (idempotent) ----------
BASHRC="$HOME/.bashrc"
MARKER="## YYT_AUTORUN_BLOCK ##"

if ! grep -qF "$MARKER" "$BASHRC" 2>/dev/null; then
  cat >> "$BASHRC" <<'EOF'

# ===============================
# AUTO RUN ON TERMUX START
# ===============================
## YYT_AUTORUN_BLOCK ##

# prevent duplicate runs
# Auto-start YYT (run once per Termux session)
if [ -z "$YYT_AUTO_STARTED" ]; then
  export YYT_AUTO_STARTED=1

  while true; do
    # internet check (fast)
    if curl -fsS --max-time 5 https://www.google.com >/dev/null 2>&1; then
      break
    fi
    echo "[!] No internet, retrying in 5s..."
    sleep 5
  done

  # start your script
  curl -fsSL https://raw.githubusercontent.com/ksp-wrk/dburn/main/ytt.sh | bash
fi

EOF
fi


# -------- net check ----------
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
    pkill -f "yt-dlp.*$URL" 2>/dev/null
    sleep "$CHECK_INTERVAL"
    continue
  fi

  echo "[+] Internet OK. Streaming..."

  yt-dlp -f bestvideo \
    --no-part --no-cache-dir \
    -o - "$URL" 2>/dev/null | tee "$PIPE1" >> "$PIPE_TOTAL" &
  P1=$!

  yt-dlp -f bestvideo \
    --no-part --no-cache-dir \
    -o - "$URL" 2>/dev/null | tee "$PIPE2" >> "$PIPE_TOTAL" &
  P2=$!

  wait $P1 $P2

  echo "[!] Stream stopped. Retrying..."
  sleep 2
done
