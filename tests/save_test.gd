extends SceneTree
## Local save (v6.1): round-trip through the real user:// file,
## corrupt / foreign-version saves fall back to a fresh start,
## and the _process change-flush persists casino-style set()
## mutations with no explicit save call. The save file is deleted
## before and after so other suites keep their fresh-start
## assumption (casino_test expects chips == 0 at the cage).

const SAVE_PATH := "user://neon_save.json"

var frames: int = 0
var stage_t: int = 0
var main: Node
var fails: int = 0
var stage: int = 0

func _ok(cond: bool, label: String) -> void:
	if cond:
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label)

func _delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var da := DirAccess.open("user://")
		if da != null:
			da.remove("neon_save.json")

func _write_save(text: String) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()

func _initialize() -> void:
	_delete_save()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	frames += 1
	stage_t += 1
	if stage == 0 and frames >= 5:
		# Fresh start: no save file existed at boot.
		_ok(int(main.get("money")) == 150, "fresh start money=150")
		_ok(int(main.get("chips")) == 0, "fresh start chips=0")
		_ok(int((main.get("casino_stats") as Dictionary).get("total_bet", -1)) == 0, "fresh start total_bet=0")
		# Write known values, then save explicitly.
		main.set("money", 12345)
		main.set("chips", 678)
		main.set("casino_stats", {"total_bet": 500050, "total_returned": 2500})
		main.set("items", {"medkit": 3, "drink": 1})
		main.call("save_game")
		_ok(FileAccess.file_exists(SAVE_PATH), "save file written")
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		_ok(parsed is Dictionary, "save file is a JSON object")
		if parsed is Dictionary:
			var d: Dictionary = parsed
			_ok(int(d.get("version", 0)) == 1, "save carries version 1")
			_ok(int(d.get("money", 0)) == 12345, "file money=12345")
			_ok(int(d.get("chips", 0)) == 678, "file chips=678")
		stage = 1
	elif stage == 1:
		# Reset everything to defaults, then load: all values
		# must come back from the file.
		main.set("money", 150)
		main.set("chips", 0)
		main.set("casino_stats", {"total_bet": 0, "total_returned": 0})
		main.set("items", {})
		main.call("load_game")
		_ok(int(main.get("money")) == 12345, "loaded money=12345")
		_ok(int(main.get("chips")) == 678, "loaded chips=678")
		var st: Dictionary = main.get("casino_stats")
		_ok(int(st.get("total_bet", 0)) == 500050 and int(st.get("total_returned", 0)) == 2500, "loaded casino_stats")
		var it: Dictionary = main.get("items")
		_ok(int(it.get("medkit", 0)) == 3 and int(it.get("drink", 0)) == 1, "loaded items")
		stage = 2
	elif stage == 2:
		# Auto-flush: mutate exactly like the casino UI does
		# (plain set(), no save call) and let _process persist it.
		main.set("money", 777)
		main.set("chips", 555)
		stage = 3
		stage_t = 0
	elif stage == 3 and stage_t >= 5:
		var parsed2: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		_ok(parsed2 is Dictionary and int((parsed2 as Dictionary).get("money", 0)) == 777, "auto-flush persisted money=777")
		_ok(parsed2 is Dictionary and int((parsed2 as Dictionary).get("chips", 0)) == 555, "auto-flush persisted chips=555")
		stage = 4
	elif stage == 4:
		# Corrupt file: load must not crash and must keep the
		# current (default) values.
		_write_save("{{{ this is not json")
		main.set("money", 150)
		main.set("chips", 0)
		main.call("load_game")
		_ok(int(main.get("money")) == 150, "corrupt save ignored (money stays 150)")
		_ok(int(main.get("chips")) == 0, "corrupt save ignored (chips stays 0)")
		# Foreign version: also ignored.
		_write_save(JSON.stringify({"version": 99, "money": 999999, "chips": 999999}))
		main.call("load_game")
		_ok(int(main.get("money")) == 150, "foreign-version save ignored")
		# Wrong top-level type: also ignored.
		_write_save("[1, 2, 3]")
		main.call("load_game")
		_ok(int(main.get("money")) == 150, "non-dict save ignored")
		_delete_save()
		_ok(not FileAccess.file_exists(SAVE_PATH), "save cleaned up for other suites")
		print("SAVE_TEST_DONE fails=", fails)
		quit(1 if fails > 0 else 0)
	return false
