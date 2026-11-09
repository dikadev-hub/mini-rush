# scripts/autoload/audio_manager.gd
# Autoload: AudioManager (client). Owner: A8. Kontrak README 5.7.
extends Node

signal music_changed(track: String)

const SFX_PATHS: Dictionary = {
	"button": "res://assets/audio/sfx/button.wav",
	"jump": "res://assets/audio/sfx/jump.wav",
	"land": "res://assets/audio/sfx/land.wav",
	"checkpoint": "res://assets/audio/sfx/checkpoint.wav",
	"countdown_tick": "res://assets/audio/sfx/countdown_tick.wav",
	"countdown_go": "res://assets/audio/sfx/countdown_go.wav",
	"victory": "res://assets/audio/sfx/victory.wav",
	"defeat": "res://assets/audio/sfx/defeat.wav",
}
const MAX_SFX_VOICES: int = 8
const CROSSFADE_SEC: float = 0.5
const MUSIC_PATH: String = "res://assets/audio/music/theme_loop.wav"

var _sfx_streams: Dictionary = {}
var _music_player: AudioStreamPlayer
var _crossfade_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _current_music: String = ""
var _voice_index: int = 0


func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_music_player = _make_player("Music")
	_music_player.finished.connect(_on_music_finished)
	_crossfade_player = _make_player("Music")
	_crossfade_player.finished.connect(_on_music_finished)
	for i: int in range(MAX_SFX_VOICES):
		_sfx_players.append(_make_player("SFX"))
	_sfx_streams.clear()
	for key: String in SFX_PATHS:
		var path: String = SFX_PATHS[key]
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path) as AudioStream
			if stream != null:
				_sfx_streams[key] = stream


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) < 0:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func _make_player(bus_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus_name
	add_child(p)
	return p


func play_sfx(sfx_name: String) -> void:
	if not _sfx_streams.has(sfx_name):
		return
	for p: AudioStreamPlayer in _sfx_players:
		if not p.playing:
			p.stream = _sfx_streams[sfx_name]
			p.play()
			return
	_voice_index = (_voice_index + 1) % MAX_SFX_VOICES
	var oldest: AudioStreamPlayer = _sfx_players[_voice_index]
	oldest.stop()
	oldest.stream = _sfx_streams[sfx_name]
	oldest.play()


func play_music(music_name: String = "theme_loop") -> void:
	if _current_music == music_name and (_music_player.playing or _crossfade_player.playing):
		return
	if music_name != "theme_loop":
		return
	var stream: AudioStream = load(MUSIC_PATH) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = int(wav.data.size() / 2)
	_current_music = music_name
	if _music_player.playing:
		_crossfade_player.stream = stream
		_crossfade_player.volume_db = -40.0
		_crossfade_player.play()
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_crossfade_player, "volume_db", 0.0, CROSSFADE_SEC)
		tw.tween_property(_music_player, "volume_db", -40.0, CROSSFADE_SEC)
		tw.chain().tween_callback(_stop_old_music)
	else:
		_music_player.stream = stream
		_music_player.volume_db = 0.0
		_music_player.play()
	music_changed.emit(music_name)


func stop_music() -> void:
	_current_music = ""
	if _music_player.playing:
		var tw := create_tween()
		tw.tween_property(_music_player, "volume_db", -40.0, CROSSFADE_SEC)
		tw.tween_callback(_music_player.stop)


func _stop_old_music() -> void:
	_music_player.stop()
	_music_player.volume_db = 0.0


func _on_music_finished() -> void:
	if _current_music == "theme_loop" and not _music_player.playing:
		_music_player.play()
