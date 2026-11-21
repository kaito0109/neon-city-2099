extends SceneTree
## Casino smoke probe: boot, enter through the facade door, walk the
## floor, leave again. Full game-flow checks live in casino_test.gd.
var frames: int = 0
var main: Node
var player: Node3D
var stage: int = 0
var stage_t: int = 0
var fails: int = 0
var casino_i: int = -1

func _ok(cond: bool, label: String) -> void:
	if cond:
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label)

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	frames += 1
	stage_t += 1
	if frames == 20 and stage == 0:
		main.call("start_game")
		player = main.get("player")
		stage = 1
		stage_t = 0
	elif stage == 1 and stage_t > 30:
		var sites: Array = main.get("city").get("shop_sites")
		_ok(sites.size() == 7, "7 sites (6 shops + casino)")
		for i in range(sites.size()):
			if String(sites[i]["kind"]) == "casino":
				casino_i = i
		_ok(casino_i >= 0, "casino site present")
		var s: Dictionary = sites[casino_i]
		var cz: Dictionary = s["casino"]
		_ok((cz["tables"] as Array).size() == 11, "11 casino tables registered")
		_ok((cz["roulette_wheels"] as Array).size() == 3, "3 roulette wheels placed")
		player.global_position = s["door_pos"]
		stage = 2
		stage_t = 0
	elif stage == 2 and stage_t > 10:
		main.call("interact")
		_ok(int(main.get("in_shop")) == casino_i, "entered casino via door")
		stage = 3
		stage_t = 0
	elif stage == 3 and stage_t > 10:
		var s2: Dictionary = (main.get("city").get("shop_sites"))[casino_i]
		player.global_position = s2["exit_pos"]
		stage = 4
		stage_t = 0
	elif stage == 4 and stage_t > 10:
		main.call("interact")
		_ok(int(main.get("in_shop")) == -1, "exited casino")
		print("CASINO_PROBE_DONE fails=", fails)
		quit(1 if fails > 0 else 0)
	return false
