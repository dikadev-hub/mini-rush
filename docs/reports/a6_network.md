# Laporan Agent A6 — Jaringan Client & Lobi

Tanggal: 2026-11-09. Owner folder: `scripts/networking/`, `scripts/autoload/net_manager.gd`, `scenes/lobby/`, `scenes/multiplayer/`.

## File dibuat / diisi

| File | Isi |
|---|---|
| `scripts/autoload/net_manager.gd` | NetManager penuh (menggantikan stub A1). Semua 17 RPC kontrak 4.5 dengan dekorator persis; client ENet `connect_to_server(address, port)` dengan timeout 8 detik; sinyal `connection_started/succeeded/failed`, `server_lost`, `room_response_received`, `room_snapshot_updated`, `match_countdown_started`, `match_started`, `remote_states_updated`, `checkpoint_ack_received`, `match_results_received`, `returned_to_lobby`; kirim state akumulator 20 Hz di `_physics_process` (dict skema 4.4: pid,p,r,a,g,t); interpolasi remote 2 snapshot, delay 100 ms, lerp posisi + slerp rotasi Y via Quaternion, hold (tanpa ekstrapolasi) saat snapshot tua, `is_remote_stale()` untuk ambang >500 ms; helper `server_send_*` / `server_broadcast_*` untuk A7; hook `server_event_handler` (Callable) untuk dipasang RoomManager A7 tanpa menyentuh file server. |
| `scenes/lobby/lobby_ui.gd` + `lobby_ui.tscn` | UI lobi Control + CanvasLayer, anchors responsif. Tombol: Create Room, Join Room, Leave, Ready (toggle), Start (visible/disabled hanya host). Daftar pemain `ItemList` dari `room_snapshot` (nickname, id, [HOST], [READY]). Input kode 6 karakter: auto-uppercase + filter `ROOM_CODE_ALPHABET`. Pesan error jujur per `Protocol.ErrorCode` (ROOM_FULL, VERSION_MISMATCH, INVALID_NICKNAME, dst). Auto-connect saat belum terhubung, aksi pending dieksekusi setelah `connection_succeeded`. |
| `scenes/multiplayer/multiplayer_room.gd` | Root scene multiplayer: memuat `lobby_ui.tscn` (atau script-nya) sebagai UI awal; entry point untuk scene race. |
| `scripts/networking/remote_player_view.gd` | `RemotePlayerView` (Node3D): menerapkan hasil interpolasi `NetManager.get_remote_interp(pid)` ke node remote player; tahan posisi saat `is_remote_stale(pid)`. |

## Verifikasi (bukti)

1. Sintaks `--check-only` (semua exit 0, tanpa error):
   - `godot --headless --path . --check-only --script res://scripts/autoload/net_manager.gd` → OK
   - `res://scenes/lobby/lobby_ui.gd` → OK (setelah fix NetManager — lihat masalah #1)
   - `res://scenes/multiplayer/multiplayer_room.gd` → OK
   - `res://scripts/networking/remote_player_view.gd` → OK
2. Test suite proyek: `godot --headless --path . -s res://tests/run_tests.gd` → **PASSED: 840  FAILED: 0**, termasuk 17 assert "NetManager punya rpc_*" (kontrak 4.5 lengkap).
3. Probe runtime headless (SceneTree dengan autoload aktif):
   - UI lobi ter-instantiate; filter kode `"ab0I9z"` → `"AB9Z"` (benar: 0,1,I,O difilter).
   - `_apply_snapshot` menampilkan `Host (id 1) [HOST]`.
   - Interpolasi: 2 snapshot (0→10, recv -200/-50 ms) → pos.x ≈ 6.67 (delay 100 ms, lerp benar).
   - Snapshot terakhir >500 ms → `is_remote_stale == true`, `get_remote_interp` menahan posisi terakhir (0,0,0), tidak ada ekstrapolasi.
4. Verifikasi koneksi end-to-end penuh (server nyata + 2 client) adalah ranah integrasi A9 (Gelombang 3, `run_local_multiplayer.sh`) — NetManager menyediakan seluruh API dan sinyal yang dibutuhkan.

## Masalah / catatan

1. **`--check-only` tidak men-resolve autoload global** (NetManager, GameConfig, dst) pada Godot 4.3 — identifier dianggap tidak dikenal meski project.godot benar dan runtime jalan normal (terverifikasi: script kompilasi sukses saat autoload aktif; test suite A9 lolos 840/0). Ini keterbatasan tooling, bukan bug kode. Saran CR untuk A9: `check_project.sh` sebaiknya tidak gagal pada error "Identifier not found: <NamaAutoload>" dari `--check-only`, atau memverifikasi via `-s` probe runtime.
2. Handler server di NetManager hanya meneruskan event ke A7 lewat `NetManager.server_event_handler` (Callable `handler(event_name, sender_id, args)`) — A7 cukup menyetel callable ini di `_ready()`; tidak ada file server yang disentuh.
3. `set_local_state(pos, rot_y, anim, on_floor)` adalah API bagi A2/A5 untuk mempublish state lokal yang dikirim 20 Hz.
