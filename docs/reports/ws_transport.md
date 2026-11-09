# Laporan: Transport WebSocket (WS) — Mini Rush

Tanggal: 2026-11-10. Latar: provider VPS (184.107.173.13) memblokir SEMUA UDP
inbound (tcpdump 0 packets) → ENet (UDP) tidak bisa dipakai dari internet.
Solusi: transport WebSocket (TCP) via `WebSocketMultiplayerPeer`. RPC decorator
& skema TIDAK berubah (multiplayer API identik). protocol.gd & map_data.gd
tidak disentuh.

## Yang berubah
| File | Perubahan |
|---|---|
| `scripts/autoload/net_manager.gd` | `_peer` jadi `MultiplayerPeer` (base class); var `transport_mode` ("enet"/"ws"); fungsi baru `connect_to_server_ws(address, port)` → `WebSocketMultiplayerPeer.create_client("ws://host:port")`, timeout 8 s sama, sinyal sama. Semua RPC & helper server tidak diubah. |
| `scripts/autoload/game_config.gd` | `transport` (default **"ws"**), `WS_DEFAULT_PORT = 3450`, flag CLI `--transport=ws` / `--ws` / `--transport=enet`. Default endpoint: `servergame.new.tg:3450`. Tanpa `--port` saat ws → port 3450. |
| `scripts/autoload/server_main.gd` | `_start_transport_server()` → `_start_ws_server()` (WebSocketMultiplayerPeer.create_server) atau `_start_enet_server()`. Log `transport: websocket — server WS aktif di TCP <port>`. |
| `scenes/lobby/lobby_ui.gd` | CheckBox "pakai websocket (untuk server publik)", default mengikuti `GameConfig.transport` (ON). `_ensure_connection()` memanggil `connect_to_server_ws` bila dicentang. |
| `scripts/gameplay/auto_test.gd` | Ikut `GameConfig.transport` (ws → `connect_to_server_ws`). |
| `scripts/run_local_multiplayer.sh` | env `TRANSPORT=enet|ws` (default **ws**), flag diteruskan ke server & semua client. |
| `tests/integration/test_multiplayer_flow.gd` | Cek kontrak WS: `connect_to_server_ws`, `WebSocketMultiplayerPeer`, flag `--transport=ws`, `_start_ws_server`. |

## Hasil verifikasi
LULUS:
- `scripts/test_project.sh`: **PASSED: 823, FAILED: 0** (termasuk 4 cek kontrak
  WS baru di integration test).
- **Runtime WS end-to-end (source)**: server headless `--transport=ws --port=27745`
  + 2 client auto-test via WebSocket. Terverifikasi dari log:
  client connect WS → `ROOM_CODE=GFRHCY` → client 2 join → COUNTDOWN →
  `rpc_match_started dikirim ke 2 peer` → state 20 Hz dikirim client.
  Setara dengan baseline ENet terakhir (2026-11-09), membuktikan transport
  berfungsi.
- **Server binary export**: `build/server/MiniRushServer.x86_64` +
  `MiniRushServer.pck` (build 01:31). Smoke test: `--server --transport=ws
  --port=3980` → listen TCP, handshake WebSocket eksternal
  (`HTTP/1.1 101 Switching Protocols` berhasil); `--server` tanpa flag →
  user://logs/server.log mencatat `transport: websocket — server WS aktif di
  TCP 3450` (default sesuai endpoint publik ws://servergame.new.tg:3450).

BELUM / catatan:
- **Multi-client penuh hingga `AUTOTEST RESULTS`** tetap BLOCKED — ini bug
  lintas-modul PRA-EKSISTING (dokumen `docs/TESTING.md` bagian "Hasil Gelombang
  3"), bukan regresi WS: mode ENet pun berhenti di titik yang sama
  (client berhenti kirim state, match tidak selesai sebelum timeout 600 s).
  Milestone WS identik dengan ENet → transport disimpulkan OK.
- APK debug: ada build lama (00:05, sebelum WS). Rebuild dijalankan saat laporan
  ini ditulis — lihat `/tmp/apk_build.log`; bila gagal, lead handle rebuild
  (`bash scripts/build_android.sh debug`).

## Deploy (lead)
- Target deploy: **/opt/minirush** di VPS 184.107.173.13 — TIDAK dideploy dari
  sini; lead yang deploy.
- Jalankan: `./MiniRushServer.x86_64 --headless --server --transport=ws
  --port=3450` (atau tanpa `--port`, default ws = 3450). Buka inbound **TCP 3450**.
- Client APK connect langsung ke `ws://servergame.new.tg:3450` (default lobi),
  tanpa nginx/certbot.
- Mode ENet masih tersedia: `--transport=enet` (port default 7777 UDP).

## CLI ringkas
- Server WS: `--server --transport=ws [--port=3450]`
- Server ENet: `--server --transport=enet [--port=7777]`
- Client: default lobi = servergame.new.tg:3450 WS (checkbox dapat dimatikan
  untuk ENet).
- Test lokal: `TRANSPORT=ws bash scripts/run_local_multiplayer.sh 2`
