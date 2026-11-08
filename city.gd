extends Node3D
## Procedural neon city: grid roads, emissive-window towers, neon signs,
## kiosks and a holo tower. Everything is code-built; no external textures.

const BLOCK: float = 60.0        # road pitch
const ROAD_W: float = 15.0
const N: int = 5                 # roads from -N..N -> city extent +-330
const EXTENT: float = 330.0

var poi_kiosks: Array[Vector3] = []
var poi_terminals: Array[Vector3] = []
var poi_pickups: Array[Vector3] = []
var sidewalk_blocks: Array = []  # {center: Vector3, half: float}
var holo: Node3D
var _rng := RandomNumberGenerator.new()
var _font: Font

var _mat_asphalt: StandardMaterial3D
var _mat_sidewalk: StandardMaterial3D
var _mat_ground: StandardMaterial3D
var _window_mats: Array = []
var _neon_mats: Array = []
var _mat_dark_metal: StandardMaterial3D

const NEON_COLORS: Array[Color] = [
	Color(1.0, 0.15, 0.55), Color(0.1, 0.9, 1.0), Color(1.0, 0.75, 0.1),
	Color(0.55, 0.3, 1.0), Color(0.2, 1.0, 0.45), Color(1.0, 0.35, 0.1),
]
const SIGN_WORDS: Array[String] = [
	"バー", "ラーメン", "ホテル", "クラブ", "薬局", "電脳酒場", "24H",
	"麺", "ネオン", "サイバー", "質屋", "カジノ", "BAR-9", "麺屋2099",
]

