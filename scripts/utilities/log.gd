# scripts/utilities/log.gd
# Logger server: tulis ke user://logs/server.log dan stdout.
# Format: [timestamp] [level] pesan. Owner: A7.
class_name Log
extends RefCounted

enum Level { DEBUG, INFO, WARN, ERROR }

const LEVEL_NAMES: Dictionary = {
	Level.DEBUG: "debug",
	Level.INFO: "info",
	Level.WARN: "warn",
	Level.ERROR: "error",
}

const LOG_PATH: String = "user://logs/server.log"
const MAX_LOG_BYTES: int = 5 * 1024 * 1024

static var _min_level: int = Level.INFO
static var _file: FileAccess = null


## Inisialisasi logger. level_str: "debug", "info", "warn", "error".
static func init_logger(level_str: String) -> void:
	_min_level = level_from_string(level_str)
	DirAccess.make_dir_recursive_absolute(LOG_PATH.get_base_dir())
	_rotate_if_needed()
	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE_READ)
	if _file == null:
		push_error("Log: gagal membuka %s (error %d)" % [LOG_PATH, FileAccess.get_open_error()])
		return
	_file.seek_end()


static func level_from_string(level_str: String) -> int:
	match level_str.to_lower():
		"debug":
			return Level.DEBUG
		"warn", "warning":
			return Level.WARN
		"error":
			return Level.ERROR
		_:
			return Level.INFO


static func debug(msg: String) -> void:
	_write(Level.DEBUG, msg)


static func info(msg: String) -> void:
	_write(Level.INFO, msg)


static func warn(msg: String) -> void:
	_write(Level.WARN, msg)


static func error(msg: String) -> void:
	_write(Level.ERROR, msg)


static func _write(level: int, msg: String) -> void:
	if level < _min_level:
		return
	var line: String = "[%s] [%s] %s" % [_timestamp(), LEVEL_NAMES[level], msg]
	print(line)
	if _file != null and _file.is_open():
		_file.store_line(line)
		_file.flush()


static func _timestamp() -> String:
	var t: Dictionary = Time.get_datetime_dict_from_system(true)
	var msec: int = Time.get_ticks_msec() % 1000
	return "%04d-%02d-%02d %02d:%02d:%02d.%03d" % [
		t.year, t.month, t.day, t.hour, t.minute, t.second, msec,
	]


static func _rotate_if_needed() -> void:
	if not FileAccess.file_exists(LOG_PATH):
		return
	var dir := DirAccess.open(LOG_PATH.get_base_dir())
	if dir == null:
		return
	if dir.file_exists(LOG_PATH.get_file()) and _file_size(LOG_PATH) < MAX_LOG_BYTES:
		return
	var backup: String = LOG_PATH + ".1"
	if dir.file_exists(backup.get_file()):
		dir.remove(backup.get_file())
	dir.rename(LOG_PATH.get_file(), backup.get_file())


static func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var size: int = f.get_length()
	f.close()
	return size
