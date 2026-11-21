extends SceneTree
## Casino photo PDCA (run under Xvfb): facade, interior tour with a
## free camera, then the cage / BJ / roulette / poker panels through
## the real player flow.
var frames: int = 0
var main: Node
var player: Node3D
var cam: Camera3D
var stage: int = 0
var stage_t: int = 0
var cui: Node
var C: Vector3

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	cam = Camera3D.new()
	cam.far = 500.0
	root.add_child(cam)

func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("res://shots/" + name)
	print("saved ", name)

func _sites() -> Array:
	return main.get("city").get("shop_sites")

func _casino_site() -> Dictionary:
	for s in _sites():
		if String(s["kind"]) == "casino":
			return s
	return {}

func _process(_delta: float) -> bool:
	frames += 1
	stage_t += 1
	if frames == 20 and stage == 0:
		main.call("start_game")
		player = main.get("player")
		cui = main.get("casino_ui")
		main.set("money", 100000)
		main.set("chips", 100000)
		C = _casino_site()["casino"]["center"]
		cam.make_current()
		stage = 1
		stage_t = 0
	elif stage == 1 and stage_t > 30:
		cam.global_position = Vector3(28, 3.0, 16)
		cam.look_at(Vector3(28, 4.2, 35.5), Vector3.UP)
		stage = 2
		stage_t = 0
	elif stage == 2 and stage_t > 10:
		_shot("casino_facade.png")
		player.global_position = _casino_site()["door_pos"]
		main.call("interact")
		stage = 3
		stage_t = 0
	elif stage == 3 and stage_t > 10:
		cam.global_position = C + Vector3(-38, 7.2, 26)
		cam.look_at(C + Vector3(6, 0, -6), Vector3.UP)
		stage = 4
		stage_t = 0
	elif stage == 4 and stage_t > 10:
		_shot("casino_overview.png")
		print("draw calls in frame: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		cam.global_position = C + Vector3(0, 2.1, 11)
		cam.look_at(C + Vector3(0, 1.7, 28), Vector3.UP)
		stage = 5
		stage_t = 0
	elif stage == 5 and stage_t > 10:
		_shot("casino_entrance.png")
		cam.global_position = C + Vector3(24, 1.9, 20.5)
		cam.look_at(C + Vector3(24, 1.3, 27.6), Vector3.UP)
		stage = 6
		stage_t = 0
	elif stage == 6 and stage_t > 10:
		_shot("casino_cage.png")
		cam.global_position = C + Vector3(-9, 3.4, 11)
		cam.look_at(C + Vector3(-5, 0.7, -5), Vector3.UP)
		stage = 7
		stage_t = 0
	elif stage == 7 and stage_t > 10:
		_shot("casino_pit.png")
		cam.global_position = C + Vector3(2.2, 2.1, -3.6)
		cam.look_at(C + Vector3(-0.95, 0.9, -8), Vector3.UP)
		stage = 8
		stage_t = 0
	elif stage == 8 and stage_t > 10:
		_shot("casino_roulette.png")
		cam.global_position = C + Vector3(-19, 2.3, -15.5)
		cam.look_at(C + Vector3(-28, 0.9, -21), Vector3.UP)
		stage = 9
		stage_t = 0
	elif stage == 9 and stage_t > 10:
		_shot("casino_pokerroom.png")
		cam.global_position = C + Vector3(23.5, 2.4, -13.5)
		cam.look_at(C + Vector3(34, 0.8, -21), Vector3.UP)
		stage = 10
		stage_t = 0
	elif stage == 10 and stage_t > 10:
		_shot("casino_vip.png")
		cam.global_position = C + Vector3(29, 2.3, 13)
		cam.look_at(C + Vector3(42.5, 1.1, 4), Vector3.UP)
		stage = 11
		stage_t = 0
	elif stage == 11 and stage_t > 10:
		_shot("casino_slots.png")
		# --- UI panels through the player camera ---
		player.call("make_camera_current")
		player.global_position = (_casino_site()["casino"]["cage_pos"] as Array)[1]
		main.call("interact")
		stage = 12
		stage_t = 0
	elif stage == 12 and stage_t > 12:
		_shot("casino_ui_cage.png")
		cui.call("_close_panel")
		var tables: Array = _casino_site()["casino"]["tables"]
		for t in tables:
			if String(t["kind"]) == "bj" and not bool(t["vip"]):
				player.global_position = t["seat_pos"]
				break
		main.call("interact")
		stage = 13
		stage_t = 0
	elif stage == 13 and stage_t > 12:
		cui.call("_bj_deal")
		stage = 14
		stage_t = 0
	elif stage == 14 and stage_t > 30:
		_shot("casino_ui_bj.png")
		cui.call("_unseat")
		var tables2: Array = _casino_site()["casino"]["tables"]
		for t in tables2:
			if String(t["kind"]) == "roulette" and not bool(t["vip"]):
				player.global_position = t["seat_pos"]
				break
		main.call("interact")
		stage = 15
		stage_t = 0
	elif stage == 15 and stage_t > 12:
		_shot("casino_ui_roulette.png")
		cui.call("_unseat")
		var tables3: Array = _casino_site()["casino"]["tables"]
		for t in tables3:
			if String(t["kind"]) == "poker":
				player.global_position = t["seat_pos"]
				break
		main.call("interact")
		stage = 16
		stage_t = 0
	elif stage == 16 and stage_t > 40:
		_shot("casino_ui_poker.png")
		print("CASINO_SHOTS_DONE")
		quit(0)
	return false
