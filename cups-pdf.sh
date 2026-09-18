#!/bin/sh
# Start the print server. Every document printed to it lands in ./out as a PDF.
# Overrides: OUT=/some/dir PORT=6631 ./cups-pdf.sh
set -eu
DIR=$(cd "$(dirname "$0")" && pwd)
IMAGE=${IMAGE:-cups-pdf}
NAME=${NAME:-cups-pdf}
# ponytail: 6631, not 631 -- macOS already runs its own cupsd on 631.
PORT=${PORT:-6631}
OUT=${OUT:-$DIR/out}

mkdir -p "$OUT"
docker image inspect "$IMAGE" >/dev/null 2>&1 || docker build -t "$IMAGE" "$DIR"
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" -p "$PORT:631" -v "$OUT:/output" \
  --restart unless-stopped "$IMAGE" >/dev/null

echo "add this printer:  ipp://localhost:$PORT/printers/Office_Printer"
echo "PDFs:              $OUT"
echo "admin UI:          http://localhost:$PORT   (stop: docker rm -f $NAME)"
