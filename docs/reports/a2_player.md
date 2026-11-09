# Laporan A2 — Karakter & Gerak (Gelombang 1)

Tanggal: 2026-11-09

## File dibuat
- `scripts/player/player_controller.gd` — `PlayerController` (CharacterBody3D), spec bagian 5.1.
- `scripts/player/player_visual.gd` — `PlayerVisual`: capsule placeholder + warna, animasi via
  AnimationPlayer jika tersedia, fallback tween scale-bounce saat land (`has_animation()` check, no crash).
- `scripts/player/player_scene_builder.gd` — `PlayerSceneBuilder.build(peer_id)`: membangun scene
  pemain di kode (body + CollisionShape3D capsule + Visual), sesuai aturan 0.7 (tanpa .tscn tulisan tangan).
- `tests/unit/test_a2_runner.gd` — runner test SceneTree standalone (39 assertion).

## File diubah
- Tidak ada file milik agent lain. Tidak ada perubahan kontrak (bagian 4 tidak disentuh).

## Spesifikasi yang diimplementasikan (bagian 5.1)
- Semua 10 `@export` dengan nilai default sesuai tabel (max_speed 8.5 … respawn_invuln_time 1.0).
- Input HANYA dari `InputProvider` (A3): `get_move_vector()` + `is_jump_just_pressed()`.
  Provider dicari sebagai child dengan script class `InputProvider` (atau group `input_provider`,
  atau lewat `@export input_provider`). Tidak ada pemanggilan `Input.*` di controller.
- `move_and_slide()` + `up_direction = Vector3.UP` + `floor_max_angle = deg_to_rad(45)`.
- Coyote time (0.12 s) dan jump buffer (0.12 s); satu konsumsi per coyote window (tanpa double jump).
- Gravity dari `physics/3d/default_gravity` × `gravity_scale`.
- Rotasi yaw mengikuti arah gerak dengan `Basis.slerp`, rate `rotation_speed`.
- Signals: `jumped`, `landed`, `respawned`, `animation_changed(anim_name: StringName)`.
- `respawn_to(position)`: reset velocity, coyote, buffer, animasi; memulai invulnerability
  (`is_invulnerable()`, timer `respawn_invuln_time`). Flag `_coyote_consumed` juga di-reset.
- `landed` di-emit saat transisi udara → tanah setelah `move_and_slide`.

## Perintah verifikasi
```bash
cd ~/mini_rush
# 1. Sintaks (semua lolos, tanpa parse error):
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . --check-only \
  --script res://scripts/player/player_controller.gd
# (idem: player_visual.gd, player_scene_builder.gd, tests/unit/test_a2_runner.gd)

# 2. Test perilaku (39/39 PASSED, exit 0):
~/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . -s res://tests/unit/test_a2_runner.gd
```

## Output verifikasi (ringkas)
```
[OK] scene builder yields PlayerController
[OK] max_speed 8.5 / accel 28 / decel 34 / air_accel 9 / jump 8.0 / gravity_scale 1.0
[OK] rotation_speed 12 / coyote 0.12 / buffer 0.12 / respawn_invuln 1.0
[OK] up_direction is UP / floor_max_angle 45deg
[OK] player lands on floor / rest height 0.80 / landed signal emitted / idle animation reported
[OK] falls back to floor under gravity
[OK] jumped signal emitted / jump raises player (peak 3.38)
[OK] lands after jump
[OK] accelerates under sustained input (8.50 m/s) / speed capped at max_speed
[OK] moves along -Z forward / decelerates to rest when input released
[OK] ground jump accepted / no double jump in air
[OK] player standing on ledge / walked off the ledge / coyote-time jump accepted
[OK] respawn resets velocity / grants invulnerability / resets animation
[OK] invulnerability expires after ~1s / respawned player settles on floor
[OK] signal jumped / landed / respawned / animation_changed exists
PASSED: 39  FAILED: 0
```
Catatan lingkungan: `ServerMain` autoload ikut booting saat test (`port=7777`) karena test
dijalankan dengan `--path .`; tidak mengganggu hasil. Error `mesh_get_surface_count` muncul
hanya di renderer dummy headless (placeholder mesh), bukan bug gameplay.

## Masalah terbuka / catatan
1. **Visual pemain masih placeholder** (capsule `StandardMaterial3D` warna biru). Aset `.glb`
   karakter asli menyusul (Agent 4/resource search bagian 1.2); `PlayerVisual` sudah siap memakai
   `AnimationPlayer` dari model bila punya animasi `idle/run/jump/fall/land`.
2. Kamera rig (`SpringArm3D` + `Camera3D`) adalah tanggung jawab A3 (bagian 5.2 menyebut
   `scenes/player/` memuat CameraRig); tidak dibuat di sini untuk menghindari tabrakan kepemilikan.
3. Integration test respawn ke checkpoint terakhir bergantung A5 (race_controller) — di luar
   lingkup A2; yang diuji di sini adalah kontrak `respawn_to()` (reset velocity/state/invuln).
4. Test coyote-time di headless bergantung timing frame fisika (fixed 60 Hz) — stabil, tetapi
   angka frame di test disetel empiris (pemain bergerak dari diam, bukan kecepatan penuh).
