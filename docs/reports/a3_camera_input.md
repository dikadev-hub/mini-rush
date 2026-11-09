# Laporan A3 — Kamera & Input

Status: **SELESAI** (sintaks OK, unit test runtime 19/19 PASS).

## File dibuat
- `scripts/input/input_provider.gd` — `InputProvider` (Node): `get_move_vector()`
  (deadzone 0.15, rescale deadzone→0, clamp 1.0, sumber terkuat menang),
  `is_jump_just_pressed()`, `is_pause_just_pressed()` (flag one-frame,
  keyboard/gamepad via action map + sentuh virtual), `get_camera_delta()`
  (akumulasi pixel, dikonsumsi sekali), `get_sensitivity()` defensif
  (`get_node_or_null("/root/SettingsManager")`, fallback 1.0 jika autoload stub).
- `scripts/input/virtual_joystick.gd` — `VirtualJoystick`: sentuh terkunci via
  `event.index`, hanya sentuh awal di separuh kiri + radius jangkauan (3× base),
  base = max(18% lebar, 120px) diameter, knob 40% base, knob digambar Panel +
  StyleBoxFlat, safe area `DisplayServer.get_display_safe_area()` dipetakan ke
  koordinat viewport. Logika di script, node dibangun di `_ready()`.
- `scripts/input/touch_buttons.gd` — `TouchButtons`: tombol JUMP (22% lebar
  layar, kanan bawah, sentuh kanan terkunci via index), tombol pause (10%
  tinggi, kanan atas; sentuhnya dikonsumsi sehingga tidak pernah jatuh ke
  joystick/drag kamera). Semua layout di dalam safe area.
- `scripts/input/touch_camera_drag.gd` — `TouchCameraDrag`: sentuh awal di
  separuh kanan (yang tidak kena tombol) terkunci ke kamera; delta pixel
  diteruskan ke provider.
- `scripts/input/touch_controls.gd` — root scene; membangun provider +
  3 kontrol di `_ready()`, menyediakan `attach_camera_rig(rig)`.
- `scripts/camera/camera_rig.gd` — `CameraRig` (Node3D) dibangun di kode:
  SpringArm3D (mask layer 1 = environment, length 5.5, clamp 2..9, margin 0.25)
  + Camera3D; follow `lerp` factor `1.0 - exp(-10*delta)`; yaw dari drag,
  pitch clamp -20°..60°; sensitivitas dari provider (`SettingsManager`).
- `scenes/ui/touch_controls.tscn` — scene minimal 3 baris (CanvasLayer + script).
- `tests/unit/test_camera_input.gd` — test runtime SceneTree.

## Verifikasi
Perintah (semua exit 0 kecuali catatan di bawah):
```
godot --headless --path . --check-only --script res://scripts/input/input_provider.gd
godot --headless --path . --check-only --script res://scripts/input/virtual_joystick.gd
godot --headless --path . --check-only --script res://scripts/input/touch_buttons.gd
godot --headless --path . --check-only --script res://scripts/input/touch_camera_drag.gd
godot --headless --path . --check-only --script res://scripts/input/touch_controls.gd
godot --headless --path . --check-only --script res://scripts/camera/camera_rig.gd
godot --headless --path . -s res://tests/unit/test_camera_input.gd
```
Hasil test runtime: `PASSED: 19  FAILED: 0` — mencakup deadzone, rescale,
clamp 1.0, drag joystick menghasilkan move, release → nol, sentuh index lain
diabaikan, jump/pause just-pressed + konsumsi flag, drag kamera, arm 5.5 /
clamp 2 & 9, mask layer 1, pitch clamp ±(-20/60), follow target.

Catatan verifikasi scene: `--check-only --script` pada `.tscn` selalu error
("Can't load script") karena engine mem-parsing .tscn sebagai script. Verifikasi
alternatif: scene di-load dan di-instantiate pada test runtime (`SCENE OK`,
bagian dari 19 test yang lulus).

## Catatan teknis
- Headless window default 64×64 membuat kontrol sentuh tidak bisa menerima
  sentuhan valid (base 120px min, margin). Test men-set `root.size` 1280×720
  sebelum menguji; di perangkat nyata tidak masalah.
- Pitch clamp: -20°..60° mengikuti konvensi pitch Godot (positif = kamera
  melihat dari atas).
- Tombol dibangun di kode (Button + StyleBoxFlat) tanpa tema global; A8 bisa
  menimpa tema nanti.

## Batasan
- Belum ada gamepad-driven camera look (spec 5.2 hanya menyebut "geser layar
  kanan atau mouse" untuk rotasi kamera) — right stick tidak dipetakan.
- Tombol respawn (spec bagian 7) belum dibuat: munculnya bergantung state
  pemain (`KILL_Y + 3`, checkpoint staleness) milik A5/A2; ukurannya kecil dan
  hanya bantuan. Siap ditambahkan di TouchButtons jika diminta (CR).
- Pengujian fisik Android (multi-touch di perangkat) belum bisa dijalankan
  di lingkungan ini; test memakai `Input.parse_input_event` dengan
  `InputEventScreenTouch/Drag` asli sesuai spec 8.1 `--auto-test`.

## Masalah terbuka
- Tidak ada CR. `SettingsManager` masih stub (A8); sensitivitas fallback 1.0
  sampai `camera_sensitivity` tersedia.
