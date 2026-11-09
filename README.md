# mini rush

multiplayer 3D racing game — godot 4.3, BY DIKA X DEV

lari, lompat, sampai finish lebih dulu. server dedicated, anti-cheat validator, room code, 8 jenis obstacle.

## fitur
- multiplayer real-time (ENet, server authoritative, tick 20 Hz)
- map rush island: platform bergerak, rotating bar, jembatan sempit, falling platform, 4 checkpoint
- validasi server: speed cap, checkpoint urut, out-of-bounds, kick pelanggar berat
- kontrol sentuh multi-touch (joystick kiri, lompat kanan) + keyboard + gamepad
- 823 unit test hijau, apk debug terverifikasi (jarsigner)

## build
```bash
./scripts/check_project.sh          # cek lingkungan
./scripts/build_android.sh debug    # apk -> build/MiniRush-debug.apk
./scripts/build_server.sh           # server linux -> build/server/
./scripts/run_local_multiplayer.sh  # test 2 client lokal
```

## status
- apk debug: 24 mb, arm64-v8a, jarsigner verified
- rpc_match_results belum terbukti end-to-end di headless multi-client (autodrive belum finish race) — jujur dicatat di docs/reports/lead_wave3.md
- visual masih primitives — aset 3d menyusul

## struktur
godot 4.3 stable · gdscript typed · sqlite tidak dipakai (state in-memory server) · renderer mobile · landscape
