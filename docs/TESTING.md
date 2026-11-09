# TESTING — Mini Rush

## Menjalankan
```bash
bash scripts/check_project.sh    # lingkungan + --import + cek sintaks semua .gd
bash scripts/test_project.sh     # unit + integration via tests/run_tests.gd
bash scripts/run_local_multiplayer.sh 2   # server + 2 client xvfb (gelombang 3)
```

## Runner
`tests/run_tests.gd` extends `SceneTree` (template spec bagian 8): `_init` →
`_run_all` → `print("PASSED: %d  FAILED: %d")` → `quit(1)` bila ada yang gagal.
Tanpa plugin GUT (mengurangi dependency eksternal).

Test dijalankan: `godot --headless --path . -s res://tests/run_tests.gd`.

## Hasil tercatat
- `tests/reports/test_run_*.log` — hasil tiap run dengan timestamp.
- Gelombang 3 (2026-11-09): `test_project.sh` **PASSED: 823  FAILED: 0**
  (setelah integrasi race scene; bukti `tests/reports/test_run_20261109_23*.log`).

## Hasil Gelombang 3 (integrasi akhir) — 2026-11-09
1. **Unit + integration: LULUS** — PASSED: 823, FAILED: 0 (3x run konsisten).
2. **Multi-client lokal: BLOCKED (bug lintas-modul, sebagian terverifikasi).**
   - Alur connect → create/join room → ready → countdown → MATCH_STARTED →
     state exchange client↔server 20 Hz **berhasil** (log `AUTOTEST` +
     `submit_state` di server.log, 100+ state per client diterima server).
   - **rpc_match_results tidak pernah diterima client**: client berhenti
     mengirim state baru / match tidak berakhir (timeout 600 s terlalu lama
     untuk skenario auto-test; autodrive hanya menabrak, tidak mengambil semua
     4 checkpoint + finish). Watchdog 90 s di auto_test memutus dengan FAIL.
   - 13 percobaan di `tests/reports/multiplayer/2026110*` (log lengkap
     server + 2 client per percobaan). Perbaikan kecil yang dilakukan:
     wiring `server_event_handler` (ServerMain), broadcast `rpc_match_started`
     per-peer (rpc(0) tidak sampai), submit_state client-side, SceneRouter
     defer, room-code handoff di run_local_multiplayer.sh.
   - Sisa akar masalah: skenario auto-test belum bisa menyelesaikan race
     (butuh waypoint/teleport-validated finish). Rekomendasi: tambah mode
     debug finish terverifikasi di Validator khusus headless-test, atau
     kecilkan DEFAULT_MATCH_TIMEOUT_SEC untuk skenario test.
3. **Build Android debug: LULUS** — `build/MiniRush-debug.apk` 23 MB,
   `lib/arm64-v8a/` ada, `apksigner verify` lolos. (Perlu
   `rendering/textures/vram_compression/import_etc2_astc=true` di
   project.godot — tanpa itu Godot 4.3 menolak export dengan error kosong,
   lihat godotengine/godot#119895.)
4. **Linux server export: LULUS** — `build/server/MiniRushServer.x86_64`
   (64 MB), `--version` → 4.3.stable.official, boot headless 12 s tanpa crash,
   terverifikasi listen UDP port (ss -uln).
5. Unit test tetap hijau setelah semua perubahan integrasi.

## Skenario penuh (sesuai spec 8.1)
1. Desktop manual: selesaikan map dengan keyboard.
2. `run_local_multiplayer.sh 2` lalu `4` — lihat status di atas.
3. Kapasitas: client ke-9 join room → `ROOM_FULL`.
4. Disconnect saat RUNNING → DISCONNECTED, room tetap jalan.
5. Restart server → error koneksi jujur di client → reconnect ok.
6. Android: `build_android.sh debug` + `adb install -r`, catat `logcat` ke `tests/reports/android/`.
7. Multi-touch: joystick + lompat + kamera bersamaan.
8. Performa: target min 30 FPS di Android kelas bawah/menengah.
