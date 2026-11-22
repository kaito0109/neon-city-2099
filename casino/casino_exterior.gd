extends Node3D
## A self-contained, instanced landmark. Coordinates: entrance at local
## (0,0,0), north-facing street, resort extending 36 m south behind it.
## Opaque glass + batched trims keep this compatible with Web/iOS GL.
const FOOTPRINT := Rect2(8.0, 33.0, 40.0, 40.0)
var _font: Font
var _batches: Dictionary = {}
var _materials: Dictionary = {}
var _doors: Array[MeshInstance3D] = []
var _open: float = 0.0
var _player: Node3D
var _unit := BoxMesh.new()
var _door_glass: Material

static func occupies_plot(plot: Dictionary) -> bool:
	var angle: float = float(plot["rot"])
	var w: float = float(plot["w"]) * 0.5
	var d: float = float(plot["d"]) * 0.5
	var extent := Vector2(absf(cos(angle)) * w + absf(sin(angle)) * d,
		absf(sin(angle)) * w + absf(cos(angle)) * d)
	return FOOTPRINT.intersects(Rect2(Vector2(float(plot["x"]), float(plot["z"])) - extent, extent * 2.0))

func _material(key: String, color: Color, metallic: float = 0.0, roughness: float = 0.6, glow: float = 0.0) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	# A restrained base contribution keeps the silhouette readable under
	# the existing dark city grade without adding dozens of point lights.
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = glow if glow > 0.0 else 0.07
	_materials[key] = mat

func build(font: Font) -> void:
	name = "CasinoLandmark"
	_font = font if font != null else ThemeDB.fallback_font
	_unit.size = Vector3.ONE
	_material("stone", Color(0.19, 0.20, 0.23), 0.25, 0.68)
	_material("gold", Color(0.66, 0.43, 0.18), 0.8, 0.3)
	_material("dark", Color(0.025, 0.035, 0.05), 0.4, 0.5)
	_material("glass", Color(0.055, 0.14, 0.19), 0.65, 0.16)
	_material("warm", Color(1.0, 0.65, 0.28), 0.25, 0.4, 0.7)
	_material("cyan", Color(0.12, 0.68, 0.76), 0.15, 0.5, 0.8)
	_material("pink", Color(0.62, 0.11, 0.32), 0.2, 0.5, 0.7)
	_material("paving", Color(0.19, 0.21, 0.24), 0.35, 0.3)
	_material("wet", Color(0.06, 0.09, 0.12), 0.7, 0.09)
	_material("leaf", Color(0.07, 0.19, 0.14), 0.0, 0.85)
	_material("rust", Color(0.23, 0.15, 0.12), 0.4, 0.8)
	var windows := ShaderMaterial.new()
	windows.shader = preload("res://casino/hotel_windows.gdshader")
	_materials["windows"] = windows
	# Reuse the shipped ModelBlob concrete maps; no new binary assets.
	var stone: StandardMaterial3D = _materials["stone"]
	stone.albedo_texture = TextureLoader.load_tex("res://assets/textures/concrete_color.jpg", "res://assets/texture_data/concrete_color.tres")
	stone.normal_texture = TextureLoader.load_tex("res://assets/textures/concrete_normal.jpg", "res://assets/texture_data/concrete_normal.tres")
	stone.normal_enabled = stone.normal_texture != null
	stone.normal_scale = 0.45
	stone.uv1_triplanar = true
	stone.uv1_world_triplanar = true
	stone.uv1_scale = Vector3(0.35, 0.35, 0.35)
	stone.albedo_color = Color(0.55, 0.55, 0.58)
	stone.emission_energy_multiplier = 0.12
	var door_material := StandardMaterial3D.new()
	door_material.albedo_color = Color(0.12, 0.25, 0.29, 0.6)
	door_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	door_material.roughness = 0.15
	door_material.metallic = 0.3
	_door_glass = door_material
	_podium()
	_towers()
	_forecourt()
	_street_details()
	_street_life()
	_flush_batches()

func _box(key: String, size: Vector3, pos: Vector3, yaw: float = 0.0, solid: bool = false) -> void:
	if not _batches.has(key):
		_batches[key] = []
	var transform := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), pos)
	(_batches[key] as Array).append(transform)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.position = pos
		body.rotation.y = yaw
		body.add_child(shape)
		add_child(body)

