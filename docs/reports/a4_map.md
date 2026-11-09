# Laporan A4 — Map & Rintangan (Gelombang 1)

Tanggal: 2026-11-09. Godot 4.3.stable headless.

## File dibuat

| File | Isi |
|---|---|
| `scripts/obstacles/obstacle_materials.gd` | Material bersama (cache 1 instance per warna) + helper `box_body` (StaticBody3D+BoxShape3D+BoxMesh) dan `box_animatable_body` |
| `scripts/obstacles/static_platform.gd` | Obstacle 1: platform statis, `@export size` |
| `scripts/obstacles/moving_platform.gd` | Obstacle 2: AnimatableBody3D `sync_to_physics=true`, `@export axis/distance/speed/pause_time`, bolak-balik + pause di ujung |
| `scripts/obstacles/rotating_bar.gd` | Obstacle 3: AnimatableBody3D bar berputar, `@export rpm/length/axis` |
| `scripts/obstacles/narrow_bridge.gd` | Obstacle 4: jembatan sempit, `@export length/width` (clamp min 1.2 m) |
| `scripts/obstacles/sliding_barrier.gd` | Obstacle 5: AnimatableBody3D penghalang geser sinusoidal, `@export range/period` |
| `scripts/obstacles/falling_platform.gd` | Obstacle 6: `@export fall_delay/respawn_delay`, jatuh setelah diinjak (Area3D sensor), respawn otomatis |
| `scripts/obstacles/checkpoint.gd` | Obstacle 7: Area3D SphereShape radius MapData, mask layer 2, tiang berubah warna saat aktif, signal `checkpoint_entered(index)` |
| `scripts/obstacles/finish_line.gd` | Obstacle 8: Area3D finish radius `MapData.FINISH_RADIUS`, gerbang visual, signal `finish_entered` |
| `scripts/maps/rush_island_builder.gd` | Builder utama map, membaca `MapData` (hanya dibaca, tidak diubah) |
| `scenes/maps/rush_island.tscn` | Scene minimal (root Node3D + script builder) — sesuai aturan 6.1: logika dibangun di kode |
| `tests/integration/test_map_builder.gd` | Test runtime SceneTree (headless) |

## Verifikasi

Sintaks (semua exit 0):
```
for f in scripts/obstacles/*.gd scripts/maps/rush_island_builder.gd: \
  godot --headless --path . --check-only --script res://$f
```

Runtime (`godot --headless --path . -s res://tests/integration/test_map_builder.gd`):
```
PASSED: 10  FAILED: 0
[OK] platform statis >= 10 (19)      [OK] AnimatableBody3D = 5, sync_to_physics=true semua
[OK] 2 falling platform              [OK] 4 checkpoint dari MapData
[OK] 1 garis finish                  [OK] tepat 1 DirectionalLight3D
[OK] 2 MultiMeshInstance3D dekorasi  [OK] checkpoint mask layer 2 + radius MapData
[OK] MapData tidak diubah
```

## Layout Rush Island (urutan wajib, mengikuti MapData)

1. Platform awal 10x8 m di z=4 (permukaan atas y=1.0, spawn MapData.SPAWN_POSITION).
2. 3 platform lompatan 3x3 m, celah tepi 2.5 m (jarak pusat 5.5 m), naik ke checkpoint 0 (0,1,-12).
3. 2 platform bergerak (horizontal 5 m / 2 m·s⁻¹, vertikal 3 m / 1.5 m·s⁻¹) → checkpoint 1 (0,4,-32).
4. Rotating bar (14 rpm, panjang 8 m) di atas jalur → checkpoint 2 (-6,6,-52).
5. Jembatan sempit 12 m x 1.6 m → checkpoint 3 (6,8,-70).
6. Sliding barrier (range 6 m, period 3 s) + 2 falling platform (fall_delay 0.8 s, respawn 3 s).
7. Garis finish di MapData.FINISH_POSITION (0,9,-90).

## Aturan yang dipenuhi

- Kolisi: layer 1 = environment (semua platform), checkpoint/finish Area3D mask layer 2 saja (bit trigger di collision_layer untuk sensor falling platform).
- Material bersama: 1 cache StandardMaterial3D per warna; BoxMesh reuse.
- Performa: tepat 1 DirectionalLight3D shadow; dekorasi pohon/batu via 2 MultiMeshInstance3D (18 instance total).

## Batasan / catatan

- **Aset glb belum ada** — semua visual pakai BoxMesh/CylinderMesh/TorusMesh berwarna sesuai instruksi ("visual primitives warna — aset glb menyusul").
- Obstacle dibangun di kode; `scenes/obstacles/*.tscn` tidak dibuat (boleh, tidak wajib; aturan 0.7 menghindari .tscn tulisan tangan). Obstacle bisa di-instance dari class (`MovingPlatform.new()` dll.) atau nanti dibungkus scene minimal.
- A5 (race_controller) menghubungkan `Checkpoint.checkpoint_entered` / `FinishLine.finish_entered` ke logika klaim; checkpoint hanya memicu indikator visual untuk pemain authority.
- Peringatan headless `Parameter "m" is null` (dummy renderer) tidak memengaruhi gameplay — hanya artifact mode `--headless`.
- Jarak platform menuju checkpoint dihitung dari permukaan atas platform (y platform + 0.5); perlu diuji bersama controller A2 apakah lompatan gap 2.5 m terjangkau dengan jump_velocity 9.8 m/s — untuk uji integrasi A2+A4.
