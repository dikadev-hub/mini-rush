#!/usr/bin/env bash
# check_project.sh — Agent A9 (QA & Build)
# Memeriksa lingkungan (Godot, export templates, JDK, Android SDK, keystore),
# lalu menjalankan --import dan cek sintaks semua file .gd.
set -u

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/godot/Godot_v4.3-stable_linux.x86_64}"
FAILURES=0

ok()   { echo "  [OK]   $*"; }
bad()  { echo "  [FAIL] $*"; FAILURES=$((FAILURES + 1)); }
info() { echo "  [INFO] $*"; }

echo "=== Mini Rush — check_project ==="
echo "Project dir: $PROJECT_DIR"

# 1. Godot binary
if [ -x "$GODOT_BIN" ]; then
    GODOT_VERSION="$("$GODOT_BIN" --version 2>/dev/null)"
    info "Godot: $GODOT_VERSION ($GODOT_BIN)"
    if [[ "$GODOT_VERSION" == 4.3* ]]; then ok "Godot versi 4.3.stable"; else bad "Godot bukan 4.3 (got: $GODOT_VERSION)"; fi
else
    bad "Godot binary tidak ditemukan di $GODOT_BIN"
fi

# 2. Export templates
TPL_DIR="$HOME/.local/share/godot/export_templates/4.3.stable"
if [ -d "$TPL_DIR" ] && [ -f "$TPL_DIR/android_debug.apk" ] && [ -f "$TPL_DIR/linux_debug.x86_64" ]; then
    ok "Export templates 4.3.stable terpasang (android + linux)"
else
    bad "Export templates 4.3.stable tidak lengkap di $TPL_DIR"
fi

# 3. JDK
if command -v java >/dev/null 2>&1; then
    JAVA_VER="$(java -version 2>&1 | head -1)"
    info "Java: $JAVA_VER"
    if [[ "$JAVA_VER" == *"17"* ]]; then ok "JDK 17 (sesuai spec)"; else info "JDK bukan 17 — lihat catatan di docs/ANDROID_BUILD.md"; fi
else
    bad "Java tidak ditemukan (perlu JDK untuk build Android)"
fi

# 4. Android SDK
ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
if [ -d "$ANDROID_HOME/platforms/android-34" ] && [ -d "$ANDROID_HOME/build-tools/34.0.0" ]; then
    ok "Android SDK platform-34 + build-tools 34.0.0 terpasang"
else
    bad "Android SDK tidak lengkap di $ANDROID_HOME (butuh platform-34, build-tools 34.0.0)"
fi

# 5. Keystore debug
KS="${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-$HOME/.android/debug.keystore}"
if [ -f "$KS" ]; then
    ok "Keystore debug ada: $KS"
else
    bad "Keystore debug tidak ada di $KS"
fi

# 6. Import project resources
echo "--- godot --import ---"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --import 2>&1 | tail -5
IMPORT_RC=$?
if [ $IMPORT_RC -eq 0 ]; then ok "--import selesai"; else bad "--import gagal (rc=$IMPORT_RC)"; fi

# 7. Cek sintaks semua .gd
echo "--- cek sintaks semua .gd ---"
SYNTAX_FAIL=0
KNOWN_AUTOLOADS="GameConfig|SceneRouter|SettingsManager|ProfileManager|AudioManager|NetManager|ServerMain"
cd "$PROJECT_DIR"
GD_COUNT=$(find "$PROJECT_DIR" -name '*.gd' -not -path '*/.godot/*' | wc -l)
while IFS= read -r f; do
    ERR_OUT="$("$GODOT_BIN" --headless --path "$PROJECT_DIR" --check-only --script "res://${f#./}" 2>&1)"
    if [ -n "$(echo "$ERR_OUT" | grep -iE 'error|Parse Error')" ]; then
        # Pengecualian: --check-only per-file tidak memuat autoload, sehingga identifier
        # global (GameConfig, NetManager, dll.) dilaporkan "not found" walau benar saat run.
        AUTOLOAD_ONLY=1
        while IFS= read -r line; do
            if echo "$line" | grep -qE "Identifier not found: ($KNOWN_AUTOLOADS)\b"; then continue; fi
            if echo "$line" | grep -qE "Failed to load script|Compilation failed"; then
                continue  # baris sekunder,abaikan
            fi
            AUTOLOAD_ONLY=0  # ada error nyata di samping identifier autoload
        done <<< "$(echo "$ERR_OUT" | grep -iE 'error')"
        if [ $AUTOLOAD_ONLY -eq 1 ]; then
            echo "  [WARN] $f hanya gagal karena identifier autoload (--check-only limitation)"
        else
            echo "  [FAIL] $f"
            echo "$ERR_OUT" | grep -iE 'error' | grep -vE "Identifier not found: ($KNOWN_AUTOLOADS)\b|Failed to load script|Compilation failed" | head -3
            SYNTAX_FAIL=$((SYNTAX_FAIL + 1))
        fi
    fi
done < <(find "$PROJECT_DIR" -name '*.gd' -not -path '*/.godot/*' | sed "s|$PROJECT_DIR/||")
if [ $SYNTAX_FAIL -eq 0 ]; then ok "Semua $GD_COUNT file .gd lolos cek sintaks"; else bad "$SYNTAX_FAIL file .gd gagal cek sintaks"; fi

echo "=== Hasil: $([ $FAILURES -eq 0 ] && echo 'LULUS' || echo 'GAGAL') ==="
exit $((FAILURES + SYNTAX_FAIL > 0 ? 1 : 0))
