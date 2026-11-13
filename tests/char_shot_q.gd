extends SceneTree
var frames: int = 0
var cam: Camera3D
var aps: Array = []
func _initialize() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.75)
	env.ambient_light_energy = 0.9
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.2
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.12, 0.12, 0.16)
	ground.material_override = gm
	root.add_child(ground)
	cam = Camera3D.new()
	cam.position = Vector3(0, 1.25, 4.6)
	root.add_child(cam)
	cam.look_at(Vector3(0, 0.85, 0), Vector3.UP)
	var names: Array = ["Punk", "Casual", "Suit", "WomanCasual"]
	var anims: Array = ["Idle", "Walk", "Run", "Idle"]
	for i in range(4):
		var ps: PackedScene = load("res://assets/people_q/" + names[i] + ".glb")
		var inst: Node3D = ps.instantiate()
		inst.scale = Vector3.ONE
		inst.position = Vector3(-2.7 + i * 1.8, 0, 0)
		root.add_child(inst)
		var ap: AnimationPlayer = _find_ap(inst)
		if ap:
			ap.play(anims[i])
			aps.append(ap)
		print(names[i], " ap=", ap != null)
func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer: return n
	for c in n.get_children():
		var r = _find_ap(c)
		if r: return r
	return null
func _process(_d: float) -> bool:
	frames += 1
	if frames == 45:
		root.get_texture().get_image().save_png("res://shots/chars_q.png")
		print("saved chars_q")
		quit(0)
		return true
	return false