func _flush_batches() -> void:
	for key in _batches:
		var transforms: Array = _batches[key]
		var mesh := MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_3D
		mesh.mesh = _unit
		mesh.instance_count = transforms.size()
		for i in range(transforms.size()):
			mesh.set_instance_transform(i, transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.name = "Landmark_" + String(key)
		instance.multimesh = mesh
		instance.material_override = _materials[key]
		instance.visibility_range_end = 280.0 if key in ["windows", "gold", "warm", "stone"] else 120.0
		add_child(instance)

func _sign(text: String, pos: Vector3, size: int, color: Color, yaw: float = PI) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = _font
	label.font_size = size
	label.pixel_size = 0.009
	label.outline_size = 2
	label.modulate = color
	label.position = pos
	label.rotation.y = yaw
	label.no_depth_test = false
	label.visibility_range_end = 200.0
	add_child(label)
	return label

func _podium() -> void:
	# Real depth and a clear, walkable central vestibule. Walls occupy
	# the wings/rear, never the ACT point or the 5 m entrance aisle.
	_box("stone", Vector3(15, 10, 36), Vector3(-11, 5, 18), 0, true)
	_box("stone", Vector3(15, 10, 36), Vector3(11, 5, 18), 0, true)
	_box("stone", Vector3(7, 10, 27), Vector3(0, 5, 22.5), 0, true)
	_box("dark", Vector3(7, 0.35, 8), Vector3(0, 4.8, 4), 0, true)
	_box("paving", Vector3(7, 0.12, 8), Vector3(0, 0.02, 4))
	_box("gold", Vector3(6.8, 3.5, 0.08), Vector3(0, 2.3, 8.5))
	_box("dark", Vector3(5.7, 2.7, 0.1), Vector3(0, 2.3, 8.4))
	_sign("WELCOME TO\nNEON PEARL", Vector3(0, 2.5, 8.25), 42, Color(1, 0.82, 0.56))
	for x in [-2.7, 2.7]:
		_box("warm", Vector3(0.08, 3.0, 0.12), Vector3(x, 2.0, 8.1))
	for side in [-1.0, 1.0]:
		_box("glass", Vector3(14.8, 6.0, 0.12), Vector3(side * 11, 4, -0.06))
		for x in range(5):
			_box("gold", Vector3(0.16, 9.7, 0.3), Vector3(side * (4.1 + x * 3.4), 4.9, -0.2))
		for z in range(1, 12):
			_box("glass", Vector3(0.12, 6.1, 2.5), Vector3(side * 18.56, 4, z * 3.0))
		_box("warm", Vector3(0.12, 0.16, 36), Vector3(side * 18.65, 9.4, 18))
	# The low trim must stop at the entrance, not look like a barrier.
	for side in [-1.0, 1.0]:
		_box("gold", Vector3(15, 0.3, 0.5), Vector3(side * 11.2, 1.0, -0.2))
	for y in [7.4, 9.6]:
		_box("gold", Vector3(37.6, 0.3, 0.5), Vector3(0, y, -0.2))
	# Floating porte-cochere with warm underside slats.
	_box("dark", Vector3(26, 0.7, 6.5), Vector3(0, 5.5, -1.8))
	_box("gold", Vector3(26.2, 0.18, 6.7), Vector3(0, 5.95, -1.8))
	_box("warm", Vector3(25.6, 0.10, 0.12), Vector3(0, 5.15, -5.0))
	for i in range(19):
		_box("gold", Vector3(0.13, 0.22, 6), Vector3(-12.1 + i * 1.35, 5.0, -1.8))
	for x in [-11.5, 11.5]:
		_box("gold", Vector3(0.45, 5.2, 0.45), Vector3(x, 2.6, -4.0), 0, true)
	_sign("CASINO  NEON PEARL", Vector3(0, 8.5, -0.5), 128, Color(1, 0.75, 0.38))
	_sign("HOTEL  /  CASINO  /  NEON CIRCLE", Vector3(0, 6.65, -0.5), 37, Color(0.65, 0.85, 0.9))
	_sign("CASINO ENTRANCE", Vector3(0, 4.35, -0.3), 34, Color(0.55, 0.95, 1.0))
	for x in [-3.2, 3.2]:
		_box("gold", Vector3(0.22, 4.1, 0.4), Vector3(x, 2.05, 0.1))
		_box("warm", Vector3(0.08, 3.8, 0.12), Vector3(x, 2.05, -0.15))
	# Sliding leaves are decorative; the existing ACT entry contract stays
	# reachable from outside even before the doors finish opening.
	for side in [-1.0, 1.0]:
		var door := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.9, 3.9, 0.16)
		door.mesh = mesh
		door.material_override = _door_glass
		door.position = Vector3(side * 1.5, 2.0, 0.1)
		door.name = "DoorLeft" if side < 0 else "DoorRight"
		add_child(door)
		_doors.append(door)
		for y in [0.25, 3.6]:
			var rail := MeshInstance3D.new()
			rail.mesh = _unit
			rail.material_override = _materials["gold"]
			rail.scale = Vector3(2.9, 0.08, 0.22)
			rail.position = Vector3(0, y - 2.0, -0.05)
			door.add_child(rail)
		var handle := MeshInstance3D.new()
		handle.mesh = _unit
		handle.material_override = _materials["warm"]
		handle.scale = Vector3(0.045, 0.8, 0.12)
		handle.position = Vector3(-side * 1.3, 0, -0.1)
		door.add_child(handle)

