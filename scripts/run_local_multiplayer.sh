#!/usr/bin/env bash
# run_local_multiplayer.sh [jumlah_client 2-4] — Agent A9
# Jalankan server headless + N client penuh via xvfb-run dengan --auto-test=<skenario>.
# Log semua proses ke tests/reports/multiplayer/<timestamp>/.
set -u

N_CLIENTS="${1:-2}"
case "$N_CLIENTS" in
    2|3|4) ;;
    *) echo "Usage: $0 [2|3|4]" >&2; exit 2;;
esac

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/godot/Godot_v4.3-stable_linux.x86_64}"
SCENARIO="${SCENARIO:-join_room}"
PORT="${PORT:-7777}"
REPORT_DIR="$PROJECT_DIR/tests/reports/multiplayer/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$REPORT_DIR"

echo "=== Mini Rush — run_local_multiplayer ($N_CLIENTS client, skenario $SCENARIO, port $PORT) ==="
echo "Log dir: $REPORT_DIR"

# 1. Server headless
"$GODOT_BIN" --headless --path "$PROJECT_DIR" -- --server --port="$PORT" \
    > "$REPORT_DIR/server.log" 2>&1 &
SERVER_PID=$!
echo "[INFO] Server PID $SERVER_PID"
sleep 2

if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "[FAIL] Server gagal start — lihat $REPORT_DIR/server.log" >&2
    cat "$REPORT_DIR/server.log" >&2
    exit 1
fi

# 2. Client via xvfb (client Godot penuh, input nyata via --auto-test)
declare -a CLIENT_PIDS=()
for i in $(seq 1 "$N_CLIENTS"); do
    if command -v xvfb-run >/dev/null 2>&1; then
        xvfb-run -a "$GODOT_BIN" --path "$PROJECT_DIR" -- \
            --auto-test="$SCENARIO" --auto-test-index="$i" --address=127.0.0.1 --port="$PORT" \
            > "$REPORT_DIR/client_$i.log" 2>&1 &
    else
        "$GODOT_BIN" --path "$PROJECT_DIR" -- \
            --auto-test="$SCENARIO" --auto-test-index="$i" --address=127.0.0.1 --port="$PORT" \
            > "$REPORT_DIR/client_$i.log" 2>&1 &
    fi
    CLIENT_PIDS+=($!)
    echo "[INFO] Client $i PID ${CLIENT_PIDS[-1]}"
done

# 3. Tunggu client selesai (timeout 120 s)
TIMEOUT=120
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    RUNNING=0
    for pid in "${CLIENT_PIDS[@]}"; do kill -0 "$pid" 2>/dev/null && RUNNING=$((RUNNING+1)); done
    [ $RUNNING -eq 0 ] && break
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

for pid in "${CLIENT_PIDS[@]}"; do kill "$pid" 2>/dev/null; done
kill "$SERVER_PID" 2>/dev/null
wait 2>/dev/null

echo "[INFO] Log tersimpan di $REPORT_DIR"
echo "=== run_local_multiplayer selesai (integrasi penuh menunggu modul A6/A7 — gelombang 3) ==="
