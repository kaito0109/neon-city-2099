extends SceneTree
## Isolated kit portrait: load one kit GLB, apply the atlas materials
## exactly like city.gd does, light it with the dusk environment, and
## save a portrait. Usage: --script tests/v29_kitshot.gd -- tower_ent
var frames: int = 0
var _cam: Camera3D

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://shots")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var fname: String = args[0] if args.size() > 0 else "tower_ent"
	var heights: Dictionary = {"tower_ent": 22.0, "tower_kit": 17.0, "tower_mil": 32.0,
		"shop_a": 4.4, "shop_b": 4.4, "shop_c": 4.4}
	var h: float = float(heights.get(fname, 10.0))
	# Dusk-ish environment.
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.045, 0.055, 0.13)
	sky_mat.sky_horizon_color = Color(0.52, 0.27, 0.30)
	sky_mat.ground_bottom_color = Color(0.012, 0.010, 0.03)
	sky_mat.ground_horizon_color = Color(0.17, 0.11, 0.19)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.44, 0.39, 0.56)
	env.ambient_light_energy = 1.08
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.18
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 35, 0)
	sun.light_color = Color(1.0, 0.64, 0.44)
	sun.light_energy = 0.72
	root.add_child(sun)
	# Ground disc.
	var gnd := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(90, 90)
	gnd.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.05, 0.05, 0.08)
	gnd.material_override = gm
	root.add_child(gnd)
	# Kit + atlas materials (mirrors city._apply_kit_mats).
	var inst: Node3D = ModelLoader.load_model("res://assets/kits/" + fname + ".glb",
		"res://assets/kit_data/" + fname + ".tres")
	if inst == null:
		print("KIT LOAD FAILED ", fname)
		quit(1)
		return
	var atlas: Texture2D = TextureLoader.load_tex("res://assets/textures/kit_atlas.jpg",
		"res://assets/texture_data/kit_atlas.tres")
	var shade := StandardMaterial3D.new()
	shade.albedo_texture = atlas
	shade.roughness = 0.88
	var glow := StandardMaterial3D.new()
	glow.albedo_texture = atlas
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.05, 0.08)
	dark.roughness = 0.5
	dark.metallic = 0.5
	var plastic := StandardMaterial3D.new()
	plastic.albedo_color = Color(0.05, 0.62, 0.66)
	plastic.roughness = 0.35
	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = Color(0.99, 0.93, 0.04)
	yellow.roughness = 0.5
	var mats: Dictionary = {"KitShade": shade, "KitGlow": glow, "KitDark": dark,
		"KitPlastic": plastic, "KitYellow": yellow}
	_apply(inst, mats)
	root.add_child(inst)
	_cam = Camera3D.new()
	_cam.fov = 55.0
	var dist: float = h * 1.25 + 8.0
	_cam.position = Vector3(dist * 0.52, h * 0.52, dist * 0.85)
	root.add_child(_cam)
	_cam.look_at(Vector3(0, h * 0.44, 0), Vector3.UP)
	_cam.current = true
	inst.set_meta("fname", fname)

func _apply(n: Node, mats: Dictionary) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for i in range(mi.mesh.get_surface_count()):
				var m: Material = mi.mesh.surface_get_material(i)
				if m != null and mats.has(m.resource_name):
					mi.set_surface_override_material(i, mats[m.resource_name])
	for c in n.get_children():
		_apply(c, mats)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 16:
		var args: PackedStringArray = OS.get_cmdline_user_args()
		var fname: String = args[0] if args.size() > 0 else "tower_ent"
		var img: Image = root.get_texture().get_image()
		img.save_png("res://shots/v29_" + fname + ".png")
		print("saved v29 ", fname)
		quit(0)
		return true
	return false
