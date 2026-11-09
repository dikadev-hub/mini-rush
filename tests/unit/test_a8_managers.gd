# Unit test A8: SettingsManager save/load, ProfileManager persist, AudioManager bus & SFX.
extends RefCounted


func run(t) -> void:
	print("  -- A8 managers")
	_test_settings_save_load(t)
	_test_settings_apply(t)
	_test_profile_persist(t)
	_test_profile_stats(t)
	_test_audio_buses(t)
	_test_audio_sfx(t)


func _test_settings_save_load(t) -> void:
	var sm := _make_settings()
	sm.set_music_volume(0.45)
	sm.set_sfx_volume(0.7)
	sm.set_camera_sensitivity(1.5)
	sm.set_graphics_quality(2)
	sm.set_fps_limit(30)
	sm.set_locale("en")
	sm.save_settings()
	var sm2 := _make_settings()
	sm2.load_settings()
	t.check(absf(sm2.music_volume - 0.45) < 0.001, "settings: music volume tersimpan")
	t.check(absf(sm2.sfx_volume - 0.7) < 0.001, "settings: sfx volume tersimpan")
	t.check(absf(sm2.camera_sensitivity - 1.5) < 0.001, "settings: sensitivitas kamera tersimpan")
	t.check(sm2.graphics_quality == 2, "settings: kualitas grafis tersimpan")
	t.check(sm2.fps_limit == 30, "settings: fps limit tersimpan")
	t.check(sm2.locale == "en", "settings: locale tersimpan")


func _test_settings_apply(t) -> void:
	var sm := _make_settings()
	sm.set_fps_limit(30)
	t.check(Engine.max_fps == 30, "settings: Engine.max_fps diterapkan")
	sm.set_locale("id")
	t.check(TranslationServer.get_locale() == "id", "settings: locale diterapkan")


func _make_settings() -> Node:
	var script: Script = load("res://scripts/autoload/settings_manager.gd")
	var n: Node = script.new()
	n.name = "SettingsManagerTest"
	Engine.get_main_loop().root.add_child(n)
	return n


func _make_profile() -> Node:
	var script: Script = load("res://scripts/autoload/profile_manager.gd")
	var n: Node = script.new()
	n.name = "ProfileManagerTest"
	Engine.get_main_loop().root.add_child(n)
	return n


func _test_profile_persist(t) -> void:
	var pm := _make_profile()
	t.check(pm.player_id.length() == 36, "profil: player_id UUID v4 dibuat")
	t.check(pm.player_token.length() == 36, "profil: player_token dibuat")
	pm.set_nickname("Racer")
	pm.set_character_id(2)
	var pm2 := _make_profile()
	t.check(pm2.nickname == "Racer", "profil: nickname persist")
	t.check(pm2.character_id == 2, "profil: character_id persist")
	t.check(pm2.player_id == pm.player_id, "profil: player_id persist")
	pm.queue_free()
	pm2.queue_free()


func _test_profile_stats(t) -> void:
	var pm := _make_profile()
	var before_matches: int = pm.total_matches
	var results: Array = [
		{"rank": 1, "peer_id": 101, "nickname": "A", "time_ms": 50000, "status": int(Protocol.PlayerStatus.FINISHED)},
		{"rank": 2, "peer_id": 202, "nickname": "B", "time_ms": -1, "status": int(Protocol.PlayerStatus.DNF)},
	]
	pm.apply_match_results(results, 101)
	t.check(pm.total_matches == before_matches + 1, "profil: total match bertambah dari hasil server")
	t.check(pm.best_time_ms == 50000, "profil: waktu terbaik dari hasil server")
	pm.apply_match_results(results, 101)
	t.check(pm.best_time_ms == 50000, "profil: waktu terbaik tidak memburuk")
	var board: Array[Dictionary] = pm.get_sorted_leaderboard()
	t.check(board.size() >= 2, "profil: leaderboard lokal terisi")
	pm.queue_free()


func _test_audio_buses(t) -> void:
	var am := _make_audio()
	am._ensure_bus("Music")
	am._ensure_bus("SFX")
	t.check(AudioServer.get_bus_index("Music") >= 0, "audio: bus Music ada")
	t.check(AudioServer.get_bus_index("SFX") >= 0, "audio: bus SFX ada")
	var settings: Node = load("res://scripts/autoload/settings_manager.gd").new()
	Engine.get_main_loop().root.add_child(settings)
	settings.set_music_volume(0.3)
	var idx := AudioServer.get_bus_index("Music")
	var expected: float = linear_to_db(0.3)
	t.check(absf(AudioServer.get_bus_volume_db(idx) - expected) < 0.01, "audio: volume bus Music mengikuti settings")
	settings.queue_free()
	am.queue_free()


func _test_audio_sfx(t) -> void:
	var am := _make_audio()
	for name: String in ["button", "jump", "land", "checkpoint", "countdown_tick", "countdown_go", "victory", "defeat"]:
		t.check(am._sfx_streams.has(name), "audio: SFX termuat: " + name)
	am.play_sfx("button")
	var playing: int = 0
	for p: AudioStreamPlayer in am._sfx_players:
		if p.playing:
			playing += 1
	t.check(playing == 1, "audio: play_sfx memainkan satu voice")
	t.check(am._sfx_players.size() == 8, "audio: polifoni maks 8 voice")
	am.queue_free()


func _make_audio() -> Node:
	var script: Script = load("res://scripts/autoload/audio_manager.gd")
	var n: Node = script.new()
	n.name = "AudioManagerTest"
	Engine.get_main_loop().root.add_child(n)
	return n
