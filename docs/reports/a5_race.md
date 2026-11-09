# A5 — Logika Balapan Client (Gelombang 2)

## Ringkasan
Race client-side sesuai spec README 5.4 selesai, terverifikasi sintaks dan unit test PASSED.

## File yang dibuat/diubah (semua milik A5)
- `scripts/gameplay/race_controller.gd` (BARU) — `class_name RaceController`, extends Node.
- `tests/unit/test_a5_race.gd` (BARU) — unit test nyata.
- `tests/run_tests.gd` (DIUBAH, milik bersama runner) — registrasi test A5 dengan `await physics_frame` sebelum membangun node (headless SceneTree butuh 1 frame agar node berada di tree) dan a5_root Node3D sebagai parent.

## Fitur race_controller.gd
- State kontrak: `next_checkpoint_index` mulai 0, `last_checkpoint_position` default `MapData.SPAWN_POSITION`, `finish_sent`, `match_finished`.
- Checkpoint: hanya index == next yang diklaim via `NetManager.report_checkpoint(index)` (`rpc_id(1, "rpc_report_checkpoint", index)` di NetManager). Index TIDAK dimajukan sebelum ack. Optimistic UI: sinyal `checkpoint_pending_changed(index, true/false)`, query `is_checkpoint_pending(i)`. Out-of-order dan klaim duplikat saat pending diabaikan.
- Ack: `checkpoint_ack_received(index, accepted=true)` → `last_checkpoint_position = MapData.CHECKPOINT_POSITIONS[index]`, `next = index + 1`, sinyal `checkpoint_confirmed`. `accepted=false` → indikator dibatalkan, `checkpoint_rejected` di-emit, `printerr` peringatan. Ack stale diabaikan.
- Respawn: `_process` cek `player.global_position.y < MapData.KILL_Y` → `player.respawn_to(last_checkpoint_position + MapData.SPAWN_OFFSET_STEP * spawn_order)`. Sinyal `respawned_to(pos)`.
- Finish: `_on_finish_entered` (dari `FinishLine.finish_entered`, milik A4) mengirim `rpc_report_finish` tepat satu kali (flag `finish_sent`).
- `rpc_match_results` → `match_finished = true`, timer berhenti, sinyal `results_received`.
- Timer lokal display only (`start_local_timer/stop_local_timer/get_local_elapsed_ms`, sinyal `local_elapsed_changed`); tidak pernah menyatakan hasil resmi — hasil hanya dari server.
- `bind_world(checkpoints, finish_line)` untuk menghubungkan Area3D milik A4.
- NetManager diakses via lookup runtime (`_net()`), bukan identifier global, agar `--check-only --script` (tanpa autoload) lolos — false positive autoload yang didokumentasi menjadi tidak relevan untuk file ini. Test menyuntikkan stub via `_net_override_obj`.

## Verifikasi
```
$ godot --headless --path . --check-only --script res://scripts/gameplay/race_controller.gd  → EXIT 0
$ godot --headless --path . --check-only --script res://tests/unit/test_a5_race.gd          → EXIT 0
$ godot --headless --path . -s res://tests/run_tests.gd
PASSED: 823  FAILED: 0   (exit 0; ~50 check A5 di antaranya: checkpoint urut, skip/duplikat, ack accepted/rejected/stale, respawn KILL_Y + offset spawn_order, finish once, timer)
```

## Batasan / catatan integrasi
- Scene race (belum ada, kemungkinan milik lead/A9) harus: membuat `RaceController`, set `rc.player` = pemain lokal, set `rc.spawn_order` dari urutan join, panggil `bind_world(checkpoint_nodes, finish_line)`, hubungkan `NetManager.match_started` → `start_local_timer()`.
- Test A5 memakai stub NetManager (autoload tidak aktif saat `-s` SceneTree); NetManager asli dipakai saat runtime karena `_net()` menemukan `/root/NetManager`.
