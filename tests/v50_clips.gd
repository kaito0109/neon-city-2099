extends SceneTree
## Render the Punk clips at several positions each and save a contact
## sheet row per clip, to identify which clip contains the broken
## poses from his photos (kneel-lunge / paddle feet / scissor float).
var frames: int = 0
var inst: Node3D
var ap: AnimationPlayer
var cam: Camera3D
var jobs: Array = []
var job_i: int = -1
var wait: int = 0

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	var w := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.35, 0.42, 0.48)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.95, 1.0)
	env.ambient_light_energy = 1.2
	w.environment = env
	root.add_child(w)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 35, 0)
	sun.light_energy = 1.2
	root.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.4, 0.44, 0.48)
	floor_mi.material_override = fm
	root.add_child(floor_mi)
	inst = People.spawn("Punk")
	root.add_child(inst)
	ap = People.find_ap(inst)
	cam = Camera3D.new()
	cam.far = 100.0
	root.add_child(cam)
	cam.global_position = Vector3(1.7, 1.2, 2.4)
	cam.look_at(Vector3(0, 0.85, 0), Vector3.UP)
	cam.make_current()
	for c in ap.get_animation_list():
		var a: Animation = ap.get_animation(c)
		var short: String = c.get_slice("|", 1) if c.contains("|") else c
		for frac in [0.15, 0.35, 0.55, 0.8]:
			jobs.append([c, short, frac, a.length * frac])

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 10:
		return false
	if wait > 0:
		wait -= 1
		if wait == 0 and job_i >= 0 and job_i < jobs.size():
			var j2: Array = jobs[job_i]
			root.get_texture().get_image().save_png("res://shots/clip_%s_%d.png" % [j2[1], int(j2[2] * 100)])
		return false
	job_i += 1
	if job_i >= jobs.size():
		print("CLIPS DONE")
		quit()
		return true
	var j: Array = jobs[job_i]
	ap.play(j[0])
	ap.seek(j[3], true)
	ap.speed_scale = 0.0
	wait = 3
	return false
