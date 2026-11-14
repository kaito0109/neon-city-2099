extends SceneTree
## Phase 2 visual check: (a) a portrait row of the three styles on
## the plaza (UV tiling / silhouette / details), (b) the hill avenue
## lined with new buildings, (c) the spawn view (hero_mega).
var frames: int = 0
var main: Node
var _stage: int = 0

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _save(name: String) -> void:
	root.get_texture().get_image().save_png("res://shots/" + name)
	print("saved ", name, " draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))

func _process(_delta: float) -> bool:
	frames += 1
	var player: Node3D = main.get("player")
	var city: Node = main.get("city")
	if frames == 5:
		main.call("start_game")
	elif frames == 12:
		var row: Array = [["ent_mid_a", -21.0], ["kit_mid_a", 0.0], ["mil_high_a", 22.0]]
		for item in row:
			var inst: Node3D = ModelLoader.load_model(
				"res://assets/bld/" + item[0] + ".glb",
				"res://assets/bld_data/" + item[0] + ".tres")
			city.call("_apply_bld_mats", inst)
			inst.position = Vector3(item[1], 0.06, -2.0)
			main.add_child(inst)
		player.global_position = Vector3(0, 0.6, 30)
		player.set("yaw", 0.0)
		player.set("pitch", -0.06)
		_stage = 1
	elif frames == 34 and _stage == 1:
		_save("v41_a_row.png")
		player.global_position = Vector3(24, 1.0, -22)
		player.set("yaw", -0.89)
		player.set("pitch", -0.10)
		_stage = 2
	elif frames == 54 and _stage == 2:
		_save("v41_b_avenue.png")
		player.global_position = Vector3(0, 0.6, 48)
		player.set("yaw", 0.0)
		player.set("pitch", -0.10)
		_stage = 3
	elif frames == 74 and _stage == 3:
		_save("v41_c_spawn.png")
		quit(0)
	return false
