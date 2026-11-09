#!/usr/bin/env bash
# build_server.sh — Agent A9
# Export preset "Linux Server", chmod +x, verifikasi dengan --version.
set -u

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/godot/Godot_v4.3-stable_linux.x86_64}"
OUT_DIR="$PROJECT_DIR/build/server"
OUT="$OUT_DIR/MiniRushServer.x86_64"

echo "=== Mini Rush — build_server ==="
mkdir -p "$OUT_DIR"

"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release "Linux Server" "$OUT"
RC=$?
if [ $RC -ne 0 ]; then
    echo "[FAIL] Export Linux Server gagal (rc=$RC)" >&2
    exit 1
fi

if [ ! -f "$OUT" ]; then
    echo "[FAIL] Binary server tidak ada: $OUT" >&2
    exit 1
fi
chmod +x "$OUT"
echo "[OK] Binary: $OUT ($(du -h "$OUT" | cut -f1))"

# Verifikasi jalankan --version (headless pck biasa masih mendukung --version)
if "$OUT" --version >/dev/null 2>&1; then
    echo "[OK] Binary server merespons --version: $("$OUT" --version 2>/dev/null | head -1)"
else
    echo "[FAIL] Binary server tidak bisa dijalankan" >&2
    exit 1
fi

echo "=== build_server: LULUS ==="
