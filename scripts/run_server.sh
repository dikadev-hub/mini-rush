#!/usr/bin/env bash
# run_server.sh [port] — Agent A9
# Jalankan server headless dari project (mode dev, pakai editor binary) dengan log ke logs/.
set -u

PORT="${1:-7777}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/godot/Godot_v4.3-stable_linux.x86_64}"
# Jika binary server hasil export ada, pakai itu; kalau tidak, jalankan project dengan editor binary.
SERVER_BIN="$PROJECT_DIR/build/server/MiniRushServer.x86_64"
LOG_DIR="$PROJECT_DIR/logs"
mkdir -p "$LOG_DIR"
TS="$(date +%Y%m%d_%H%M%S)"
LOG="$LOG_DIR/server_$TS.log"

echo "=== Mini Rush — run_server (port $PORT, log: $LOG) ==="

if [ -x "$SERVER_BIN" ]; then
    exec "$SERVER_BIN" --headless -- --server --port="$PORT" 2>&1 | tee -a "$LOG"
else
    exec "$GODOT_BIN" --headless --path "$PROJECT_DIR" -- --server --port="$PORT" 2>&1 | tee -a "$LOG"
fi
