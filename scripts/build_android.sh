#!/usr/bin/env bash
# build_android.sh [debug|release] — Agent A9
# Export APK Android lalu verifikasi: ukuran > 5 MB, lib/arm64-v8a/, tanda tangan valid.
# CATATAN: JANGAN dijalankan penuh di lingkungan disk ketat; verifikasi preset
# dengan `--export-* --dry-run` bila tersedia (lihat docs/reports/a9_qa_build.md).
set -u

MODE="${1:-debug}"
case "$MODE" in
    debug|release) ;;
    *) echo "Usage: $0 [debug|release]" >&2; exit 2;;
esac

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/godot/Godot_v4.3-stable_linux.x86_64}"
BUILD_DIR="$PROJECT_DIR/build"
OUT="$BUILD_DIR/MiniRush-$MODE.apk"
FLAG="--export-$MODE"

# Lingkungan keystore (Godot 4.3 membaca env ini untuk export Android tanpa editor)
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-$HOME/.android/debug.keystore}"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="${GODOT_ANDROID_KEYSTORE_DEBUG_USER:-androiddebugkey}"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="${GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD:-android}"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-$GODOT_ANDROID_KEYSTORE_DEBUG_PATH}"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="${GODOT_ANDROID_KEYSTORE_RELEASE_USER:-androiddebugkey}"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:-android}"
export GODOT_ANDROID_SDK_PATH="${ANDROID_HOME:-$HOME/android-sdk}"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk-amd64}"

# Godot 4.3 headless export Android butuh java_sdk_path & android_sdk_path di
# Editor Settings (env GODOT_ANDROID_* hanya menutup keystore). Tulis bila belum ada.
ES_DIR="${HOME}/.config/godot"
ES_FILE="$ES_DIR/editor_settings-4.3.tres"
if [ ! -f "$ES_FILE" ]; then
    mkdir -p "$ES_DIR"
    cat > "$ES_FILE" <<EOF
[application]
config/version="4.3"
[editor]
export/android/java_sdk_path="$JAVA_HOME"
export/android/android_sdk_path="$GODOT_ANDROID_SDK_PATH"
EOF
    echo "[INFO] Editor Settings ditulis: $ES_FILE"
fi

echo "=== Mini Rush — build_android ($MODE) ==="
mkdir -p "$BUILD_DIR"

"$GODOT_BIN" --headless --path "$PROJECT_DIR" "$FLAG" "Android" "$OUT"
RC=$?
if [ $RC -ne 0 ]; then
    echo "[FAIL] Export Android $MODE gagal (rc=$RC)" >&2
    exit 1
fi

# Verifikasi 1: file ada dan ukuran > 5 MB
if [ ! -f "$OUT" ]; then
    echo "[FAIL] APK tidak ada: $OUT" >&2
    exit 1
fi
SIZE_MB=$(( $(stat -c%s "$OUT") / 1024 / 1024 ))
echo "[OK] APK: $OUT (${SIZE_MB} MB)"
if [ $SIZE_MB -le 5 ]; then
    echo "[FAIL] Ukuran APK <= 5 MB (${SIZE_MB} MB)" >&2
    exit 1
fi

# Verifikasi 2: berisi lib/arm64-v8a/
if ! unzip -l "$OUT" | grep -q "lib/arm64-v8a/"; then
    echo "[FAIL] APK tidak berisi lib/arm64-v8a/" >&2
    exit 1
fi
echo "[OK] APK berisi lib/arm64-v8a/"

# Verifikasi 3: tanda tangan
KS="$GODOT_ANDROID_KEYSTORE_DEBUG_PATH"
BT="$GODOT_ANDROID_SDK_PATH/build-tools/34.0.0"
if [ -x "$BT/apksigner" ]; then
    if "$BT/apksigner" verify "$OUT" >/dev/null 2>&1; then
        echo "[OK] apksigner verify lolos"
    else
        echo "[FAIL] apksigner verify gagal" >&2
        exit 1
    fi
else
    if jarsigner -verify -keystore "$KS" -storepass android "$OUT" >/dev/null 2>&1; then
        echo "[OK] jarsigner verify lolos"
    else
        echo "[FAIL] jarsigner verify gagal" >&2
        exit 1
    fi
fi

echo "=== build_android $MODE: LULUS ==="
