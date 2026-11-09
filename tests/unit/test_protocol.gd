# tests/unit/test_protocol.gd — A9. Test konstanta kontrak protokol (owner A1).
extends RefCounted

func run(t) -> void:
	t.check(Protocol.PROTOCOL_VERSION == 1, "PROTOCOL_VERSION == 1")
	t.check(Protocol.NICKNAME_MIN_LEN == 2, "NICKNAME_MIN_LEN == 2")
	t.check(Protocol.NICKNAME_MAX_LEN == 16, "NICKNAME_MAX_LEN == 16")
	t.check(Protocol.MAX_SPEED == 14.0, "MAX_SPEED == 14.0")
	t.check(Protocol.MAX_POSITION_DELTA_FACTOR == 1.5, "MAX_POSITION_DELTA_FACTOR == 1.5")
	t.check(Protocol.MAX_ALLOWED_TELEPORT_DIST == 6.0, "MAX_ALLOWED_TELEPORT_DIST == 6.0")
	t.check(Protocol.RoomState.LOBBY == 0 and Protocol.RoomState.COUNTDOWN == 1
		and Protocol.RoomState.RUNNING == 2 and Protocol.RoomState.FINISHED == 3,
		"RoomState enum urutan LOBBY COUNTDOWN RUNNING FINISHED")
	t.check(Protocol.PlayerStatus.ALIVE == 0 and Protocol.PlayerStatus.FINISHED == 1
		and Protocol.PlayerStatus.DISCONNECTED == 2 and Protocol.PlayerStatus.DNF == 3,
		"PlayerStatus enum urutan ALIVE FINISHED DISCONNECTED DNF")
	t.check(Protocol.ErrorCode.ROOM_FULL == 2, "ErrorCode ROOM_FULL == 2")
	t.check(Protocol.ErrorCode.VERSION_MISMATCH == 6, "ErrorCode VERSION_MISMATCH == 6")
