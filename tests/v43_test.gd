extends SceneTree
## Phase 2.5 checks: atmosphere systems exist — wet streaks,
## street lamps, steam vents, gantry sign bridges.
var frames: int = 0
var main: Node
var fails: int = 0

func _ok(cond: bool, label: String) -> void:
	if cond:
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label)

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 15:
		var city: Node = main.get("city")
		_ok(int(city.get("streak_count_v4")) >= 100, "wet streaks (%d)" % int(city.get("streak_count_v4")))
		_ok(int(city.get("lamp_count")) >= 80, "street lamps (%d)" % int(city.get("lamp_count")))
		_ok(int(city.get("steam_count_v4")) >= 20, "steam vents (%d)" % int(city.get("steam_count_v4")))
		_ok(int(city.get("gantry_count")) >= 4, "gantry sign bridges (%d)" % int(city.get("gantry_count")))
		_ok(city.get_node_or_null("WetStreaksV4") != null, "streak multimesh node")
		_ok(city.get_node_or_null("LampPools") != null, "lamp pool multimesh node")
		print("TEST DONE failed=", fails > 0)
		quit(0 if fails == 0 else 1)
	return false
