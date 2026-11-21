extends SceneTree
## v5.4: shops (enter / buy / use / exit), new jobs wiring, and the
## pedestrian bridge climb.
var frames: int = 0
var main: Node
var player: Node3D
var stage: int = 0
var stage_t: int = 0
var fails: int = 0
var max_y: float = -99.0
var pharm: int = -1

func _ok(cond: bool, label: String) -> void:
	if cond:
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label)

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _sites() -> Array:
	return main.get("city").get("shop_sites")

func _process(_delta: float) -> bool:
	frames += 1
	stage_t += 1
	if frames == 20 and stage == 0:
		main.call("start_game")
		player = main.get("player")
		stage = 1
		stage_t = 0
	elif stage == 1 and stage_t > 30:
		var sites: Array = _sites()
		_ok(sites.size() == 7, "6 shops + casino built")
		for i in range(sites.size()):
			if String(sites[i]["kind"]) == "pharmacy":
				pharm = i
		_ok(pharm >= 0, "pharmacy exists")
		# enter the pharmacy
		player.global_position = sites[pharm]["door_pos"]
		main.call("interact")
		_ok(int(main.get("in_shop")) == pharm, "entered pharmacy")
		_ok(player.global_position.y < -30.0, "player is in the interior (y=%.1f)" % player.global_position.y)
		stage = 2
		stage_t = 0
	elif stage == 2 and stage_t > 10:
		var s: Dictionary = _sites()[pharm]
		var money0: int = int(main.get("money"))
		player.global_position = s["buys"][0]["pos"]
		main.call("interact")
		_ok(int((main.get("items") as Dictionary).get("medkit", 0)) == 1, "bought a medkit")
		_ok(int(main.get("money")) == money0 - 80, "paid €$80 (money=%d)" % int(main.get("money")))
		# exit
		player.global_position = s["exit_pos"]
		main.call("interact")
		_ok(int(main.get("in_shop")) == -1, "exited the shop")
		_ok(player.global_position.y > -2.0, "back on the street (y=%.1f)" % player.global_position.y)
		# use the medkit at low HP
		player.set("hp", 40.0)
		main.call("use_item")
		_ok(float(player.get("hp")) == 100.0, "medkit healed to 100 (hp=%.0f)" % float(player.get("hp")))
		_ok(int((main.get("items") as Dictionary).get("medkit", 0)) == 0, "medkit consumed")
		stage = 3
		stage_t = 0
	elif stage == 3 and stage_t > 10:
		# errand wiring: holding a medkit flips get -> deliver
		main.set("mission", "errand")
		main.set("mission_stage", "get")
		main.set("_shop_target", pharm)
		main.set("mission_target_pos", Vector3.ZERO)
		stage = 4
		stage_t = 0
	elif stage == 4 and stage_t > 5:
		_ok(String(main.get("mission_stage")) == "get", "errand waits without a medkit")
		(main.get("items") as Dictionary)["medkit"] = 1
		stage = 5
		stage_t = 0
	elif stage == 5 and stage_t > 5:
		_ok(String(main.get("mission_stage")) == "deliver", "errand flips to deliver with a medkit")
		main.set("mission", "")
		main.set("mission_stage", "")
		main.set("mission_target_pos", null)
		# footbridge: walk north -> south across the canal
		player.global_position = Vector3(-60, 0.6, 146)
		player.set("yaw", PI)
		player.set("_yaw_t", PI)
		player.set("touch_move", Vector2(0, -1))
		max_y = -99.0
		stage = 6
		stage_t = 0
	elif stage == 6:
		max_y = maxf(max_y, player.global_position.y)
		if player.global_position.z > 197.0 or stage_t > 2400:
			player.set("touch_move", Vector2.ZERO)
			_ok(player.global_position.z > 197.0, "crossed the footbridge (z=%.1f)" % player.global_position.z)
			_ok(max_y > 2.8, "climbed the stairs (max y=%.2f)" % max_y)
			print("V54 DONE fails=", fails)
			quit()
			return true
	return false
