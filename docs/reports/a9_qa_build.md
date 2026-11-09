# Laporan Agent A9 — QA, Build Scripts, Export Presets, Test Runner (Gelombang 1)

Tanggal: 2026-11-09

## File yang dibuat
- `export_presets.cfg` — dua preset:
  - **Android**: `com.minirush.game`, `Mini Rush`, `gradle_build/use_gradle_build=false`,
    `architectures/arm64-v8a=true` (lainnya false), `permissions/internet=true`,
    `export_path="build/MiniRush.apk"`, version 1 / 0.1.0, `screen/immersive_mode=true`.
  - **Linux Server**: `dedicated_server=true`, `binary_format/embed_pck=false`,
    `export_path="build/server/MiniRushServer.x86_64"`, runnable=false.
- `scripts/check_project.sh` — cek Godot 4.3, export templates, JDK, Android SDK
  (platform-34 + build-tools 34.0.0), keystore debug, jalankan `--import`, lalu
  cek sintaks semua `.gd` dengan `--check-only`. Exit non-zero bila ada kegagalan.
- `scripts/build_android.sh [debug|release]` — export lalu verifikasi bertahap:
  file ada, ukuran > 5 MB, `unzip -l` berisi `lib/arm64-v8a/`, `apksigner verify`
  (fallback `jarsigner -verify`). Set env `GODOT_ANDROID_KEYSTORE_DEBUG_*` dan
  `GODOT_ANDROID_SDK_PATH` otomatis.
- `scripts/build_server.sh` — export preset Linux Server, `chmod +x`, verifikasi `--version`.
- `scripts/run_server.sh [port]` — pakai binary hasil export bila ada, kalau tidak
  jalankan project dengan editor binary headless + `--server --port=<p>`, log ke `logs/`.
- `scripts/run_local_multiplayer.sh [2-4]` — server headless + N client penuh via
  `xvfb-run -a` dengan `--auto-test=<skenario>`, log ke `tests/reports/multiplayer/<ts>/`.
- `scripts/test_project.sh` — jalankan `run_tests.gd`, simpan log ke `tests/reports/`.
- `tests/run_tests.gd` — SceneTree runner persis template spec bagian 8
  (`_init` → `_run_all` → `print PASSED/FAILED` → `quit(1)` bila gagal), plus
  helper `skip()` untuk guard modul agent lain yang belum ada.
- `tests/unit/test_room_code.gd` — 200 iterasi generate: panjang 6, hanya alphabet
  `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`, tanpa I/O/0/1, `is_valid` menerima/menolak.
- `tests/unit/test_protocol.gd` — konstanta & enum kontrak Protocol.
- `tests/unit/test_map_data.gd` — konstanta MapData + sanity (checkpoint monotonik
  menuju finish, spawn/finish di dalam WORLD_BOUNDS).
- `tests/integration/test_multiplayer_flow.gd` — verifikasi ke-17 nama RPC kontrak
  ada di NetManager; guard skip bila NetManager/RoomManager belum ada.
- `docs/ANDROID_BUILD.md`, `docs/TESTING.md`, `docs/INSTALLATION.md`,
  `docs/DEVELOPMENT.md`, `docs/MULTIPLAYER.md`, `docs/DEPLOYMENT.md`, `docs/CREDITS.md`.

## Hasil verifikasi (bukti)
- `bash scripts/check_project.sh` → **LULUS**:
  Godot `4.3.stable.official.77dcf97d8`, templates OK, SDK OK, keystore OK,
  `--import` selesai, **41 file .gd lolos `--check-only`**.
- `bash scripts/test_project.sh` → **`PASSED: 840  FAILED: 0`**, exit code 0.
- Preset dikenali Godot 4.3:
  - Linux Server: `--export-release "Linux Server" ... --dry-run` → rc=0, pck packing penuh.
  - Android: preset ditemukan; export menolak **hanya** karena Java SDK path /
    Android SDK path belum di-set di Editor Settings (bukan "preset not found"
    dan bukan opsi tidak dikenali). Env `GODOT_ANDROID_KEYSTORE_DEBUG_*` diakui
    (error keystore hilang setelah env diset). Lengkap di bagian catatan di bawah.
- `build_android.sh` **tidak dijalankan penuh** (disk ketat, sesuai instruksi).

## Catatan lingkungan (penyimpangan dari spec)
1. **JDK 21, bukan 17.** Spec minta JDK 17; lingkungan hanya punya OpenJDK 21.0.12.
   Godot 4.3 Android export berjalan dengan JDK 17+, jadi JDK 21 dipakai dan
   `check_project.sh` mencatatnya sebagai info, bukan gagalan. Jika nanti perlu
   strict 17, install `openjdk-17-jdk` lalu `export JAVA_HOME=...java-17...`.
2. **Export Android butuh path di Editor Settings atau env tambahan.** Env keystore
   (`GODOT_ANDROID_KEYSTORE_DEBUG_PATH/USER/PASSWORD`) diakui Godot 4.3, tetapi
   Java SDK path dan Android SDK path tetap ditolak headless tanpa
   `editor_settings-4.3.tres`. Solusi di `build_android.sh`: sebelum export,
   script menulis `~/.config/godot/editor_settings-4.3.tres` berisi
   `export/android/java_sdk_path` dan `export/android/android_sdk_path` bila belum ada
   (lihat bagian bawah "langkah build_android"). Catatan: sebagian besar opsi preset
   seperti `permissions/internet=true` dikenali; tidak ada opsi yang ditolak Godot 4.3.
3. **Gradle build = false** sesuai spec (prebuilt APK template, tidak perlu gradle) —
   berarti `android_source.zip` + JDK/SDK tidak dipakai saat export; hanya keystore.

## Langkah build_android.sh (dilaporkan, belum dijalankan — disk ketat)
1. `bash scripts/check_project.sh` (harus LULUS)
2. `bash scripts/build_android.sh debug`
3. Verifikasi otomatis di script: ukuran > 5 MB, `lib/arm64-v8a/`, `apksigner verify`.
4. Output: `build/MiniRush-debug.apk`.

## Masalah terbuka
- **`--check-only` tidak memuat autoload.** File yang memakai identifier global autoload
  (mis. `GameConfig`, `NetManager`) bisa gagal compile saat `--check-only` dijalankan
  per-file, walau benar saat project dijalankan. Pengecualian di `check_project.sh`
  untuk path di bawah `scripts/autoload/` dan file yang hanya gagal karena
  identifier autoload tidak ditemukan.
- (A3) `scripts/input/virtual_joystick.gd` memunculkan parse error saat `--import`
  (baris 64, "Assignment is not allowed inside an expression") walau lolos
  `--check-only` — perlu dilihat A3.
- (A6/A7, aktif saat gelombang 1) Saat cek terakhir, 3 file milik agent lain sedang
  dalam penulisan: `scripts/networking/remote_player_view.gd` dan
  `scenes/lobby/lobby_ui.gd` di-WARN karena identifier `NetManager` belum resolve
  saat `--check-only` per-file (limitasi tool, bukan error nyata);
  `scripts/autoload/server_main.gd` (A7) sempat punya parse error nyata dan
  **ditangkap FAIL oleh check_project.sh** — saat laporan terakhir sudah bersih
  (cek ulang berikutnya hanya menampilkan WARN A6 di atas).
- Integration test penuh (multi-client, ROOM_FULL, disconnect/reconnect) menunggu
  modul A6/A7 selesai — guard skip sudah terpasang.
