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

# 2. Client 1 dulu (host) — ambil kode room dari log, lalu client sisanya join.
ROOM_CODE=""
xvfb-run -a "$GODOT_BIN" --path "$PROJECT_DIR" -- \
    --auto-test="$SCENARIO" --auto-test-index=1 --address=127.0.0.1 --port="$PORT" \
    > "$REPORT_DIR/client_1.log" 2>&1 &
CLIENT_PIDS=($!)
echo "[INFO] Client 1 PID ${CLIENT_PIDS[-1]}"

# Tunggu kode room dari client 1 (maks 30 s).
for attempt in $(seq 1 30); do
    ROOM_CODE=$(grep -o "AUTOTEST. ROOM_CODE=[A-Z0-9]*" "$REPORT_DIR/client_1.log" 2>/dev/null | head -1 | sed 's/.*ROOM_CODE=//')
    [ -n "$ROOM_CODE" ] && break
    sleep 1
done
if [ -z "$ROOM_CODE" ]; then
    echo "[FAIL] Client 1 tidak menghasilkan kode room dalam 30 s — lihat $REPORT_DIR/client_1.log" >&2
    kill "${CLIENT_PIDS[-1]}" "$SERVER_PID" 2>/dev/null
    exit 1
fi
echo "[INFO] Room code: $ROOM_CODE"

for i in $(seq 2 "$N_CLIENTS"); do
    xvfb-run -a "$GODOT_BIN" --path "$PROJECT_DIR" -- \
        --auto-test="$SCENARIO" --auto-test-index="$i" --room-code="$ROOM_CODE" --address=127.0.0.1 --port="$PORT" \
        > "$REPORT_DIR/client_$i.log" 2>&1 &
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

# 4. Verifikasi: kedua client menerima results identik
RESULTS_COUNT=$(grep -l "AUTOTEST. RESULTS:" "$REPORT_DIR"/client_*.log 2>/dev/null | wc -l)
OK_COUNT=$(grep -l "AUTOTEST. client .* selesai OK" "$REPORT_DIR"/client_*.log 2>/dev/null | wc -l)
COUNTDOWN=$(grep -l "AUTOTEST. COUNTDOWN" "$REPORT_DIR"/client_*.log 2>/dev/null | wc -l)
echo "[INFO] Log tersimpan di $REPORT_DIR"
if [ "$OK_COUNT" -ge 2 ] && [ "$COUNTDOWN" -ge 2 ] && [ "$RESULTS_COUNT" -ge 2 ]; then
    # Identik: bandingkan hasil JSON client 1 dan 2
    R1=$(grep -o "RESULTS: .*" "$REPORT_DIR/client_1.log" | sort -u)
    R2=$(grep -o "RESULTS: .*" "$REPORT_DIR/client_2.log" | sort -u)
    if [ "$R1" == "$R2" ]; then
        echo "=== run_local_multiplayer: LULUS (kedua client selesai, results identik) ==="
        exit 0
    else
        echo "=== run_local_multiplayer: GAGAL (results berbeda) ===" >&2
        echo "C1: $R1" >&2
        echo "C2: $R2" >&2
        exit 1
    fi
else
    echo "=== run_local_multiplayer: GAGAL (ok=$OK_COUNT countdown=$COUNTDOWN results=$RESULTS_COUNT dari $N_CLIENTS client) ===" >&2
    exit 1
fi