func _towers() -> void:
	for side in [-1.0, 1.0]:
		var floors: int = 20 if side < 0 else 18
		for floor_i in range(floors):
			var t: float = float(floor_i) / float(floors)
			var x: float = side * (10.0 + sin(t * PI) * 1.0)
			var z: float = 20.0 + sin(t * PI * 0.8) * 2.0
			var width: float = 13.5 - t * 3.0
			var depth: float = 23.0 - t * 4.0
			var yaw: float = side * t * 0.15
			_box("windows", Vector3(width, 2.95, depth), Vector3(x, 11.5 + floor_i * 3.0, z), yaw)
			_box("gold", Vector3(width + 0.3, 0.14, depth + 0.3), Vector3(x, 10.0 + floor_i * 3.0, z), yaw)
			if floor_i % 4 == 0:
				_box("warm", Vector3(width + 0.34, 0.07, depth + 0.34), Vector3(x, 10.18 + floor_i * 3.0, z), yaw)
		# Simplified solid tower volumes above the publicly reachable podium.
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(14.5, floors * 3.0, 24)
		shape.shape = box
		body.position = Vector3(side * 10, 10 + floors * 1.5, 21)
		body.add_child(shape)
		add_child(body)
	_box("glass", Vector3(20, 4.0, 7), Vector3(0, 60, 20))
	_box("gold", Vector3(22, 0.35, 8), Vector3(0, 62.1, 20))
	# A vertical gold halo is readable from the street and across the city.
	var halo := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 16.8
	ring.outer_radius = 17.4
	ring.rings = 48
	ring.ring_segments = 8
	halo.mesh = ring
	halo.material_override = _materials["warm"]
	halo.position = Vector3(0, 73, 21)
	halo.rotation.x = PI * 0.5
	halo.name = "PearlHalo"
	add_child(halo)
	_sign("NEON\nPEARL", Vector3(0, 75, 20.5), 190, Color(1, 0.8, 0.45))
	# Mechanical plant and ventilation at the back of the roof.
	for x in [-12.0, -8.0, 8.0, 12.0]:
		_box("dark", Vector3(2.8, 1.8, 3.2), Vector3(x, 10.8, 32))
		for z in range(5):
			_box("gold", Vector3(2.9, 0.07, 0.14), Vector3(x, 11.8, 30.7 + z * 0.55))

func _forecourt() -> void:
	# Use the existing plaza surface as the single ground layer.
	for x in [-3.8, 3.8]:
		_box("stone", Vector3(0.23, 0.15, 8.4), Vector3(x, 0.13, -5))
	for x in [-8.0, 8.0]:
		var z: float = -5.0 if x > 0 else -7.0 # leave the clinic's rear corner clear
		_box("stone", Vector3(3.4, 0.7, 1.5), Vector3(x, 0.35, z), 0, true)
		_box("leaf", Vector3(3.0, 0.6, 1.1), Vector3(x, 0.9, z))
		_box("gold", Vector3(3.5, 0.12, 1.6), Vector3(x, 0.72, z))
	for x in [-4.4, 4.4]:
		for z in [-3.0, -6.0]:
			_box("dark", Vector3(0.2, 0.85, 0.2), Vector3(x, 0.425, z), 0, true)
			_box("warm", Vector3(0.22, 0.15, 0.22), Vector3(x, 0.85, z))
	for x in [-6.0, 6.0]:
		var light := OmniLight3D.new()
		light.position = Vector3(x, 4.7, -2)
		light.light_color = Color(1, 0.66, 0.3)
		light.light_energy = 1.5
		light.omni_range = 8
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = 30
		light.distance_fade_length = 12
		add_child(light)

