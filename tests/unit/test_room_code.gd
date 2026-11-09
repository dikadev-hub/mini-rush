# tests/unit/test_room_code.gd — A9. Test generator kode room (owner A1).
extends RefCounted

func run(t) -> void:
	var alphabet: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	for i in 200:
		var code := RoomCode.generate()
		t.check(code.length() == 6, "kode room panjang 6 (iter %d)" % i)
		var valid_chars := true
		for c in code:
			if not alphabet.contains(c):
				valid_chars = false
		t.check(valid_chars, "kode room hanya dari alphabet (iter %d)" % i)
		t.check(not code.contains("I") and not code.contains("O")
			and not code.contains("0") and not code.contains("1"),
			"tanpa I O 0 1 (iter %d)" % i)
		t.check(RoomCode.is_valid(code), "is_valid menerima kode sah (iter %d)" % i)
	t.check(not RoomCode.is_valid("ABC12"), "is_valid menolak panjang salah")
	t.check(not RoomCode.is_valid("ABCDI1"), "is_valid menolak I dan 1")
	t.check(RoomCode.is_valid("AAAAAA"), "is_valid menerima 6 huruf sah")
