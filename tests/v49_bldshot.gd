extends SceneTree
## v5 buildings PDCA (free camera): (a) forms row wide,
## (b) slope/twin three-quarter close, (c) podium close-up.
var frames: int = 0
var main: Node
var cam: Camera3D
var _stage: int = 0

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	cam = Camera3D.new()
	cam.far = 900.0
	root.add_child(cam)

func _save(name: String) -> void:
	root.get_texture().get_image().save_png("res://shots/" + name)
	print("saved ", name, " draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))

func _place(city: Node, bname: String, pos: Vector3) -> void:
	var inst: Node3D = ModelLoader.load_model(
		"res://assets/bld/" + bname + ".glb",
		"res://assets/bld_data/" + bname + ".tres")
	city.call("_apply_bld_mats", inst)
	inst.position = pos
	main.add_child(inst)

func _process(_delta: float) -> bool:
	frames += 1
	var city: Node = main.get("city")
	if frames == 5:
		main.call("start_game")
	elif frames == 14:
		_place(city, "ent_high_c", Vector3(-46, 0.06, -6))
		_place(city, "mil_high_c", Vector3(-23, 0.06, -6))
		_place(city, "ent_tower_c", Vector3(0, 0.06, -6))
		_place(city, "mil_mid_c", Vector3(23, 0.06, -6))
		_place(city, "kit_tower_b", Vector3(46, 0.06, -6))
		_place(city, "ent_mid_c", Vector3(30, 0.06, 20))
		cam.make_current()
		cam.global_position = Vector3(0, 10, 42)
		cam.look_at(Vector3(0, 13, -6), Vector3.UP)
		_stage = 1
	elif frames == 42 and _stage == 1:
		_save("v49_a_forms.png")
		cam.global_position = Vector3(-33, 7, 24)
		cam.look_at(Vector3(-36, 17, -6), Vector3.UP)
		_stage = 2
	elif frames == 62 and _stage == 2:
		_save("v49_b_close.png")
		cam.global_position = Vector3(39, 1.8, 32)
		cam.look_at(Vector3(28.5, 2.4, 20), Vector3.UP)
		_stage = 3
	elif frames == 82 and _stage == 3:
		_save("v49_c_podium.png")
		quit(0)
		return true
	return false
