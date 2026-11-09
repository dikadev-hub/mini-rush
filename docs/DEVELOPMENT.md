# DEVELOPMENT — Mini Rush

## Struktur tim & kepemilikan file
Lihat spec bagian 3 (docs sumber kebenaran: README proyek). Setiap agent hanya
mengedit folder miliknya; perubahan file bersama lewat `docs/CHANGE_REQUESTS.md`.

## Workflow harian
1. `bash scripts/check_project.sh` — lingkungan + `--import` + cek sintaks semua `.gd`.
2. Kembangkan; setiap `.gd` wajib lolos `--check-only` (spec 6.1).
3. `bash scripts/test_project.sh` — unit/integration, wajib `FAILED: 0`.
4. Catat bukti di `docs/reports/<agent>.md` dan `tests/reports/`.

## Test
- Runner: `tests/run_tests.gd` (SceneTree, tanpa plugin GUT → tidak ada dependency eksternal).
- Guard: test untuk modul agent lain memakai skip dengan pesan bila class belum ada;
  jangan biarkan test gagal karena modul belum dibuat, dan jangan hapus test agar lulus.

## Konvensi kode (spec 6.3)
- Typed GDScript, satu `class_name` per file, fungsi privat diawali `_`,
  konstanta `UPPER_SNAKE_CASE`, file ≈ maksimal 300 baris.
- Kontrak (autoload, signal, RPC, skema pesan) tidak boleh diubah tanpa change request.

## Catatan performa
(fase 4 — diisi setelah profiling di perangkat/emulator)
