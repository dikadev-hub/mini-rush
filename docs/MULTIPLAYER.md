# MULTIPLAYER — Mini Rush

## Arsitektur
- Server dedicated headless (ENet, UDP default **7777**), client Godot penuh.
- Semua RPC berada di autoload `NetManager` (`res://scripts/autoload/net_manager.gd`)
  sehingga path node sama di semua peer (kontrak spec 4.5, 17 RPC).
- State pemain dikirim client 20 Hz (`rpc_submit_state`), server broadcast
  `rpc_broadcast_states` 20 Hz; client interpolasi remote dengan delay 100 ms.
- Room: kode 6 karakter dari `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (tanpa I/O/0/1),
  maks 8 pemain/room, max_rooms default 50.

## Menjalankan lokal
```bash
bash scripts/run_server.sh 7777          # server headless, log ke logs/
bash scripts/run_local_multiplayer.sh 2  # server + 2 client xvfb --auto-test
bash scripts/run_local_multiplayer.sh 4
```
Log multiplayer: `tests/reports/multiplayer/<timestamp>/`.

## Kriteria lulus (gelombang 3)
Semua client masuk room, countdown terjadi di semua client, semua client
menerima `rpc_match_results` yang sama. Kegagalan koneksi harus tampil jujur
di UI (mis. "Server tidak dapat dihubungi di 127.0.0.1:7777").

## Deployment
Lihat `docs/DEPLOYMENT.md` (VPS/Docker).
