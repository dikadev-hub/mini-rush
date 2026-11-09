# scripts/networking/remote_player_view.gd
# Owner: A6. Menerapkan interpolasi NetManager ke node remote player (Node3D).
# Dipasang pada node remote player (mis. child "RemoteSync") di scene race.
class_name RemotePlayerView
extends Node3D

## Node3D yang posisi/rotasinya diinterpolasi (default: parent).
@export var target_path: NodePath

var _target: Node3D
var _pid: int = 0


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		_target = get_parent() as Node3D


func setup(peer_id: int) -> void:
	_pid = peer_id


func _process(_delta: float) -> void:
	if _pid <= 0 or _target == null:
		return
	var interp: Dictionary = NetManager.get_remote_interp(_pid)
	if interp.is_empty():
		return
	var pos: Vector3 = interp.get("p", _target.position)
	# Jika snapshot terlalu tua, tahan posisi terakhir (tidak ada perubahan).
	if not NetManager.is_remote_stale(_pid):
		_target.position = pos
		var rot_y: float = float(interp.get("r", _target.rotation.y))
		_target.rotation.y = rot_y