func _mat(color: Color, emission: float = 0.0, rough: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m

func _window_texture() -> ImageTexture:
	# NOTE: keep this an albedo-only texture at UV scale 1. On the software-GL
	# verification pipeline, material uv1_scale corrupts texture sampling and
	# emission_texture blows out to white; an unshaded albedo texture renders
	# correctly everywhere. A tall grid keeps windows small on any facade.
	var w: int = 48
	var h: int = 96
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var c := Color(0.035, 0.045, 0.1)
			if _rng.randf() < 0.30:
				var pick: float = _rng.randf()
				if pick < 0.55:
					c = Color(1.0, 0.8, 0.45) * _rng.randf_range(0.5, 1.0)
				elif pick < 0.8:
					c = Color(0.55, 0.85, 1.0) * _rng.randf_range(0.5, 1.0)
				else:
					c = Color(1.0, 0.45, 0.7) * _rng.randf_range(0.5, 1.0)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

func _make_materials() -> void:
	_mat_asphalt = _mat(Color(0.05, 0.05, 0.085), 0.0, 0.55)
	_mat_sidewalk = _mat(Color(0.12, 0.12, 0.17), 0.0, 0.9)
	_mat_ground = _mat(Color(0.012, 0.012, 0.03), 0.0, 1.0)
	_mat_dark_metal = _mat(Color(0.05, 0.05, 0.08), 0.0, 0.5)
	for i in range(5):
		var tex: ImageTexture = _window_texture()
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.albedo_color = Color(1, 1, 1)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_window_mats.append(m)
	for c in NEON_COLORS:
		_neon_mats.append(_mat(c, 2.6, 0.4))

func _box(parent: Node, size: Vector3, pos: Vector3, mat: Material, collide: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	if mat != null:
		mi.material_override = mat
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		mi.add_child(body)
		body.position = Vector3.ZERO
	return mi

func build(font: Font) -> void:
	_rng.seed = 2099
	_font = font
	_make_materials()
	_build_ground_and_roads()
	_build_blocks()
	_build_holo()
	_build_boundary()

func _build_ground_and_roads() -> void:
	# Base ground slab + physics.
	_box(self, Vector3(760, 1, 760), Vector3(0, -0.56, 0), _mat_ground, true)
	# Road strips along X and Z.
	for i in range(-N, N + 1):
		var c: float = i * BLOCK
		_box(self, Vector3(EXTENT * 2 + ROAD_W, 0.1, ROAD_W), Vector3(0, 0.02, c), _mat_asphalt)
		_box(self, Vector3(ROAD_W, 0.1, EXTENT * 2 + ROAD_W), Vector3(c, 0.02, 0), _mat_asphalt)
	# Glowing center dashes via MultiMesh (one draw call).
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(3.2, 0.06, 0.35)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = dash_mesh
	var transforms: Array[Transform3D] = []
	for i in range(-N, N + 1):
		var c: float = i * BLOCK
		var t: float = -EXTENT + 8.0
		while t < EXTENT - 4.0:
			# skip intersection centers
			var near_cross: bool = false
			for j in range(-N, N + 1):
				if absf(t - j * BLOCK) < ROAD_W * 0.7:
					near_cross = true
			if not near_cross:
				transforms.append(Transform3D(Basis.IDENTITY, Vector3(t, 0.09, c)))
				transforms.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(c, 0.09, t)))
			t += 11.0
	mm.instance_count = transforms.size()
	for k in range(transforms.size()):
		mm.set_instance_transform(k, transforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _neon_mats[1]
	add_child(mmi)
	# Streetlight poles (visual only, MultiMesh).
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.06
	pole_mesh.bottom_radius = 0.09
	pole_mesh.height = 5.2
	var pm := MultiMesh.new()
	pm.transform_format = MultiMesh.TRANSFORM_3D
	pm.mesh = pole_mesh
	var poles: Array[Transform3D] = []
	for i in range(-N, N + 1):
		var c: float = i * BLOCK
		var t: float = -EXTENT + 20.0
		while t < EXTENT:
			poles.append(Transform3D(Basis.IDENTITY, Vector3(t, 2.6, c - ROAD_W * 0.62)))
			poles.append(Transform3D(Basis.IDENTITY, Vector3(c + ROAD_W * 0.62, 2.6, t)))
			t += 40.0
	pm.instance_count = poles.size()
	for k in range(poles.size()):
		pm.set_instance_transform(k, poles[k])
	var pmi := MultiMeshInstance3D.new()
	pmi.multimesh = pm
	pmi.material_override = _mat_dark_metal
	add_child(pmi)

func _build_blocks() -> void:
	var kiosk_spots: Array[Vector2] = [Vector2(-2, -2), Vector2(2, -1), Vector2(0, 2), Vector2(-3, 2), Vector2(3, 3)]
	for bx in range(-N, N):
		for bz in range(-N, N):
			var cx: float = bx * BLOCK + BLOCK * 0.5
			var cz: float = bz * BLOCK + BLOCK * 0.5
			var inner: float = BLOCK - ROAD_W  # 45
			# Sidewalk slab.
			_box(self, Vector3(inner, 0.36, inner), Vector3(cx, 0.09, cz), _mat_sidewalk)
			sidewalk_blocks.append({"center": Vector3(cx, 0.27, cz), "half": inner * 0.5})
			# Buildings: 1 big or 4 small.
			if _rng.randf() < 0.4:
				_add_building(Vector3(cx, 0, cz), Vector2(inner * 0.72, inner * 0.72))
			else:
				var q: float = inner * 0.25
				for ox in [-q, q]:
					for oz in [-q, q]:
						if _rng.randf() < 0.85:
							_add_building(Vector3(cx + ox, 0, cz + oz), Vector2(inner * 0.4, inner * 0.4))
			# POIs on some blocks.
			var key := Vector2(bx, bz)
			if kiosk_spots.has(key):
				_add_kiosk(Vector3(cx - inner * 0.32, 0.27, cz - inner * 0.32))
			if (bx + bz) % 3 == 0:
				poi_terminals.append(Vector3(cx + inner * 0.34, 0.27, cz + inner * 0.1))
				_add_terminal(poi_terminals[poi_terminals.size() - 1])
			if (bx * 7 + bz) % 4 == 0:
				poi_pickups.append(Vector3(cx - inner * 0.15, 0.27, cz + inner * 0.33))

func _add_building(center: Vector3, fp: Vector2) -> void:
	var height: float = _rng.randf_range(13.0, 46.0)
	if _rng.randf() < 0.12:
		height = _rng.randf_range(48.0, 72.0)
	var wm: StandardMaterial3D = _window_mats[_rng.randi() % _window_mats.size()]
	_box(self, Vector3(fp.x, height, fp.y), Vector3(center.x, height * 0.5 + 0.27, center.z), wm, true)
	# Neon roof trim.
	var neon: Material = _neon_mats[_rng.randi() % _neon_mats.size()]
	_box(self, Vector3(fp.x + 0.5, 0.5, fp.y + 0.5), Vector3(center.x, height + 0.35, center.z), neon)
	# Wall sign on a random side for many buildings.
	if _rng.randf() < 0.55:
		var side: int = _rng.randi() % 4
		var dir := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)][side] as Vector3
		var off: Vector3 = dir * (fp.x * 0.5 + 0.2) if dir.x != 0.0 else dir * (fp.y * 0.5 + 0.2)
		var spos: Vector3 = center + off + Vector3(0, _rng.randf_range(6.0, maxf(7.0, height * 0.55)), 0)
		var ssize := Vector3(0.3, _rng.randf_range(3.0, 5.5), 1.6)
		if dir.z != 0.0:
			ssize = Vector3(1.6, ssize.y, 0.3)
		_box(self, ssize, spos, neon)
		if _font != null and _rng.randf() < 0.6:
			var lab := Label3D.new()
			lab.text = SIGN_WORDS[_rng.randi() % SIGN_WORDS.size()]
			lab.font = _font
			lab.font_size = 96
			lab.pixel_size = 0.011
			lab.modulate = Color(1, 1, 1)
			lab.outline_size = 8
			lab.position = spos + dir * 0.25
			lab.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			if dir.x > 0.0:
				lab.rotation.y = PI * 0.5
			elif dir.x < 0.0:
				lab.rotation.y = -PI * 0.5
			elif dir.z < 0.0:
				lab.rotation.y = PI
			add_child(lab)

