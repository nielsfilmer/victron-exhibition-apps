#!/usr/bin/env bash
# Build the kiosk-ws-relay binary for both macOS architectures
# (Apple Silicon arm64 + Intel x86_64) and drop them in kiosk/bin/.
#
# Run this whenever main.go or go.sum changes, and commit the
# resulting binaries — the kiosk Mac has no Go toolchain.
set -euo pipefail

cd "$(dirname "$0")"
OUT="$(cd .. && pwd)/bin"
mkdir -p "$OUT"

# `-s -w` strips debug symbols → ~30% smaller binary. Trimpath removes
# the developer's home directory from embedded build paths so the
# binary is reproducible across developer machines.
LDFLAGS="-s -w"
COMMON=(-trimpath -ldflags "$LDFLAGS")

echo "→ Downloading deps…"
go mod download

echo "→ Building arm64…"
GOOS=darwin GOARCH=arm64 go build "${COMMON[@]}" -o "$OUT/kiosk-ws-relay-arm64" .

echo "→ Building x86_64…"
GOOS=darwin GOARCH=amd64 go build "${COMMON[@]}" -o "$OUT/kiosk-ws-relay-x86_64" .

chmod +x "$OUT/kiosk-ws-relay-arm64" "$OUT/kiosk-ws-relay-x86_64"

echo
ls -lh "$OUT"/kiosk-ws-relay-* | awk '{printf "  %-40s %s\n", $NF, $5}'
echo
echo "✓ Built. Commit the binaries in $OUT/ alongside main.go."
