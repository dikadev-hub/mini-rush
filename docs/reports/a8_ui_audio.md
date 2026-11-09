# Laporan A8 — UI, Audio, Profil (Gelombang 2)

Tanggal: 2026-11-09. Owner: A8.

## File dibuat
- `scripts/autoload/settings_manager.gd` — ConfigFile `user://settings.cfg` (section audio/camera/controls/graphics/display/locale); `apply_all()` saat boot: volume bus Music/SFX, `Engine.max_fps`, `msaa_3d` + `scaling_3d_scale`, `TranslationServer.set_locale`.
- `scripts/autoload/profile_manager.gd` — `user://profile.cfg`: player_id UUID v4, nickname, character_id, player_token, total_matches, total_wins, best_time_ms. Statistik HANYA dari `apply_match_results()` (dipanggil dari `result_screen.show_results`, terhubung `NetManager.match_results_received`). Leaderboard lokal `user://leaderboard.cfg` (label "Lokal" di UI).
- `scripts/autoload/audio_manager.gd` — bus Master/Music/SFX (dibuat jika belum ada), `play_sfx(name)` / `play_music("theme_loop")`, crossfade 0.5 s, polifoni maks 8 voice, loop musik.
- `scripts/ui/ui_theme.gd` (class `UITheme`) — Theme global: font Nunito OFL, base 28 px, tombol corner_radius 18 shadow 6, palet primer teal + aksen oranye + netral gelap (tanpa neon), helper `format_time_ms`.
- `scripts/ui/main_menu.gd` + `scenes/ui/main_menu.tscn` — logo, Play/Settings/Profile/Leaderboard, status koneksi, preview karakter SubViewport (kapsul placeholder, tidak ada model dari A2 di assets/characters).
- `scripts/ui/hud.gd` + `scenes/ui/hud.tscn` — countdown besar tengah, timer race, posisi 1-dari-N (`set_player_position`), indikator CP, jumlah pemain, tombol pause; tersambung sinyal NetManager (`match_countdown_started`, `match_started`, `checkpoint_ack_received`, `match_results_received`).
- `scripts/ui/pause_menu.gd` + `scenes/ui/pause_menu.tscn` — Resume/Settings/Leave Match, overlay CanvasLayer.
- `scripts/ui/result_screen.gd` + `scenes/ui/result_screen.tscn` — pemenang, tabel ranking (nickname/waktu/status), Play Again hanya host (dari snapshot), Return to Lobby; SFX victory/defeat.
- `scripts/ui/settings_menu.gd` + `scenes/ui/settings_menu.tscn` — slider music/sfx/sensitivitas kamera+kontrol, dropdown kualitas Low/Medium/High, FPS 30/60, bahasa id/en; tersimpan via SettingsManager.
- `scripts/ui/profile_screen.gd` + `scenes/ui/profile_screen.tscn` — player ID, edit nickname, karakter, stats.
- `scripts/ui/leaderboard_screen.gd` + `scenes/ui/leaderboard_screen.tscn` — leaderboard lokal, label "Lokal".
- `tests/unit/test_a8_managers.gd` — test nyata settings save/load + apply, profile persist + statistik dari results, bus audio + volume + SFX polifoni.
- `assets/audio/sfx/{button,jump,land,checkpoint,countdown_tick,countdown_go,victory,defeat}.wav` dan `assets/audio/music/theme_loop.wav` — dibuat prosedural (Python, sine/noise), CC0, dicatat di `docs/CREDITS.md`.
- `assets/ui/nunito.ttf` — Nunito OFL dari Google Fonts, dicatat di `docs/CREDITS.md`.

## File diubah
- `tests/run_tests.gd` — mendaftarkan `test_a8_managers.gd` ke runner.
- `docs/CREDITS.md` — entri font dan audio.

## Verifikasi (bukti)
- Sintaks (`--check-only`): settings_manager, profile_manager, audio_manager, ui_theme, test_a8_managers = 0 error. Script UI (main_menu, hud, pause_menu, result_screen, settings_menu, profile_screen, leaderboard_screen) melaporkan 1 "Compile Error: Identifier not found: AudioManager" — **false positive `--check-only` yang tidak memuat autoload** (dikonfirmasi: file milik agent lain `scenes/lobby/lobby_ui.gd` juga melaporkan hal sama untuk `NetManager`). Bukti runtime menggantikan ini (di bawah).
- Runtime semua 7 scene UI headless (`godot --headless --path . scenes/ui/<x>.tscn --quit`): **0 SCRIPT ERROR semuanya**.
- Unit test: `godot --headless --path . -s res://tests/run_tests.gd` → **PASSED: 823 FAILED: 0** (termasuk ~27 asersi A8 baru).

## Catatan integrasi (tidak mengubah kontrak)
- Statistik profil di-update dari `NetManager.match_results_received` melalui `result_screen.show_results` — memenuhi aturan "statistik hanya dari rpc_match_results, bukan dihitung client". Jika lead ingin pemutakhiran lebih awal (misal saat HUD menerima results), bisa dipindahkan tanpa perubahan kontrak.
- Server mengirim `results` dengan kunci `rank/peer_id/nickname/time_ms/status` (cocok dengan `match_manager.build_results` A7) — sudah diverifikasi terbaca oleh result_screen.
- HUD menghitung countdown lokal dari `match_countdown_started` (tick per detik); waktu resmi tetap dari server.
- `main.gd` (A1) masih kosong — routing ke menu saat client start perlu lead/A6 menghubungkan `SceneRouter.goto_scene("res://scenes/ui/main_menu.tscn")`; tidak saya sentuh (bukan milik saya).

## Keterbatasan
- Preview karakter memakai CapsuleMesh placeholder — belum ada model .glb dari A2 di `assets/characters/`.
- Musik hanya satu track loop sederhana (prosedural).
- Belum ada integrasi HUD ke posisi ranking real-time (butuh RaceController A5 untuk memanggil `hud.set_player_position`).
- Tema global belum dipasang di project.godot (`gui/theme/custom` milik A1); scene UI memakai UITheme via helper style per node, dan `theme.default_font` dapat dipasang lead lewat `UITheme.build()` bila diinginkan.
