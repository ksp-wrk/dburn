#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

STREAMS=8
BYTES_PER_STREAM=1550000000000   # 250MB
UA="Mozilla/5.0"

echo "Starting $STREAMS streams x $BYTES_PER_STREAM bytes"

for i in $(seq 1 $STREAMS); do
  curl -L --http2 -A "$UA" \
    "https://speed.cloudflare.com/__down?bytes=$BYTES_PER_STREAM" \
    | pv -brat -i 1 > /dev/null &
done
wait

echo "Done."