func _street_details() -> void:
	# Human-scale service strip west of the doors, away from the main
	# north/south carriageway and the clinic at world (38,22).
	_box("dark", Vector3(2.4, 3.0, 0.45), Vector3(-15, 1.5, -5), 0, true)
	_box("cyan", Vector3(2.1, 1.5, 0.07), Vector3(-15, 1.9, -5.27))
	_sign("NEON PEARL\n24H • CASINO\n← ENTRY", Vector3(-15, 2, -5.32), 25, Color(0.8, 1, 1))
	# Small night-food kiosk with an awning, counter, stools and crates.
	var stall := ModelLoader.load_model("res://assets/models/night_bites.glb")
	_box("rust", Vector3(2.48, 0.9, 1.16), Vector3(-17, 0.45, -1), 0, true)
	if stall != null:
		stall.position = Vector3(-17, 0, -1)
		stall.rotation.y = PI
		add_child(stall)
	else:
		_box("dark", Vector3(2.9, 0.14, 2.4), Vector3(-17, 2.8, -1))
		for x in [-18.1, -15.9]:
			_box("gold", Vector3(0.08, 2.8, 0.08), Vector3(x, 1.4, -1))
	_sign("NIGHT BITES", Vector3(-17, 2.52, -2.06), 29, Color(1, 0.65, 0.35))
	for x in [-18.1, -15.9]:
		_box("dark", Vector3(0.45, 0.6, 0.45), Vector3(x, 0.3, -3), 0, true)
	for z in [7.0, 13.0, 19.0]:
		_box("dark", Vector3(0.6, 1.7, 2.3), Vector3(-19.3, 0.85, z))
		for y in range(6):
			_box("rust", Vector3(0.66, 0.06, 1.9), Vector3(-19.3, 0.3 + y * 0.22, z))
	for x in [-14.0, -12.8]:
		_box("rust", Vector3(0.8, 0.65, 0.8), Vector3(x, 0.325, 1))
	var drain := ModelLoader.load_model("res://assets/models/neon_drain.glb")
	if drain != null:
		drain.position = Vector3(-4.3, 0.10, -6)
		add_child(drain)
	for x in [-17.5, 17.5]:
		_box("gold", Vector3(0.12, 8, 0.12), Vector3(x, 4, -0.4))
	# Cable trays along the side facades.
	for side in [-1.0, 1.0]:
		for y in [2.4, 2.7]:
			_box("dark", Vector3(0.14, 0.14, 33), Vector3(side * 18.8, y, 19))

func _street_life() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6401
	for person in [["Worker", Vector3(-17, 0.1, 0.3), 0.0],
			["Casual", Vector3(-16.8, 0.1, -3.6), PI],
			["Suit", Vector3(5.8, 0.1, -2.0), PI]]:
		var npc := preload("res://npc.gd").new()
		add_child(npc)
		npc.setup(global_position, 2.0, person[0], rng, true)
		npc.global_position = to_global(person[1])
		npc.rotation.y = person[2]

func update_doors(player_position: Vector3, delta: float) -> void:
	var local := to_local(player_position)
	var near: bool = absf(local.x) < 5.0 and local.z > -6.5 and local.z < 7.0 and absf(local.y) < 3.0
	_open = move_toward(_open, 1.0 if near else 0.0, delta * 1.8)
	var eased: float = _open * _open * (3.0 - 2.0 * _open)
	for i in range(_doors.size()):
		var side: float = -1.0 if i == 0 else 1.0
		_doors[i].position.x = side * (1.5 + eased * 2.9)

func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		var main := get_tree().get_first_node_in_group("main")
		if main != null:
			_player = main.get("player") as Node3D
	if is_instance_valid(_player):
		update_doors(_player.global_position, delta)
