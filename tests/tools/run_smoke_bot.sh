#!/usr/bin/env bash
# tests/tools/run_smoke_bot.sh — Smoke test fitur BOT AI (server-side).
# Headless server + 1 client WS: create room -> add bot -> race sampai finish.
# Bukti log disimpan di tests/reports/multiplayer/<timestamp>/.
set -u

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/godot/Godot_v4.3-stable_linux.x86_64}"
PORT="${PORT:-27751}"
REPORT_DIR="$PROJECT_DIR/tests/reports/multiplayer/$(date +%Y%m%d_%H%M%S)_bot"
mkdir -p "$REPORT_DIR"

echo "=== Mini Rush — smoke test bot (port $PORT, log: $REPORT_DIR) ==="

"$GODOT_BIN" --headless --path "$PROJECT_DIR" -- --server --port="$PORT" --transport=ws \
    > "$REPORT_DIR/server.log" 2>&1 &
SERVER_PID=$!
sleep 2
if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "[FAIL] server gagal start" >&2
    cat "$REPORT_DIR/server.log" >&2
    exit 1
fi

xvfb-run -a "$GODOT_BIN" --path "$PROJECT_DIR" -- \
    --auto-test=add_bot --auto-test-index=1 --address=127.0.0.1 --port="$PORT" --transport=ws \
    > "$REPORT_DIR/client_1.log" 2>&1 &
CLIENT_PID=$!

TIMEOUT=100
ELAPSED=0
while kill -0 "$CLIENT_PID" 2>/dev/null && [ $ELAPSED -lt $TIMEOUT ]; do
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done
kill "$CLIENT_PID" "$SERVER_PID" 2>/dev/null
wait 2>/dev/null

echo "[INFO] Log tersimpan di $REPORT_DIR"
# Kriteria PASS menyamai baseline ws_transport (client penuh hingga AUTOTEST
# RESULTS adalah bug lintas-modul PRA-EKSISTING, lihat docs/TESTING.md):
# 1) bot muncul di snapshot daftar pemain di client
# 2) server mencatat bot ditambahkan
# 3) server mencatat checkpoint bot diterima (mekanisme sama seperti pemain)
# 4) server mencatat bot finish (masuk payload rpc_match_results)
FAIL=0
grep -q "BOT_IN_SNAPSHOT" "$REPORT_DIR/client_1.log" || { echo "[FAIL] bot tidak muncul di daftar pemain" >&2; FAIL=1; }
grep -q "bot ditambahkan" "$REPORT_DIR/server.log" || { echo "[FAIL] server tidak mencatat penambahan bot" >&2; FAIL=1; }
grep -qE "peer -[0-9]+ checkpoint [0-9]+ diterima" "$REPORT_DIR/server.log" || { echo "[FAIL] checkpoint bot tidak diterima" >&2; FAIL=1; }
grep -qE "peer -[0-9]+ finish dalam" "$REPORT_DIR/server.log" || { echo "[FAIL] bot tidak finish" >&2; FAIL=1; }
if [ $FAIL -eq 0 ]; then
    echo "=== smoke bot: LULUS ==="
    exit 0
else
    echo "=== smoke bot: GAGAL ===" >&2
    exit 1
fi
