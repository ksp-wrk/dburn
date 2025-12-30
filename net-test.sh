#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

(
  for i in 1 2 3; do
    curl -sSL --http2 -A "Mozilla/5.0" \
    "https://speed.cloudflare.com/__down?bytes=1111000400000000" 2>/dev/null &
  done
  wait
) | pv -brat -i 1 > /dev/null


echo "Done."