func _add_kiosk(pos: Vector3) -> void:
	poi_kiosks.append(pos)
	var g := Node3D.new()
	g.position = pos
	add_child(g)
	_box(g, Vector3(1.4, 2.6, 0.8), Vector3(0, 1.3, 0), _mat_dark_metal, true)
	_box(g, Vector3(1.1, 1.1, 0.12), Vector3(0, 1.7, 0.45), _neon_mats[1])
	if _font != null:
		var lab := Label3D.new()
		lab.text = "JOB"
		lab.font = _font
		lab.font_size = 72
		lab.pixel_size = 0.008
		lab.modulate = Color(0.4, 0.95, 1.0)
		lab.position = Vector3(0, 3.1, 0)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		g.add_child(lab)

func _add_terminal(pos: Vector3) -> void:
	var g := Node3D.new()
	g.position = pos
	add_child(g)
	_box(g, Vector3(0.8, 1.9, 0.5), Vector3(0, 0.95, 0), _mat_dark_metal, true)
	_box(g, Vector3(0.6, 0.6, 0.1), Vector3(0, 1.35, 0.28), _neon_mats[0])

func _build_holo() -> void:
	holo = Node3D.new()
	holo.position = Vector3(0, 26, 0)
	add_child(holo)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 5.5
	tm.outer_radius = 6.5
	ring.mesh = tm
	ring.rotation.x = PI * 0.5
	ring.material_override = _neon_mats[0]
	holo.add_child(ring)
	if _font != null:
		var lab := Label3D.new()
		lab.text = "NEO-KIBARA 2099"
		lab.font = _font
		lab.font_size = 128
		lab.pixel_size = 0.02
		lab.modulate = Color(1.0, 0.35, 0.8)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		holo.add_child(lab)

func _build_boundary() -> void:
	var wall_mat: Material = _mat(Color(0.04, 0.02, 0.08), 0.0, 0.7)
	for s in [-1.0, 1.0]:
		_box(self, Vector3(690, 16, 1.5), Vector3(0, 8, s * (EXTENT + 6)), wall_mat, true)
		_box(self, Vector3(1.5, 16, 690), Vector3(s * (EXTENT + 6), 8, 0), wall_mat, true)
		_box(self, Vector3(690, 0.6, 1.7), Vector3(0, 16.2, s * (EXTENT + 6)), _neon_mats[3])
		_box(self, Vector3(1.7, 0.6, 690), Vector3(s * (EXTENT + 6), 16.2, 0), _neon_mats[3])

func _process(delta: float) -> void:
	if holo != null:
		holo.rotation.y += delta * 0.25
