# Laporan A1 — Scaffold & Kontrak (Wave 0)

Tanggal: 2026-11-09
Engine: Godot 4.3.stable.official.77dcf97d8 (`~/godot/Godot_v4.3-stable_linux.x86_64 --version`)

## File dibuat

| File | Isi |
|---|---|
| `project.godot` | Nama, renderer mobile, orientasi sensor_landscape, main scene, **7 autoload sesuai urutan kontrak 4.1**, input map (`move_left/right/up/down`, `jump`, `pause`, `respawn`) dengan keyboard + gamepad |
| `icon.svg` | Ikon placeholder |
| `scripts/autoload/game_config.gd` | Implementasi penuh sesuai kontrak 4.2 (konstanta, deteksi mode, CLI `--port=`, `--address=`) |
| `scripts/autoload/scene_router.gd` | Stub A1: API `goto_scene(path)` |
| `scripts/autoload/settings_manager.gd` | Stub minimal (`extends Node`) — milik A8 |
| `scripts/autoload/profile_manager.gd` | Stub minimal — milik A8 |
| `scripts/autoload/audio_manager.gd` | Stub minimal — milik A8 |
| `scripts/autoload/net_manager.gd` | Stub minimal — milik A6 |
| `scripts/autoload/server_main.gd` | Stub minimal — milik A7 |
| `scripts/main/main.gd` | Root scene minimal, tanpa logika |
| `scenes/main/main.tscn` | Node root + script (satu-satunya .tscn yang ditulis tangan) |
| `scripts/shared/protocol.gd` | class_name `Protocol` — enum RoomState/PlayerStatus/ErrorCode, konstanta anti-cheat, versi protokol (kontrak 4.4) |
| `scripts/shared/map_data.gd` | class_name `MapData` — checkpoint, finish, spawn, bounds (kontrak 4.3) |
| `scripts/shared/room_code.gd` | class_name `RoomCode` — `generate()`, `is_valid()`, alphabet tanpa I/O/0/1 |
| `docs/CONTRACTS.md` | Salinan kontrak bagian 4 + kolom "Perubahan Resmi" (kosong) |
| Struktur folder | `assets/*`, `scenes/{player,maps,obstacles,ui,lobby,multiplayer}`, `scripts/{player,camera,input,obstacles,gameplay,networking,server,ui,audio,profile,utilities}`, `tests/*`, `shaders`, `resources`, `server/config/server.cfg`, `docs/reports` |

## Verifikasi sintaks (`--check-only --script`)

Semua file .gd diperiksa satu per satu; hasil:

```
scripts/autoload/audio_manager.gd    exit=0
scripts/autoload/game_config.gd      exit=0
scripts/autoload/net_manager.gd      exit=0
scripts/autoload/profile_manager.gd  exit=0
scripts/autoload/scene_router.gd     exit=0
scripts/autoload/server_main.gd      exit=0
scripts/autoload/settings_manager.gd exit=0
scripts/main/main.gd                 exit=0
scripts/shared/map_data.gd           exit=0
scripts/shared/protocol.gd           exit=0
scripts/shared/room_code.gd          exit=0
```

Boot project penuh:

```
$ godot --headless --path . --quit     → exit=0, tanpa error
$ godot --headless --path . --import   → exit=0
```

## Masalah terbuka / catatan untuk agent lain

1. **`--check-only` tidak memuat autoload.** File yang mereferensikan `GameConfig` dsb. secara langsung akan gagal di `--check-only` walau benar saat runtime. Solusi A1: `main.gd` sengaja tidak mereferensikan autoload. Agent lain yang mengalaminya bisa memakai `Engine.has_singleton`/akses via `get_node("/root/GameConfig")` atau membiarkan referensi dan memverifikasi lewat boot `--quit`, lalu mencatatnya di laporan.
2. `net_manager.gd` (A6) wajib mendeklarasikan 17 RPC persis seperti tabel di `docs/CONTRACTS.md` 4.5.
3. `server_main.gd` (A7) berjalan hanya jika `GameConfig.is_dedicated_server == true`; scene main memanggil `SceneRouter` untuk tidak memuat UI di mode server (implementasi A7/A6/A8).
4. `project.godot` belum memuat `export_presets.cfg` (milik A9) dan logika gameplay/UI/networking (milik agent masing-masing).
