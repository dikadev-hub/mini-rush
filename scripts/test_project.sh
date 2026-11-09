#!/usr/bin/env bash
# test_project.sh — Agent A9
# Jalankan unit + integration test via SceneTree runner (tests/run_tests.gd).
set -u

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/godot/Godot_v4.3-stable_linux.x86_64}"
REPORT_DIR="$PROJECT_DIR/tests/reports"
mkdir -p "$REPORT_DIR"
TS="$(date +%Y%m%d_%H%M%S)"

echo "=== Mini Rush — test_project ==="
"$GODOT_BIN" --headless --path "$PROJECT_DIR" -s res://tests/run_tests.gd 2>&1 | tee "$REPORT_DIR/test_run_$TS.log"
RC=${PIPESTATUS[0]}
echo "=== test_project exit code: $RC ==="
exit $RC
