# Laporan Fitur: BOT AI Pemain (server-side)

Tanggal: 2026-11-10. Tujuan: 1 orang bisa main sendirian di room dan tetap
balapan sampai finish melawan bot.

## Desain
- Bot adalah **entity server-side** (pseudo-peer) — TIDAK butuh koneksi
  jaringan sungguhan. peer_id bot **negatif** (-1, -2, ...) agar tidak
  tabrakan dengan peer asli. Nama berurutan: `Bot 1`, `Bot 2`, ...
- Bot bergerak mengikuti path checkpoint Rush Island (`MapData`
  CHECKPOINT_POSITIONS -> FINISH_POSITION) dengan kecepatan acak
  5.5-8.5 m/s per bot (variasi agar tidak robotik), di bawah batas
  anti-cheat (`MAX_SPEED * MAX_POSITION_DELTA_FACTOR`).
- Checkpoint & finish diklaim lewat **mekanisme server yang sama** seperti
  pemain (`MatchManager.process_checkpoint` / `process_finish`), sehingga
  hasil bot otomatis masuk `rpc_match_results` (rank, waktu, status).
- Bot dihapus otomatis saat room dihapus (`expire_empty_rooms` — room kosong
  TTL; bot bukan pemilik slot jaringan). Bot tidak bisa menjadi host
  (`oldest_active_peer` melewati bot).

## RPC baru (kontrak eksisting TIDAK diubah)
| RPC | Arah | Skema |
|---|---|---|
| `request_add_bot()` -> `rpc_request_add_bot` | client (host) -> server | `@rpc("any_peer", "reliable")`, tanpa argumen. Server validasi: pengirim = host, room state LOBBY, room tidak penuh. Respons: broadcast `rpc_room_snapshot` (eksisting). |
| `PlayerEntry.to_dict()` | server -> client | field baru `"is_bot": bool` (aditif; field lama tidak berubah). |

## File yang berubah
| File | Perubahan |
|---|---|
| `scripts/server/bot_manager.gd` | **BARU**. `BotManager`: `add_bot(room)`, `update_bots(room, delta, now)` (jalan saat RUNNING, berhenti setelah finish). |
| `scripts/server/player_entry.gd` | var `is_bot`, `bot_speed_mps`; `to_dict()` + `is_bot`. |
| `scripts/server/room.gd` | var `next_bot_peer_id` (negatif); `oldest_active_peer()` melewati bot. |
| `scripts/autoload/net_manager.gd` | helper client `request_add_bot()`, RPC `rpc_request_add_bot`, delegasi server `_server_handle_add_bot`. |
| `scripts/autoload/server_main.gd` | `bot_manager` (BotManager), event `add_bot`, handler `handle_request_add_bot` (host + LOBBY + kapasitas), `update_bots` per frame saat RUNNING, skip RPC ke bot di `rpc_match_started`, bot kembali `is_ready` saat return-to-lobby. |
| `scenes/lobby/lobby_ui.gd` | tombol **"Tambah Bot (Host)"** (hanya tampil untuk host, disabled saat di luar room); daftar pemain menandai `[BOT]`. |
| `scripts/gameplay/auto_test.gd` | skenario `--auto-test=add_bot`: host add bot, verifikasi bot di snapshot (`BOT_IN_SNAPSHOT`) & di results (`BOT_FINISHED`). |
| `tests/unit/test_bot.gd` | **BARU**. 24 assertion unit test. |
| `tests/run_tests.gd` | daftarkan `test_bot.gd`. |
| `tests/tools/run_smoke_bot.sh` | **BARU**. Smoke test end-to-end. |

## Test unit (tests/unit/test_bot.gd)
- add bot: entri masuk room, nama `Bot 1`, peer_id negatif, otomatis ready,
  `is_bot=true` di snapshot.
- 3 bot: nama berurutan tanpa duplikat; kapasitas 8 dihormati.
- bot tidak dipilih sebagai kandidat host.
- progress: bot mengklaim semua checkpoint via mekanisme server, mencapai
  finish, status FINISHED, `finish_time_ms > 0`, `should_finish` true.
- results: bot ada di payload `rpc_match_results` (rank valid, waktu, FINISHED).
- reset: `begin_race` me-reset bot untuk match berikutnya.

## Hasil verifikasi
- `godot --headless --path . -s res://tests/run_tests.gd` →
  **PASSED: 847  FAILED: 0** (823 lama + 24 baru, semua hijau).
- `--check-only` semua file .gd baru/diubah → **OK** (8/8).
- **Smoke test nyata** (`tests/tools/run_smoke_bot.sh`, log:
  `tests/reports/multiplayer/20261110_023324_bot/`):
  - server headless WS port 27751 + 1 client auto-test `add_bot`.
  - client: `[AUTOTEST] BOT_IN_SNAPSHOT name=Bot 1 pid=-1` (bot tampil di
    daftar pemain).
  - server: `room DK7MQA: bot ditambahkan (nickname='Bot 1' peer_id=-1 speed=5.7 m/s)`,
    `peer -1 checkpoint 0..3 diterima`, `peer -1 finish dalam 4223 ms
    (winner=true)` → bot ikut race penuh & finish via mekanisme yang sama
    seperti pemain.
- Catatan (pra-eksisting, bukan regresi fitur ini): client penuh hingga
  `AUTOTEST RESULTS` masih terhenti karena bug lintas-modul yang sudah
  didokumentasikan di `docs/TESTING.md` (bagian Hasil Gelombang 3) dan
  `docs/reports/ws_transport.md` — juga terjadi tanpa perubahan bot ini.

## Cara pakai
1. Client connect → Buat Room.
2. Host klik **"Tambah Bot (Host)"** (bisa beberapa kali hingga room penuh).
3. Ready → Mulai. Bot ikut countdown → race → checkpoint → finish.
4. Hasil match memuat bot (`Bot N`) dengan rank/waktu.
