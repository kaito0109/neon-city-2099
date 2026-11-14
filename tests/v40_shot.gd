extends SceneTree
## v4 visual check: top-down (compare with design/v4_map.png), the
## spawn view toward the megabuilding, the canal/market street, and
## the hill avenue. Also prints the frame draw-call count (the v4
## optimization budget is ~350 in street view).
var frames: int = 0
var main: Node
var _stage: int = 0
var _cam: Camera3D

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	_cam = Camera3D.new()
	_cam.far = 3000.0
	root.add_child(_cam)

func _save(name: String) -> void:
	var img: Image = root.get_texture().get_image()
	img.save_png("res://shots/" + name)
	print("saved ", name, " draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))

func _process(_delta: float) -> bool:
	frames += 1
	var player: Node3D = main.get("player")
	if frames == 5:
		main.call("start_game")
	elif frames == 40:
		# Fog would white-out a 560 m top view (e^-3.8); disable it
		# for this verification shot only.
		for ch in main.get_children():
			if ch is WorldEnvironment:
				(ch as WorldEnvironment).environment.fog_enabled = false
		_cam.global_position = Vector3(0, 560, 0.01)
		_cam.look_at(Vector3.ZERO, Vector3(0, 0, -1))
		_cam.make_current()
		_stage = 1
	elif frames == 55 and _stage == 1:
		_save("v40_a_top.png")
		for ch in main.get_children():
			if ch is WorldEnvironment:
				(ch as WorldEnvironment).environment.fog_enabled = true
		player.global_position = Vector3(0, 0.6, 48)
		player.set("yaw", 0.0)
		player.set("pitch", -0.10)
		player.call("make_camera_current")
		_stage = 2
	elif frames == 75 and _stage == 2:
		_save("v40_b_spawn.png")
		player.global_position = Vector3(-30, 0.6, 118)
		player.set("yaw", PI - 0.35)
		player.set("pitch", -0.12)
		_stage = 3
	elif frames == 95 and _stage == 3:
		_save("v40_c_canal.png")
		player.global_position = Vector3(58, 1.2, -52)
		player.set("yaw", -0.85)
		player.set("pitch", -0.14)
		_stage = 4
	elif frames == 115 and _stage == 4:
		_save("v40_d_hills.png")
		player.global_position = Vector3(190, 19.5, -198)
		player.set("yaw", 2.36)
		player.set("pitch", -0.06)
		_stage = 5
	elif frames == 135 and _stage == 5:
		_save("v40_e_hilltop.png")
		quit(0)
	return false
