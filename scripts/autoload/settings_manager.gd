# scripts/autoload/settings_manager.gd
# Autoload: SettingsManager (client). Owner: A8. Kontrak README 5.7.
extends Node

signal setting_changed(section: String, key: String, value: Variant)

const SETTINGS_PATH: String = "user://settings.cfg"
const QUALITY_LOW: int = 0
const QUALITY_MEDIUM: int = 1
const QUALITY_HIGH: int = 2

var music_volume: float = 0.8
var sfx_volume: float = 0.8
var camera_sensitivity: float = 1.0
var controls_sensitivity: float = 1.0
var graphics_quality: int = QUALITY_MEDIUM
var fps_limit: int = 60
var locale: String = "id"


func _ready() -> void:
	load_settings()
	apply_all()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		return
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	camera_sensitivity = clampf(float(cfg.get_value("camera", "camera_sensitivity", camera_sensitivity)), 0.1, 3.0)
	controls_sensitivity = clampf(float(cfg.get_value("controls", "controls_sensitivity", controls_sensitivity)), 0.1, 3.0)
	graphics_quality = clampi(int(cfg.get_value("graphics", "quality", graphics_quality)), QUALITY_LOW, QUALITY_HIGH)
	fps_limit = int(cfg.get_value("display", "fps_limit", fps_limit))
	locale = str(cfg.get_value("locale", "locale", locale))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("camera", "camera_sensitivity", camera_sensitivity)
	cfg.set_value("controls", "controls_sensitivity", controls_sensitivity)
	cfg.set_value("graphics", "quality", graphics_quality)
	cfg.set_value("display", "fps_limit", fps_limit)
	cfg.set_value("locale", "locale", locale)
	cfg.save(SETTINGS_PATH)


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_bus_volume("Music", music_volume)
	setting_changed.emit("audio", "music_volume", music_volume)


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_bus_volume("SFX", sfx_volume)
	setting_changed.emit("audio", "sfx_volume", sfx_volume)


func set_camera_sensitivity(v: float) -> void:
	camera_sensitivity = clampf(v, 0.1, 3.0)
	setting_changed.emit("camera", "camera_sensitivity", camera_sensitivity)


func set_controls_sensitivity(v: float) -> void:
	controls_sensitivity = clampf(v, 0.1, 3.0)
	setting_changed.emit("controls", "controls_sensitivity", controls_sensitivity)


func set_graphics_quality(q: int) -> void:
	graphics_quality = clampi(q, QUALITY_LOW, QUALITY_HIGH)
	_apply_quality()
	setting_changed.emit("graphics", "quality", graphics_quality)


func set_fps_limit(fps: int) -> void:
	fps_limit = fps
	Engine.max_fps = fps
	setting_changed.emit("display", "fps_limit", fps)


func set_locale(loc: String) -> void:
	locale = loc
	TranslationServer.set_locale(loc)
	setting_changed.emit("locale", "locale", loc)


func apply_all() -> void:
	_apply_bus_volume("Music", music_volume)
	_apply_bus_volume("SFX", sfx_volume)
	Engine.max_fps = fps_limit
	_apply_quality()
	TranslationServer.set_locale(locale)


func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		push_warning("SettingsManager: bus audio tidak ditemukan: " + bus_name)
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func _apply_quality() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	match graphics_quality:
		QUALITY_LOW:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.scaling_3d_scale = 0.7
		QUALITY_MEDIUM:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.scaling_3d_scale = 1.0
		QUALITY_HIGH:
			vp.msaa_3d = Viewport.MSAA_4X
			vp.scaling_3d_scale = 1.0
