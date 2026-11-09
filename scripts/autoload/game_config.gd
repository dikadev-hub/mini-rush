# scripts/autoload/game_config.gd
# Autoload: GameConfig (client & server). Owner: A1. Contract: README bagian 4.2.
extends Node

const NET_PORT: int = 7777
const MAX_PLAYERS_PER_ROOM: int = 8
const MIN_PLAYERS_TO_START: int = 1          # 1 untuk test lokal
const SERVER_STATE_RATE_HZ: float = 20.0
const CLIENT_SEND_RATE_HZ: float = 20.0
const COUNTDOWN_SECONDS: int = 5
const DEFAULT_MATCH_TIMEOUT_SEC: float = 600.0
const ROOM_EMPTY_TTL_SEC: float = 10.0
const RECONNECT_WINDOW_SEC: float = 30.0
const ROOM_CODE_LENGTH: int = 6
const ROOM_CODE_ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # tanpa I, O, 0, 1
const WS_DEFAULT_PORT: int = 3450

var is_dedicated_server: bool = false
## Default endpoint publik: domain menuju VPS 184.107.173.13 (TCP 3450 routable,
## UDP diblokir provider -> default transport WebSocket).
var server_address: String = "servergame.new.tg"
var server_port: int = NET_PORT
## Transport: "enet" (UDP) atau "ws" (WebSocket/TCP, default — untuk server publik
## yang memblokir UDP inbound). Flag CLI: --transport=ws / --ws / --transport=enet.
var transport: String = "ws"


func _ready() -> void:
	is_dedicated_server = DisplayServer.get_name() == "headless" \
		or OS.has_feature("dedicated_server") \
		or ("--server" in OS.get_cmdline_user_args())
	_parse_cli_args()


## WS: listen TCP port (default 3450, endpoint publik ws://servergame.new.tg:3450).
func _parse_cli_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			server_port = int(arg.get_slice("=", 1))
		elif arg.begins_with("--address="):
			server_address = arg.get_slice("=", 1)
		elif arg == "--transport=ws" or arg == "--ws":
			transport = "ws"
		elif arg == "--transport=enet":
			transport = "enet"
	if server_port == NET_PORT and transport == "ws" and not ("--port=" in OS.get_cmdline_user_args()):
		server_port = WS_DEFAULT_PORT  # endpoint publik: ws://servergame.new.tg:3450
