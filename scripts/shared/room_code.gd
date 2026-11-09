# scripts/shared/room_code.gd
# Generator kode room. Owner: A1. Memakai konstanta dari GameConfig.
class_name RoomCode
extends RefCounted

const ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # tanpa I, O, 0, 1
const LENGTH: int = 6

static func generate() -> String:
	var code := ""
	for i in LENGTH:
		var idx := randi() % ALPHABET.length()
		code += ALPHABET[idx]
	return code

static func is_valid(code: String) -> bool:
	if code.length() != LENGTH:
		return false
	for i in code.length():
		if not ALPHABET.contains(code[i]):
			return false
	return true
