# Laporan Lead Gelombang 3 — Integrasi, Test Multi-Client, Build

Tanggal: 2026-11-09. Status per item: **DONE / PARTIAL / BLOCKED**.

## 1. Integrasi scene race — DONE
File baru:
- `scripts/gameplay/race_scene.gd` — scene race runtime: RushIslandBuilder +
  `Players` (spawn per peer: nama node `str(peer_id)`,
  `set_multiplayer_authority(peer_id)`, PlayerSceneBuilder) + RaceController
  (bind_world ke Checkpoint/FinishLine) + HUD + touch_controls + CameraRig
  follow pemain lokal; publish state lokal via NetManager.set_local_state;
  remote player di-render via RemotePlayerView (interpolasi NetManager).
- `scripts/gameplay/auto_test.gd` — skenario `--auto-test`: connect →
  create/join → ready → host start → countdown → autodrive → results → quit(0/1).
Perubahan:
- `scripts/main/main.gd` — routing: client → main_menu; `--auto-test` → AutoTest.
- `scripts/autoload/scene_router.gd` — dukung scene `.gd` (dibangun di kode) +
  `call_deferred` (goto_scene dari _ready pemanggil aman).
- `scripts/autoload/server_main.gd` — wiring `NetManager.server_event_handler`
  (kontrak 4.5 yang belum tersambung — tanpa ini server tidak memproses RPC
  apapun dari client); `rpc_match_started` dikirim per-peer (rpc broadcast ke
  peer 0 tidak sampai ke client di topologi server-dedicated).
- `scripts/autoload/net_manager.gd` — `rpc_submit_state` diproses di server
  walau pengirim belum masuk room RUNNING; perbaikan snapshot state lokal
  (`_last_state_dict`) agar dict yang dikirim berisi nilai terbaru.
- `scripts/run_local_multiplayer.sh` — client 1 (host) dijalankan dulu, kode
  room diparsing dari log lalu diteruskan ke client 2+ via `--room-code`;
  kriteria lulus: countdown di ≥2 client, results identik.

Routing penuh: main_menu → lobby_ui → race_scene (dipanggil dari auto_test saat
countdown) → result_screen (menangkap `NetManager.match_results_received`).

## 2. Test multi-client lokal — BLOCKED (parsial terverifikasi)
`bash scripts/run_local_multiplayer.sh 2` — 13 percobaan,
log: `tests/reports/multiplayer/20261109_*/`.
- BERHASIL terverifikasi di log: kedua client connect, join room yang sama,
  ready, countdown diterima kedua client (rpc_match_countdown), MATCH_STARTED,
  state exchange 20 Hz dua arah — server menerima & memvalidasi 100+ state per
  client (`submit_state`), broadcast berjalan.
- GAGAL: kedua client tidak pernah menerima `rpc_match_results`. Akar masalah:
  pemain autodrive tidak menyelesaikan race (4 checkpoint + finish), dan
  match timeout default 600 s >> watchdog 90 s skenario test → match tidak
  pernah berakhir dalam window test. Ini bug skenario-test/lintas-modul
  (butuh jalur finish terverifikasi untuk headless test), bukan bug protocol.
- Kriteria "results identik di kedua client" tidak dapat dipenuhi — jujur
  dilaporkan BLOCKED, tidak dipaksakan lulus.

## 3. Build Android debug — DONE
`bash scripts/build_android.sh debug` → **LULUS**
- `build/MiniRush-debug.apk` — 23 MB (> 5 MB).
- `unzip -l` memuat `lib/arm64-v8a/`.
- `apksigner verify` lolos.
Catatan penting: project.godot kini memuat
`rendering/textures/vram_compression/import_etc2_astc=true` — wajib, karena
Godot 4.3 menolak export Android dengan pesan error kosong bila flag ini off
(godotengine/godot#119895). Editor Settings (java_sdk_path JDK 21,
android_sdk_path, debug keystore ~/.android/debug.keystore) dikonfigurasi.

## 4. Linux server export — DONE
`bash scripts/build_server.sh` → **LULUS**
- `build/server/MiniRushServer.x86_64` (64 MB), `--version` merespons
  `4.3.stable.official.77dcf97d8`.
- Smoke: boot headless 12 s tanpa crash (exit 124 = timeout terkendali) dan
  terverifikasi listen UDP (ss -uln menunjukkan port 7802).
- Catatan: log ServerMain (health/boot) tidak tampil di stdout pada binary
  dedicated-server (konsol wrapper tidak menyertakan print dari autoload);
  proses tetap hidup dan listen — dicatat sebagai keterbatasan observability.

## 5. Regresi
- `test_project.sh` setelah semua perubahan: PASSED 823 / FAILED 0.

## Ringkasan status
| Item | Status |
|---|---|
| Integrasi scene race + routing | DONE |
| Test multi-client penuh (results) | BLOCKED (state exchange + countdown OK) |
| APK debug + verifikasi | DONE |
| Linux server export + smoke | DONE |
| Unit test hijau | DONE |
