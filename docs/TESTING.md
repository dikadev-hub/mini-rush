# TESTING — Mini Rush

## Menjalankan
```bash
bash scripts/check_project.sh    # lingkungan + --import + cek sintaks semua .gd
bash scripts/test_project.sh     # unit + integration via tests/run_tests.gd
bash scripts/run_local_multiplayer.sh 2   # server + 2 client xvfb (gelombang 3)
```

## Runner
`tests/run_tests.gd` extends `SceneTree` (template spec bagian 8): `_init` →
`_run_all` → `print("PASSED: %d  FAILED: %d")` → `quit(1)` bila ada yang gagal.
Tanpa plugin GUT (mengurangi dependency eksternal).

Test dijalankan: `godot --headless --path . -s res://tests/run_tests.gd`.

## Hasil tercatat
- `tests/reports/test_run_*.log` — hasil tiap run dengan timestamp.
- Gelombang 1 (2026-11-09): `check_project.sh` LULUS (41 file .gd lolos
  `--check-only`), `test_project.sh` **PASSED: 840  FAILED: 0**.
- `scripts/input/virtual_joystick.gd` (milik A3) memunculkan parse error saat
  `--import` (baris 64) meski lolos `--check-only` — perlu ditinjau A3.

## Skenario penuh (gelombang 3, sesuai spec 8.1)
1. Desktop manual: selesaikan map dengan keyboard.
2. `run_local_multiplayer.sh 2` lalu `4`.
3. Kapasitas: client ke-9 join room → `ROOM_FULL`.
4. Disconnect saat RUNNING → DISCONNECTED, room tetap jalan.
5. Restart server → error koneksi jujur di client → reconnect ok.
6. Android: `build_android.sh debug` + `adb install -r`, catat `logcat` ke `tests/reports/android/`.
7. Multi-touch: joystick + lompat + kamera bersamaan.
8. Performa: target min 30 FPS di Android kelas bawah/menengah.

## Status (gelombang 1)
Item 1–8 menunggu modul A2–A8 selesai; integration test dengan guard skip
sudah terpasang dan dijalankan.
