# MINI RUSH — Kontrak Bersama (salinan README bagian 4)

> Sumber kebenaran asli: README bagian 4. Dokumen ini adalah salinan kontrak
> untuk referensi cepat. Perubahan kontrak HANYA lewat `docs/CHANGE_REQUESTS.md`
> dan disetujui lead; setiap perubahan resmi dicatat di bagian "Perubahan Resmi" di bawah.

## 4.1 Autoload (urutan di project.godot)

| Nama autoload | Path script | Berjalan di | Pemilik |
|---|---|---|---|
| `GameConfig` | `res://scripts/autoload/game_config.gd` | client & server | A1 |
| `SceneRouter` | `res://scripts/autoload/scene_router.gd` | client | A1 |
| `SettingsManager` | `res://scripts/autoload/settings_manager.gd` | client | A8 |
| `ProfileManager` | `res://scripts/autoload/profile_manager.gd` | client | A8 |
| `AudioManager` | `res://scripts/autoload/audio_manager.gd` | client | A8 |
| `NetManager` | `res://scripts/autoload/net_manager.gd` | client & server | A6 |
| `ServerMain` | `res://scripts/autoload/server_main.gd` | server (script di-load hanya jika mode server) | A7 |

Status scaffold (A1): semua 7 autoload terdaftar di `project.godot` dengan urutan persis di atas.
`GameConfig` dan `SceneRouter` diimplementasi (A1). Sisanya stub `extends Node` minimal,
diisi oleh agent pemilik (A6/A7/A8).

## 4.2 Deteksi mode (GameConfig)

```gdscript
extends Node

const NET_PORT: int = 7777
const MAX_PLAYERS_PER_ROOM: int = 8
const MIN_PLAYERS_TO_START: int = 1
const SERVER_STATE_RATE_HZ: float = 20.0
const CLIENT_SEND_RATE_HZ: float = 20.0
const COUNTDOWN_SECONDS: int = 5
const DEFAULT_MATCH_TIMEOUT_SEC: float = 600.0
const ROOM_EMPTY_TTL_SEC: float = 10.0
const RECONNECT_WINDOW_SEC: float = 30.0
const ROOM_CODE_LENGTH: int = 6
const ROOM_CODE_ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var is_dedicated_server: bool = false
var server_address: String = "127.0.0.1"
var server_port: int = NET_PORT
```

`is_dedicated_server` = true jika: `DisplayServer.get_name() == "headless"`,
atau `OS.has_feature("dedicated_server")`, atau `"--server" in OS.get_cmdline_user_args()`.
CLI: `--port=<int>`, `--address=<str>` (setelah `--`).

## 4.3 MapData (`scripts/shared/map_data.gd`, class_name `MapData`)

```
MAP_ID = "rush_island"
CHECKPOINT_POSITIONS = [V3(0,1,-12), V3(0,4,-32), V3(-6,6,-52), V3(6,8,-70)]
CHECKPOINT_RADIUS = 2.5
FINISH_POSITION = V3(0, 9, -90);  FINISH_RADIUS = 3.0
SPAWN_POSITION = V3(0, 1.5, 4)
WORLD_BOUNDS_MIN = V3(-60,-30,-100);  WORLD_BOUNDS_MAX = V3(60,60,20)
KILL_Y = -20.0
SPAWN_OFFSET_STEP = V3(1.2, 0, 0)
```

## 4.4 Protocol (`scripts/shared/protocol.gd`, class_name `Protocol`)

- `enum RoomState { LOBBY, COUNTDOWN, RUNNING, FINISHED }`
- `enum PlayerStatus { ALIVE, FINISHED, DISCONNECTED, DNF }`
- `enum ErrorCode { OK=0, ROOM_NOT_FOUND=1, ROOM_FULL=2, ROOM_ALREADY_STARTED=3, INVALID_NICKNAME=4, SERVER_BUSY=5, VERSION_MISMATCH=6, NOT_HOST=7, INVALID_STATE=8 }`
- `PROTOCOL_VERSION = 1`, `NICKNAME_MIN_LEN = 2`, `NICKNAME_MAX_LEN = 16`
- `MAX_SPEED = 14.0`, `MAX_POSITION_DELTA_FACTOR = 1.5`, `MAX_ALLOWED_TELEPORT_DIST = 6.0`
- Skema state pemain (dict): `pid:int, p:Vector3, r:float(rotY rad), a:StringName(anim), g:bool(on_floor), t:int(ms)`

Room code: `RoomCode` (`scripts/shared/room_code.gd`) — `generate()`, `is_valid(code)`;
alphabet tanpa I, O, 0, 1; panjang 6 (konstanta juga ada di `GameConfig`).

## 4.5 Daftar RPC (dideklarasikan di `NetManager`, milik A6)

| Nama RPC | Dekorator | Arah | Argumen |
|---|---|---|---|
| `rpc_request_create_room` | `@rpc("any_peer", "reliable")` | client→server | `nickname: String, character_id: int, protocol_version: int` |
| `rpc_request_join_room` | `@rpc("any_peer", "reliable")` | client→server | `room_code: String, nickname: String, character_id: int, protocol_version: int` |
| `rpc_request_leave_room` | `@rpc("any_peer", "reliable")` | client→server | — |
| `rpc_set_ready` | `@rpc("any_peer", "reliable")` | client→server | `is_ready: bool` |
| `rpc_request_start_match` | `@rpc("any_peer", "reliable")` | client→server | — |
| `rpc_room_response` | `@rpc("authority", "reliable")` | server→client | `error_code: int, room_snapshot: Dictionary` |
| `rpc_room_snapshot` | `@rpc("authority", "reliable")` | server→client | `room_snapshot: Dictionary` |
| `rpc_match_countdown` | `@rpc("authority", "reliable")` | server→client | `start_server_ms: int, countdown_sec: int` |
| `rpc_match_started` | `@rpc("authority", "reliable")` | server→client | `race_start_server_ms: int` |
| `rpc_submit_state` | `@rpc("any_peer", "unreliable_ordered")` | client→server | `state: Dictionary` |
| `rpc_broadcast_states` | `@rpc("authority", "unreliable_ordered")` | server→client | `states: Array` |
| `rpc_report_checkpoint` | `@rpc("any_peer", "reliable")` | client→server | `index: int` |
| `rpc_checkpoint_ack` | `@rpc("authority", "reliable")` | server→client | `index: int, accepted: bool` |
| `rpc_report_finish` | `@rpc("any_peer", "reliable")` | client→server | — |
| `rpc_match_results` | `@rpc("authority", "reliable")` | server→client | `results: Array` |
| `rpc_return_to_lobby` | `@rpc("authority", "reliable")` | server→client | `room_snapshot: Dictionary` |
| `rpc_server_health` | `@rpc("any_peer", "reliable")` | client→server | — |

Aturan RPC Godot 4:
- Dekorator harus persis sama di kedua sisi.
- Server mengetahui pengirim via `multiplayer.get_remote_sender_id()`; jangan percaya `peer_id` dari klien.
- Client memanggil server dengan `rpc_id(1, ...)`; server memanggil client dengan `rpc_id(peer_id, ...)`.

## 4.6 Aturan node spawn pemain

- Node pemain bernama `str(peer_id)`; parent `Players` dengan `MultiplayerSpawner.spawn_path` → `Players`.
- `player.set_multiplayer_authority(peer_id)`; pemain lokal = `is_multiplayer_authority() == true`.

## Perubahan Resmi

(none)
