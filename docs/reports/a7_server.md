# Laporan A7 — Server Dedicated (Gelombang 1)

Tanggal: 2026-11-09. Engine: Godot 4.3.stable.official.77dcf97d8.

## File dibuat / diisi

| File | Isi |
|---|---|
| `scripts/utilities/log.gd` | Logger `Log.debug/info/warn/error`: stdout + `user://logs/server.log`, format `[timestamp] [level] pesan`, rotasi 5 MB |
| `scripts/server/player_entry.gd` | `PlayerEntry`: peer_id, nickname, character_id, is_ready, status, next_checkpoint, last_pos, last_state_ms (+`has_state`), finish_time_ms, join_order, player_token, pelanggaran kecepatan |
| `scripts/server/room.gd` | `Room`: code, state, host_peer, players, created_at_ms, empty_since_ms, race/countdown start ms, snapshot dict |
| `scripts/server/validator.gd` | Semua validasi: nickname 2–16 [a-zA-Z0-9 -], protocol_version, ROOM_FULL, bounds, kecepatan (>21 m/s ditolak, 20 pelanggaran/5 dtk → kick), checkpoint (index == next_checkpoint, jarak ≤ radius+teleport), finish (semua checkpoint + dekat FINISH) |
| `scripts/server/room_manager.gd` | `rooms`/`peer_to_room`, create/join/leave, host migration (pemain tertua), disconnect saat RUNNING → DISCONNECTED + reconnect 30 dtk token sama ke slot sama, TTL room kosong, kick |
| `scripts/server/match_manager.gd` | Start hanya host & semua ready, countdown→race, validasi state, checkpoint ack, finish + winner, ranking urut (DNF di akhir), timeout match |
| `scripts/autoload/server_main.gd` | Entry point penuh: parse `--port= --max-rooms= --max-players= --log-level= --match-timeout=`, ENet server (max_clients = max_rooms*max_players cap 400), loop broadcast 20 Hz, health log tiap 10 dtk, graceful shutdown (`auto_accept_quit=false`, SIGTERM via `NOTIFICATION_WM_CLOSE_REQUEST`) |
| `server/Dockerfile` | debian:bookworm-slim, entrypoint binary + `--headless -- --server` (persis bagian 9) |
| `server/docker-compose.yml` | Sesuai bagian 9 + `command` meneruskan env sebagai CLI argumen |
| `server/.env.example` | 5 variabel sesuai bagian 9 |
| `tests/unit/test_server_logic.gd` | 21 assertion smoke test logika server |

## Verifikasi

1. **Sintaks** (`--check-only --script`) — semua 8 file exit=0.
2. **Boot server headless**: `godot --headless --path . -- --server --port=7799 --max-rooms=3 --log-level=debug` → exit=0, log: "server ENet aktif di UDP 7799 (max_clients=24)", "ServerMain siap", log file `user://logs/server.log` terisi.
3. **Unit test**: `godot --headless --path . -s res://tests/unit/test_server_logic.gd` → `PASSED: 21 FAILED: 0` (nickname, versi, ROOM_FULL, host migration, pid mismatch, speed hack ditolak, 20 pelanggaran→kick, out of bounds, checkpoint lompat/urut, finish ditolak/valid, ranking, DNF).
4. NetManager stub: deteksi `has_method(rpc_name)` — tidak crash saat A6 belum ada.

## Masalah terbuka / catatan untuk agent lain

1. **CR untuk A6 (NetManager):** server mendelegasikan pengiriman RPC via `ServerMain._net_call_to(peer_id, nama_rpc, args)`. NetManager wajib mendeklarasikan 17 RPC kontrak 4.5 di `net_manager.gd` dan mendelegasikan RPC client→server ke `ServerMain.handle_*` (method publik sudah tersedia: `handle_request_create_room`, `handle_request_join_room`, `handle_request_leave_room`, `handle_set_ready`, `handle_request_start_match`, `handle_submit_state`, `handle_report_checkpoint`, `handle_report_finish`, `handle_server_health`). Tanpa itu, RPC gagal diam-diam (server tetap jalan, tidak crash).
2. **CR untuk A1 (`game_config.gd`):** CLI `--max-rooms=`, `--max-players=`, `--log-level=`, `--match-timeout=` hanya diparse di `ServerMain` (kontrak 5.6 milik A7). GameConfig sudah cukup untuk `--port=`/`--address=`.
3. **Isu engine (terdokumentasi):** `Time.get_ticks_msec()` bernilai negatif di awal proses; `PlayerEntry.has_state` dipakai alih-alih cek `last_state_ms > 0`. Juga `--check-only` tidak memuat autoload → `server_main.gd` memakai `preload(game_config.gd)` untuk konstanta dan `get_node("/root/GameConfig")` untuk instance.
4. **Keterbatasan MVP (jujur, sesuai bagian 12):** validasi posisi berbasis delta kecepatan yang dikirim client, bukan simulasi server penuh; state broadcast menyertakan `r`/`a`/`g` minimal (rotasi/animasi diperkaya setelah A6/A5 mendefinisikan payload penuh). Reconnect butuh client mengirim token via join/rejoin path (API `try_reconnect` tersedia; wiring RPC reconnect bergantung A6).
5. Docker image belum di-build (butuh `scripts/build_server.sh` hasil export A9); verifikasi container ditunda ke Gelombang 3.
