extends SceneTree
## Triplanar + uv1_scale sanity check under this VM's software GL:
## v1-era notes say uv1_scale != 1 corrupts sampling (black/magenta).
## Verify before choosing the ground-texturing route.
var frames: int = 0
var _cam: Camera3D

func _initialize() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.35, 0.42, 0.46)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.58, 0.62)
	env.ambient_light_energy = 1.0
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 0.6
	root.add_child(sun)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/textures/asphalt_color.jpg")
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/textures/asphalt_normal.jpg")
	mat.roughness_texture = load("res://assets/textures/asphalt_rough.jpg")
	mat.texture_repeat = true
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	ground.mesh = pm
	ground.material_override = mat
	root.add_child(ground)
	var slope := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(10, 6, 0.5)
	slope.mesh = bm
	slope.material_override = mat
	slope.position = Vector3(-6, 2.5, -10)
	slope.rotation_degrees = Vector3(-32, 20, 0)
	root.add_child(slope)
	_cam = Camera3D.new()
	_cam.global_position = Vector3(0, 7, 13)
	root.add_child(_cam)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		_cam.look_at(Vector3(0, 0.5, -4), Vector3.UP)
		_cam.make_current()
	elif frames == 14:
		var img: Image = root.get_texture().get_image()
		img.save_png("res://shots/tri_test.png")
		print("saved tri_test.png")
		return true
	return false
