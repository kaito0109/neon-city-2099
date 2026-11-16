extends SceneTree
## v5.5 lineup check: every cleaned Sketchfab model in a row, so
## orientation / scale / materials can be eyeballed in one shot.
var frames: int = 0
var cam: Camera3D

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.13, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.58, 0.66)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.1
	root.add_child(sun)
	var gnd := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 120)
	gnd.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.16, 0.17, 0.19)
	gnd.material_override = gm
	gnd.position = Vector3(0, -0.02, 0)
	root.add_child(gnd)
	var defs: Array = [
		["revolving_tower", -95.0, -18.0], ["sky_t_021", -48.0, -14.0],
		["bg_apartment", -12.0, -12.0], ["iqinso_hotel", 26.0, -16.0],
		["milk_peach", 52.0, -8.0],
		["hovercar", -52.0, 16.0], ["scifi_car", -38.0, 16.0],
		["cyberpunk_car", -24.0, 16.0], ["flying_car2", -8.0, 16.0],
		["noodle_vending", 8.0, 14.0], ["vending", 14.0, 14.0],
	]
	for d in defs:
		var inst: Node3D = ModelLoader.load_model(
			"res://assets/skf/" + String(d[0]) + ".glb",
			"res://assets/skf_data/" + String(d[0]) + ".tres")
		if inst == null:
			print("LOAD FAIL ", d[0])
			continue
		inst.position = Vector3(float(d[1]), 0.0, float(d[2]))
		root.add_child(inst)
		print("placed ", d[0])
	cam = Camera3D.new()
	cam.far = 600.0
	root.add_child(cam)
	cam.global_position = Vector3(-30, 26, 78)
	cam.look_at(Vector3(-16, 10, -8), Vector3.UP)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 40:
		root.get_texture().get_image().save_png("res://shots/v55_lineup1.png")
		cam.global_position = Vector3(-38, 3.2, 34)
		cam.look_at(Vector3(-34, 1.2, 14), Vector3.UP)
	if frames == 60:
		root.get_texture().get_image().save_png("res://shots/v55_lineup2.png")
		print("LINEUP DONE")
		quit()
		return true
	return false
