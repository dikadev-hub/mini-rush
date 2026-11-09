# scripts/shared/protocol.gd
# Kontrak protokol jaringan. Owner: A1. Jangan ubah tanpa change request.
class_name Protocol
extends RefCounted

# Status room
enum RoomState { LOBBY, COUNTDOWN, RUNNING, FINISHED }

# Status pemain dalam match
enum PlayerStatus { ALIVE, FINISHED, DISCONNECTED, DNF }

# Kode error standar, dikirim server ke client
enum ErrorCode {
	OK = 0,
	ROOM_NOT_FOUND = 1,
	ROOM_FULL = 2,
	ROOM_ALREADY_STARTED = 3,
	INVALID_NICKNAME = 4,
	SERVER_BUSY = 5,
	VERSION_MISMATCH = 6,
	NOT_HOST = 7,
	INVALID_STATE = 8,
}

const PROTOCOL_VERSION: int = 1
const NICKNAME_MAX_LEN: int = 16
const NICKNAME_MIN_LEN: int = 2

# Batas validasi gerak server (anti-cheat dasar)
const MAX_SPEED: float = 14.0          # m/s, di atas kecepatan normal + toleransi
const MAX_POSITION_DELTA_FACTOR: float = 1.5
const MAX_ALLOWED_TELEPORT_DIST: float = 6.0

# Skema pesan state pemain (dict)
# {
#   "pid": int,          # peer id
#   "p": Vector3,        # posisi
#   "r": float,          # rotasi Y (radian)
#   "a": StringName,     # nama animasi: "idle","run","jump","fall","land"
#   "g": bool,           # on_floor
#   "t": int             # timestamp klien (ms), untuk interpolasi
# }
