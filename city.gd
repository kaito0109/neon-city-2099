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
var _buildings: Array = []  # {center, fp, height} for facade relief
var _tank_xforms: Array[Transform3D] = []
var skybridge_count: int = 0
var _billboard_mats: Array = []
var billboard_count: int = 0
var _searchlights: Array = []
var holo: Node3D
var _rng := RandomNumberGenerator.new()
var _font: Font

var _mat_asphalt: StandardMaterial3D
var _mat_asphalt_pbr: StandardMaterial3D
var road_tile_count: int = 0
var _photo_mats: Array = []
var photo_building_count: int = 0
var _mat_sidewalk: StandardMaterial3D
var _mat_ground: StandardMaterial3D
var _window_mats: Array = []
var _neon_mats: Array = []
var _mat_dark_metal: StandardMaterial3D
var _mat_roof: StandardMaterial3D
var _mat_beacon: StandardMaterial3D
var _mat_edge_line: StandardMaterial3D
var _mat_crosswalk: StandardMaterial3D
var _mat_puddle: StandardMaterial3D
var _mat_pool: StandardMaterial3D
var _mat_bulb: StandardMaterial3D
var _glow_tex: ImageTexture
var _t: float = 0.0

const NEON_COLORS: Array[Color] = [
	Color(1.0, 0.15, 0.55), Color(0.1, 0.9, 1.0), Color(1.0, 0.75, 0.1),
	Color(0.55, 0.3, 1.0), Color(0.2, 1.0, 0.45), Color(1.0, 0.35, 0.1),
]
const SIGN_WORDS: Array[String] = [
	"バー", "ラーメン", "ホテル", "クラブ", "薬局", "電脳酒場", "24H",
	"麺", "ネオン", "サイバー", "質屋", "カジノ", "BAR-9", "麺屋2099",
]
const BILLBOARD_BRANDS: Array[String] = [
	"TURBO", "データ堂", "麺NOODLE", "光学堂", "HOTEL-9",
	"サイバー薬局", "電脳BAR", "NEO質屋",
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

func _window_texture(style: int = 0) -> ImageTexture:
	# NOTE: keep this an albedo-only texture at UV scale 1. On the software-GL
	# verification pipeline, material uv1_scale corrupts texture sampling and
	# emission_texture blows out to white; an unshaded albedo texture renders
	# correctly everywhere. Styles vary palette / lit ratio / window size
	# so buildings stop looking cloned.
	var palettes: Array = [
		[Color(1.0, 0.8, 0.45), Color(0.55, 0.85, 1.0), Color(1.0, 0.45, 0.7)],
		[Color(1.0, 0.78, 0.42), Color(1.0, 0.86, 0.58), Color(0.92, 0.62, 0.3)],
		[Color(0.5, 0.85, 1.0), Color(0.72, 0.95, 1.0), Color(0.35, 0.6, 1.0)],
		[Color(1.0, 0.3, 0.6), Color(0.75, 0.35, 1.0), Color(1.0, 0.55, 0.82)],
		[Color(0.35, 1.0, 0.7), Color(0.62, 1.0, 0.86), Color(0.2, 0.85, 0.9)],
	]
	var pal: Array = palettes[style % palettes.size()]
	var lit: float = [0.36, 0.50, 0.30, 0.44, 0.33][style % 5]
	var cell_h: int = [1, 1, 2, 1, 3][style % 5]
	var w: int = 48
	var h: int = 96
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.075, 0.09, 0.17))
	var cy: int = 0
	while cy < h:
		var cx: int = 0
		while cx < w:
			if _rng.randf() < lit:
				var col: Color = pal[_rng.randi() % pal.size()] * _rng.randf_range(0.45, 1.0)
				for yy in range(cy, mini(cy + cell_h, h)):
					for xx in range(cx, mini(cx + 2, w)):
						img.set_pixel(xx, yy, col)
			cx += 2
		cy += cell_h
	# v2.5 weathering: speckle grime, a few rain-streak columns, and
	# darker bands at both ends (base splash-back / parapet grime).
	for i in range(500):
		var gx: int = _rng.randi() % w
		var gy: int = _rng.randi() % h
		img.set_pixel(gx, gy, img.get_pixel(gx, gy) * _rng.randf_range(0.45, 0.8))
	for s in range(3):
		var sx2: int = _rng.randi() % w
		var dark: float = _rng.randf_range(0.55, 0.8)
		for yy in range(h):
			img.set_pixel(sx2, yy, img.get_pixel(sx2, yy) * dark)
	for yy in range(h):
		var edge: float = minf(float(yy), float(h - 1 - yy)) / float(h)
		if edge < 0.09:
			var f2: float = 0.55 + edge * 4.0
			for xx in range(w):
				img.set_pixel(xx, yy, img.get_pixel(xx, yy) * f2)
	return ImageTexture.create_from_image(img)

func _district_indices(pos: Vector3) -> Array:
	var d: float = Vector2(pos.x, pos.z).length()
	if d < 110.0:
		return [0, 1, 2, 3, 4, 5]
	if absf(pos.x) > absf(pos.z):
		return [3, 0, 1] if pos.x > 0.0 else [4, 1, 2]
	return [1, 3, 4] if pos.z < 0.0 else [2, 5, 0]

func _district_neon_mat(pos: Vector3) -> Material:
	var idx: Array = _district_indices(pos)
	return _neon_mats[idx[_rng.randi() % idx.size()]]

func _district_neon_color(pos: Vector3, rng: RandomNumberGenerator) -> Color:
	var idx: Array = _district_indices(pos)
	return NEON_COLORS[idx[rng.randi() % idx.size()]]

func _glow_texture() -> ImageTexture:
	# Soft radial gradient (white, alpha falls off) for fake glow pools.
	var s: int = 128
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var center: float = (s - 1) * 0.5
	for y in range(s):
		for x in range(s):
			var d: float = Vector2(x - center, y - center).length() / center
			var a: float = pow(clampf(1.0 - d, 0.0, 1.0), 2.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

func _make_materials() -> void:
	_mat_asphalt = _mat(Color(0.078, 0.078, 0.12), 0.0, 0.34)
	_mat_sidewalk = _mat(Color(0.155, 0.155, 0.215), 0.0, 0.9)
	_mat_sidewalk.albedo_texture = _noise_texture(Color(0.155, 0.155, 0.215))
	# v2.5 PBR (ambientCG, CC0): photo asphalt on road tiles, concrete
	# normal/roughness on the sidewalks.
	var cn: Texture2D = TextureLoader.load_tex("res://assets/textures/concrete_normal.jpg", "res://assets/texture_data/concrete_normal.tres")
	var cr: Texture2D = TextureLoader.load_tex("res://assets/textures/concrete_rough.jpg", "res://assets/texture_data/concrete_rough.tres")
	if cn != null:
		_mat_sidewalk.normal_enabled = true
		_mat_sidewalk.normal_texture = cn
		_mat_sidewalk.normal_scale = 0.45
	if cr != null:
		_mat_sidewalk.roughness_texture = cr
	var ac: Texture2D = TextureLoader.load_tex("res://assets/textures/asphalt_color.jpg", "res://assets/texture_data/asphalt_color.tres")
	var an: Texture2D = TextureLoader.load_tex("res://assets/textures/asphalt_normal.jpg", "res://assets/texture_data/asphalt_normal.tres")
	var ar: Texture2D = TextureLoader.load_tex("res://assets/textures/asphalt_rough.jpg", "res://assets/texture_data/asphalt_rough.tres")
	if ac != null:
		_mat_asphalt_pbr = StandardMaterial3D.new()
		_mat_asphalt_pbr.albedo_texture = ac
		_mat_asphalt_pbr.albedo_color = Color(0.62, 0.62, 0.64)
		_mat_asphalt_pbr.vertex_color_use_as_albedo = true
		_mat_asphalt_pbr.metallic = 0.0
		_mat_asphalt_pbr.roughness = 1.0
		if ar != null:
			_mat_asphalt_pbr.roughness_texture = ar
		if an != null:
			_mat_asphalt_pbr.normal_enabled = true
			_mat_asphalt_pbr.normal_texture = an
			_mat_asphalt_pbr.normal_scale = 0.85
		_mat_asphalt_pbr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mat_ground = _mat(Color(0.03, 0.03, 0.062), 0.0, 1.0)
	_mat_dark_metal = _mat(Color(0.05, 0.05, 0.08), 0.0, 0.5)
	_mat_roof = _mat(Color(0.045, 0.05, 0.085), 0.0, 0.95)
	_glow_tex = _glow_texture()
	# Aviation beacons (shared material, blinked in _process).
	_mat_beacon = _mat(Color(1.0, 0.12, 0.2), 2.4, 0.4)
	# Road edge lines: pale, unshaded so they read at night without glowing.
	_mat_edge_line = StandardMaterial3D.new()
	_mat_edge_line.albedo_color = Color(0.32, 0.42, 0.55)
	_mat_edge_line.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Crosswalk stripes: plain light concrete.
	_mat_crosswalk = _mat(Color(0.5, 0.55, 0.62), 0.0, 0.9)
	# Puddles: darker, much smoother than asphalt -> moon/neon sheen.
	_mat_puddle = _mat(Color(0.09, 0.12, 0.2), 0.0, 0.12)
	_mat_puddle.metallic = 0.55
	# Fake streetlight pools on the road (additive gradient quads).
	_mat_pool = StandardMaterial3D.new()
	_mat_pool.albedo_texture = _glow_tex
	_mat_pool.albedo_color = Color(0.35, 0.6, 0.85, 0.34)
	_mat_pool.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_pool.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_pool.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_pool.no_depth_test = false
	# Streetlight bulbs.
	_mat_bulb = _mat(Color(0.75, 0.95, 1.0), 2.4, 0.4)
	for i in range(10):
		var tex: ImageTexture = _window_texture(i)
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.albedo_color = Color(1, 1, 1)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_window_mats.append(m)
	for c in NEON_COLORS:
		_neon_mats.append(_mat(c, 2.6, 0.4))
	for k in range(5):
		var bm := StandardMaterial3D.new()
		bm.albedo_texture = _billboard_texture(k)
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_billboard_mats.append(bm)
	# v2.6 photo facades (ambientCG Facade 008/010/018B, CC0, night
	# baked): unshaded like the window towers, but photographic —
	# real lit offices with interiors instead of flat window grids.
	for fa in ["a", "b", "c"]:
		var ft: Texture2D = TextureLoader.load_tex("res://assets/textures/facade_" + fa + ".jpg", "res://assets/texture_data/facade_" + fa + ".tres")
		if ft != null:
			var fm := StandardMaterial3D.new()
			fm.albedo_texture = ft
			fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			_photo_mats.append(fm)

func _disc(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	for yy in range(-r, r + 1):
		var half: int = int(sqrt(float(r * r - yy * yy)))
		img.fill_rect(Rect2i(cx - half, cy + yy, half * 2, 1), col)

func _billboard_texture(kind: int) -> ImageTexture:
	# Procedural "video ad" art: gradient + bold geometric motif +
	# scanlines + a dark brand band at the bottom (text goes on top
	# as a Label3D). Unshaded, so it glows like the real thing's ads.
	var w: int = 192
	var h: int = 384
	var tops: Array[Color] = [Color(1.0, 0.25, 0.55), Color(0.1, 0.75, 1.0), Color(0.55, 0.3, 1.0), Color(0.15, 0.95, 0.75), Color(1.0, 0.6, 0.1)]
	var bots: Array[Color] = [Color(1.0, 0.55, 0.1), Color(0.05, 0.2, 0.65), Color(1.0, 0.2, 0.45), Color(0.05, 0.35, 0.55), Color(0.85, 0.15, 0.1)]
	var top: Color = tops[kind % 5]
	var bot: Color = bots[kind % 5]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		var c: Color = top.lerp(bot, float(y) / float(h - 1))
		if y % 4 == 3:
			c *= 0.8
		img.fill_rect(Rect2i(0, y, w, 1), c)
	var white := Color(1, 1, 1, 0.92)
	var dark := Color(0.02, 0.02, 0.08, 0.9)
	match kind % 5:
		0:
			_disc(img, w / 2, 128, 62, Color(1.0, 0.92, 0.62, 0.95))
			for i in range(5):
				img.fill_rect(Rect2i(18, 222 + i * 20, w - 36, 9), dark)
		1:
			img.fill_rect(Rect2i(w / 2 - 26, 72, 52, 188), white)
			img.fill_rect(Rect2i(w / 2 - 13, 40, 26, 34), white)
			img.fill_rect(Rect2i(w / 2 - 26, 150, 52, 34), dark)
		2:
			var r: int = 70
			var ring_i: int = 0
			while r > 12:
				_disc(img, w / 2, 148, r, white if ring_i % 2 == 0 else dark)
				r -= 14
				ring_i += 1
		3:
			for i in range(72):
				var half2: int = 70 - abs(i - 36) * 2
				if half2 > 0:
					img.fill_rect(Rect2i(w / 2 - half2, 76 + i, half2 * 2, 1), white)
		4:
			for gy in range(6):
				for gx in range(4):
					if (gx + gy) % 2 == 0:
						img.fill_rect(Rect2i(16 + gx * 42, 36 + gy * 42, 30, 30), Color(1, 1, 1, 0.75))
			_disc(img, w - 52, 300, 30, white)
	img.fill_rect(Rect2i(0, h - 58, w, 58), dark)
	img.fill_rect(Rect2i(0, h - 58, w, 6), white)
	return ImageTexture.create_from_image(img)

func _noise_texture(base: Color, size: int = 256) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var nrng := RandomNumberGenerator.new()
	nrng.seed = 99
	for y in range(size):
		for x in range(size):
			var v: float = nrng.randf_range(-0.05, 0.05)
			img.set_pixel(x, y, Color(
				clampf(base.r + v, 0.0, 1.0),
				clampf(base.g + v, 0.0, 1.0),
				clampf(base.b + v, 0.0, 1.0)))
	for i in range(60):
		var bx: int = nrng.randi() % size
		var by: int = nrng.randi() % size
		var w: int = nrng.randi_range(5, 22)
		var dark: float = nrng.randf_range(0.55, 0.85)
		for yy in range(by, mini(by + w, size)):
			for xx in range(bx, mini(bx + w, size)):
				var p: Color = img.get_pixel(xx, yy)
				img.set_pixel(xx, yy, Color(p.r * dark, p.g * dark, p.b * dark))
	return ImageTexture.create_from_image(img)

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
	_build_skyline()
	_build_sky()
	_build_blender_props()
	_build_street_props()
	_build_hero_towers()
	_build_facade_kits()
	_build_facade_relief()
	_build_elevated()
	_build_hills()
	_build_searchlights()

func _build_searchlights() -> void:
	var sorted_b: Array = _buildings.duplicate()
	sorted_b.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["height"]) > float(b["height"]))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.65, 0.85, 1.0, 0.05)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var made: int = 0
	for b in sorted_b:
		if made >= 2:
			break
		var c: Vector3 = b["center"]
		var h: float = b["height"]
		if h < 40.0:
			continue
		var pivot := Node3D.new()
		pivot.position = Vector3(c.x, h + 0.3, c.z)
		add_child(pivot)
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 6.0
		cm.bottom_radius = 0.35
		cm.height = 52.0
		cm.radial_segments = 20
		cone.mesh = cm
		cone.position.y = 26.0
		cone.material_override = mat
		pivot.add_child(cone)
		_searchlights.append({"pivot": pivot, "phase": float(made) * 2.1})
		made += 1

func _build_ground_and_roads() -> void:
	# Base ground slab + physics.
	_box(self, Vector3(760, 1, 760), Vector3(0, -0.56, 0), _mat_ground, true)
	# Road strips along X and Z.
	for i in range(-N, N + 1):
		var c: float = i * BLOCK
		_box(self, Vector3(EXTENT * 2 + ROAD_W, 0.1, ROAD_W), Vector3(0, 0.02, c), _mat_asphalt)
		_box(self, Vector3(ROAD_W, 0.1, EXTENT * 2 + ROAD_W), Vector3(c, 0.02, 0), _mat_asphalt)
	_build_road_tiles()
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
	# Streetlight bulbs + fake light pools under each pole (v1.1 visuals).
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.15
	bulb_mesh.height = 0.3
	var bm2 := MultiMesh.new()
	bm2.transform_format = MultiMesh.TRANSFORM_3D
	bm2.mesh = bulb_mesh
	bm2.instance_count = poles.size()
	for k in range(poles.size()):
		var pp: Vector3 = poles[k].origin
		bm2.set_instance_transform(k, Transform3D(Basis.IDENTITY, pp + Vector3(0, 2.62, 0)))
	var bmi := MultiMeshInstance3D.new()
	bmi.multimesh = bm2
	bmi.material_override = _mat_bulb
	add_child(bmi)
	var pool_mesh := QuadMesh.new()
	pool_mesh.size = Vector2(8.5, 8.5)
	var qm := MultiMesh.new()
	qm.transform_format = MultiMesh.TRANSFORM_3D
	qm.mesh = pool_mesh
	qm.instance_count = poles.size()
	var flat := Basis(Vector3.RIGHT, -PI * 0.5)
	for k in range(poles.size()):
		var pp2: Vector3 = poles[k].origin
		qm.set_instance_transform(k, Transform3D(flat, Vector3(pp2.x, 0.085, pp2.z)))
	var qmi := MultiMeshInstance3D.new()
	qmi.multimesh = qm
	qmi.material_override = _mat_pool
	add_child(qmi)
	_build_road_details()

func _build_road_details() -> void:
	# Edge lines along every road strip (thin pale boxes, one per side).
	for i in range(-N, N + 1):
		var c: float = i * BLOCK
		for s in [-1.0, 1.0]:
			_box(self, Vector3(EXTENT * 2 + ROAD_W, 0.05, 0.26), Vector3(0, 0.075, c + s * (ROAD_W * 0.5 - 0.6)), _mat_edge_line)
			_box(self, Vector3(0.26, 0.05, EXTENT * 2 + ROAD_W), Vector3(c + s * (ROAD_W * 0.5 - 0.6), 0.075, 0), _mat_edge_line)
	# Crosswalks at every intersection (zebra stripes, one MultiMesh).
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.55, 0.05, 3.4)
	var cm := MultiMesh.new()
	cm.transform_format = MultiMesh.TRANSFORM_3D
	cm.mesh = stripe
	var cts: Array[Transform3D] = []
	var rot90 := Basis(Vector3.UP, PI * 0.5)
	for i in range(-N, N + 1):
		for j in range(-N, N + 1):
			var cx: float = i * BLOCK
			var cz: float = j * BLOCK
			for s in [-1.0, 1.0]:
				# Crossing the Z-running road, walking along X.
				for k in range(5):
					cts.append(Transform3D(Basis.IDENTITY,
						Vector3(cx - 2.2 + k * 1.1, 0.08, cz + s * (ROAD_W * 0.5 + 2.6))))
				# Crossing the X-running road, walking along Z.
				for k in range(5):
					cts.append(Transform3D(rot90,
						Vector3(cx + s * (ROAD_W * 0.5 + 2.6), 0.08, cz - 2.2 + k * 1.1)))
	cm.instance_count = cts.size()
	for k in range(cts.size()):
		cm.set_instance_transform(k, cts[k])
	var cmi := MultiMeshInstance3D.new()
	cmi.multimesh = cm
	cmi.material_override = _mat_crosswalk
	add_child(cmi)
	# Puddles on the roads (flattened discs, glossy material).
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	var dm := MultiMesh.new()
	dm.transform_format = MultiMesh.TRANSFORM_3D
	dm.mesh = disc
	var count: int = 200
	dm.instance_count = count
	for k in range(count):
		var road_c: float = float(_rng.randi_range(-N, N)) * BLOCK
		var along: float = _rng.randf_range(-EXTENT + 12.0, EXTENT - 12.0)
		var off: float = _rng.randf_range(-5.2, 5.2)
		var pos: Vector3 = Vector3(along, 0.078, road_c + off) if k % 2 == 0 else Vector3(road_c + off, 0.078, along)
		var r: float = _rng.randf_range(1.6, 4.2)
		var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(r, 1.0, r * _rng.randf_range(0.55, 0.85)))
		dm.set_instance_transform(k, Transform3D(b, pos))
	var dmi := MultiMeshInstance3D.new()
	dmi.multimesh = dm
	dmi.material_override = _mat_puddle
	add_child(dmi)

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

func _roof_finish(cx: float, cz: float, fp: Vector2, top_y: float, neon: Material) -> void:
	# Dark cap flush with the walkable roof surface.
	_box(self, Vector3(fp.x + 0.2, 0.12, fp.y + 0.2), Vector3(cx, top_y - 0.04, cz), _mat_roof)
	# Thin neon cornice frame around the edge.
	var t: float = 0.4
	var y: float = top_y + 0.05
	_box(self, Vector3(fp.x + 0.55, 0.16, t), Vector3(cx, y, cz - fp.y * 0.5 - 0.05), neon)
	_box(self, Vector3(fp.x + 0.55, 0.16, t), Vector3(cx, y, cz + fp.y * 0.5 + 0.05), neon)
	_box(self, Vector3(t, 0.16, fp.y + 0.55), Vector3(cx - fp.x * 0.5 - 0.05, y, cz), neon)
	_box(self, Vector3(t, 0.16, fp.y + 0.55), Vector3(cx + fp.x * 0.5 + 0.05, y, cz), neon)

func _add_building(center: Vector3, fp: Vector2) -> void:
	var height: float = _rng.randf_range(13.0, 46.0)
	if _rng.randf() < 0.12:
		height = _rng.randf_range(48.0, 72.0)
	_buildings.append({"center": center, "fp": fp, "height": height})
	# Per-building duplicate + tint: same texture family, different tone.
	var wm: StandardMaterial3D = (_window_mats[_rng.randi() % _window_mats.size()] as StandardMaterial3D).duplicate() as StandardMaterial3D
	var bright: float = _rng.randf_range(0.72, 1.12)
	wm.albedo_color = Color(bright * _rng.randf_range(0.9, 1.06), bright, bright * _rng.randf_range(0.9, 1.1))
	# Photo-facade towers: stacked ~13 m segments of real night
	# facade (one full-height collider hidden inside the shells).
	var photo: bool = not _photo_mats.is_empty() and height >= 19.0 and fp.x <= 31.0 and fp.y <= 31.0 and _rng.randf() < 0.42
	if photo:
		photo_building_count += 1
		var pm: Material = _photo_mats[_rng.randi() % _photo_mats.size()]
		var segs: int = int(ceil(height / 13.0))
		var seg_h: float = height / float(segs)
		for s in range(segs):
			var seg: MeshInstance3D = _box(self, Vector3(fp.x, seg_h, fp.y), Vector3(center.x, 0.27 + seg_h * (float(s) + 0.5), center.z), pm)
			if s % 2 == 1:
				seg.rotation.y = PI
		_box(self, Vector3(fp.x - 0.04, height, fp.y - 0.04), Vector3(center.x, height * 0.5 + 0.27, center.z), _mat_dark_metal, true)
	else:
		_box(self, Vector3(fp.x, height, fp.y), Vector3(center.x, height * 0.5 + 0.27, center.z), wm, true)
	# Roof finish (district-biased colour): dark cap + thin neon
	# cornice frame. (Was a solid emissive slab — rooftops blew out
	# white and swallowed the player's feet; matters now that roofs
	# are gameplay space.)
	var neon: Material = _district_neon_mat(center)
	_roof_finish(center.x, center.z, fp, height + 0.27, neon)
	# Silhouette variety: setback crown on tall towers, annex on big mid-rises.
	if photo:
		pass
	elif height > 34.0:
		var h2: float = height * _rng.randf_range(0.22, 0.4)
		var fp2: Vector2 = fp * _rng.randf_range(0.55, 0.72)
		_box(self, Vector3(fp2.x, h2, fp2.y), Vector3(center.x, height + 0.27 + h2 * 0.5, center.z), wm, true)
		_roof_finish(center.x, center.z, fp2, height + 0.27 + h2, neon)
		_buildings.append({"center": center, "fp": fp2, "height": height + h2})
	elif height > 17.0 and fp.x > 30.0 and _rng.randf() < 0.35:
		var ah: float = _rng.randf_range(4.5, 8.5)
		var sgn: float = 1.0 if _rng.randf() < 0.5 else -1.0
		if _rng.randf() < 0.5:
			_box(self, Vector3(4.2, ah, fp.y * 0.66), Vector3(center.x + sgn * (fp.x * 0.5 + 2.1), 0.27 + ah * 0.5, center.z), wm, true)
		else:
			_box(self, Vector3(fp.x * 0.66, ah, 4.2), Vector3(center.x, 0.27 + ah * 0.5, center.z + sgn * (fp.y * 0.5 + 2.1)), wm, true)
	# Rooftop antenna + blinking beacon on tall towers (v1.1 visuals).
	if height > 38.0:
		var ant := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.14
		cyl.height = _rng.randf_range(3.5, 6.5)
		ant.mesh = cyl
		ant.position = Vector3(center.x, height + 0.27 + cyl.height * 0.5, center.z)
		ant.material_override = _mat_dark_metal
		add_child(ant)
		var bec := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.3
		sph.height = 0.6
		bec.mesh = sph
		bec.position = Vector3(center.x, height + 0.27 + cyl.height + 0.3, center.z)
		bec.material_override = _mat_beacon
		add_child(bec)
	# Giant video billboard on some tall towers.
	if height > 36.0 and _rng.randf() < 0.5:
		var bside: int = _rng.randi() % 4
		var bdir := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)][bside] as Vector3
		var bw: float = _rng.randf_range(9.0, 13.0)
		var bh: float = bw * 1.9
		var boff: Vector3 = bdir * (fp.x * 0.5 + 0.18) if bdir.x != 0.0 else bdir * (fp.y * 0.5 + 0.18)
		var bpos: Vector3 = center + boff + Vector3(0, height * 0.58, 0)
		var plane := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(bw, bh)
		plane.mesh = qm
		plane.position = bpos
		plane.material_override = _billboard_mats[billboard_count % _billboard_mats.size()]
		if bdir.x > 0.0:
			plane.rotation.y = PI * 0.5
		elif bdir.x < 0.0:
			plane.rotation.y = -PI * 0.5
		elif bdir.z < 0.0:
			plane.rotation.y = PI
		add_child(plane)
		billboard_count += 1
		if _font != null:
			var blab := Label3D.new()
			blab.text = BILLBOARD_BRANDS[billboard_count % BILLBOARD_BRANDS.size()]
			blab.font = _font
			blab.font_size = 144
			blab.pixel_size = 0.016
			blab.modulate = Color(1, 1, 1)
			blab.outline_size = 10
			blab.position = bpos + bdir * 0.15 + Vector3(0, bh * 0.3, 0)
			blab.rotation = plane.rotation
			add_child(blab)
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

func _build_skyline() -> void:
	# Distant mega-towers beyond the playable boundary: the city never ends.
	var idx: int = 0
	var ang: float = 0.0
	while ang < TAU:
		var r: float = _rng.randf_range(425.0, 540.0)
		var pos := Vector3(cos(ang) * r, 0, sin(ang) * r)
		var w: float = _rng.randf_range(28.0, 58.0)
		var h: float = _rng.randf_range(55.0, 165.0)
		if idx % 9 == 4:
			h = _rng.randf_range(180.0, 235.0)
		var wm: StandardMaterial3D = _window_mats[_rng.randi() % _window_mats.size()]
		var tower := _box(self, Vector3(w, h, w), Vector3(pos.x, h * 0.5, pos.z), wm)
		tower.rotation.y = _rng.randf() * PI
		if _rng.randf() < 0.35:
			_box(self, Vector3(w + 0.6, 0.5, w + 0.6), Vector3(pos.x, h + 0.3, pos.z), _neon_mats[_rng.randi() % _neon_mats.size()])
		if h > 120.0:
			var ant := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.15
			cyl.bottom_radius = 0.3
			cyl.height = 9.0
			ant.mesh = cyl
			ant.position = Vector3(pos.x, h + 4.5, pos.z)
			ant.material_override = _mat_dark_metal
			add_child(ant)
			var bec := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = 0.8
			sph.height = 1.6
			bec.mesh = sph
			bec.position = Vector3(pos.x, h + 9.2, pos.z)
			bec.material_override = _mat_beacon
			add_child(bec)
		ang += _rng.randf_range(0.10, 0.17)
		idx += 1

func _build_sky() -> void:
	# Stars (one MultiMesh of tiny boxes, fog disabled so they stay visible).
	var star_mat := StandardMaterial3D.new()
	star_mat.albedo_color = Color(0.8, 0.88, 1.0)
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.disable_fog = true
	var star_mesh := BoxMesh.new()
	star_mesh.size = Vector3(1.5, 1.5, 1.5)
	var sm := MultiMesh.new()
	sm.transform_format = MultiMesh.TRANSFORM_3D
	sm.mesh = star_mesh
	var scount: int = 240
	sm.instance_count = scount
	for k in range(scount):
		var dir := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(0.16, 1.0), _rng.randf_range(-1.0, 1.0)).normalized()
		var s: float = _rng.randf_range(0.7, 1.9)
		sm.set_instance_transform(k, Transform3D(Basis.IDENTITY.scaled(Vector3(s, s, s)), dir * 880.0))
	var smi := MultiMeshInstance3D.new()
	smi.multimesh = sm
	smi.material_override = star_mat
	add_child(smi)
	# Moon: bright disc + soft halo, billboarded, fog disabled.
	var moon_pos := Vector3(-430, 305, -690)
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_texture = _glow_tex
	disc_mat.albedo_color = Color(1.5, 1.65, 1.9, 1.0)
	disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	disc_mat.disable_fog = true
	var disc := MeshInstance3D.new()
	var dq := QuadMesh.new()
	dq.size = Vector2(88, 88)
	disc.mesh = dq
	disc.material_override = disc_mat
	disc.position = moon_pos
	add_child(disc)
	var halo_mat := StandardMaterial3D.new()
	halo_mat.albedo_texture = _glow_tex
	halo_mat.albedo_color = Color(0.4, 0.52, 0.95, 0.5)
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_mat.disable_fog = true
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(280, 280)
	halo.mesh = hq
	halo.material_override = halo_mat
	halo.position = moon_pos
	add_child(halo)

# --- v1.2 Blender models: street props + hero towers -------------------
# Loaded at runtime (not preload) so a missing GLB can never break the
# scene: the city simply falls back to the v1.1 procedural look.

func _place_model(glb_path: String, parent: Node, pos: Vector3, rot_y: float, scl: float = 1.0) -> Node3D:
	var inst: Node3D = ModelLoader.load_model(glb_path)
	if inst == null:
		return null
	inst.position = pos
	inst.rotation.y = rot_y
	inst.scale = Vector3.ONE * scl
	parent.add_child(inst)
	return inst

func _build_blender_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242  # separate seed: never perturbs the v1 city layout
	var root := Node3D.new()
	root.name = "BlenderProps"
	add_child(root)
	var dirs: Array[Vector3] = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	# Vending machines + holo totems on sidewalk blocks.
	var vend_left: int = 16
	var totem_left: int = 14
	for blk in sidewalk_blocks:
		var center: Vector3 = blk["center"]
		var half: float = float(blk["half"])
		if vend_left > 0 and rng.randf() < 0.30:
			var dir: Vector3 = dirs[rng.randi() % dirs.size()]
			var side_off: float = rng.randf_range(-9.0, 9.0)
			var pos: Vector3 = center + dir * (half - 2.4)
			if dir.x != 0.0:
				pos.z += side_off
			else:
				pos.x += side_off
			pos.y = 0.27
			# Model fronts face local +Z after glTF import; aim +Z at dir.
			var inst: Node3D = _place_model("res://assets/models/vending_machine.glb", root, pos, atan2(dir.x, dir.z))
			if inst != null:
				inst.name = "Vending"
				_apply_vending_glass(inst)
				_add_collider(inst, Vector3(0.95, 1.95, 0.8), Vector3(0, 0.97, 0))
				vend_left -= 1
		if totem_left > 0 and rng.randf() < 0.26:
			var sx: float = 1.0 if rng.randf() < 0.5 else -1.0
			var sz: float = 1.0 if rng.randf() < 0.5 else -1.0
			var off := Vector3(sx * (half - 2.0), 0, sz * (half - 2.0))
			var pos2: Vector3 = center + off
			pos2.y = 0.27
			var inst2: Node3D = _place_model("res://assets/models/holo_totem.glb", root, pos2, atan2(off.x, off.z))
			if inst2 != null:
				inst2.name = "HoloTotem"
				_add_collider(inst2, Vector3(0.9, 3.2, 0.55), Vector3(0, 1.6, 0))
				totem_left -= 1
	# Traffic lights at selected intersections (arm reaches over the road).
	var spots: Array = [[-3, -3], [-3, 0], [-3, 3], [0, -3], [0, 3], [3, -3],
		[3, 0], [3, 3], [-1, -1], [1, 1], [-1, 2], [2, -1]]
	var corners: Array = [[1, 1], [-1, 1], [1, -1], [-1, -1]]
	for k in range(spots.size()):
		var ij: Array = spots[k]
		var cn: Array = corners[k % corners.size()]
		var pos3 := Vector3(float(ij[0]) * BLOCK + float(cn[0]) * (ROAD_W * 0.5 + 1.7), 0.05,
			float(ij[1]) * BLOCK + float(cn[1]) * (ROAD_W * 0.5 + 1.7))
		var dir3 := Vector3(-float(cn[0]), 0, -float(cn[1])).normalized()
		# Arm extends along local +Z after glTF import; aim it at the centre.
		var inst3: Node3D = _place_model("res://assets/models/traffic_light.glb", root, pos3, atan2(dir3.x, dir3.z))
		if inst3 != null:
			inst3.name = "TrafficLight"
			_add_collider(inst3, Vector3(0.34, 3.6, 0.34), Vector3(0, 1.8, 0))

func _apply_vending_glass(node: Node) -> void:
	# The glTF exporter drops the display glass's alpha (it arrives as an
	# opaque dark material, hiding the drink rows), so re-apply a real
	# transparent material on the VendGlass surface here.
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for i in range(mi.mesh.get_surface_count()):
				var m: Material = mi.mesh.surface_get_material(i)
				if m != null and m.resource_name == "VendGlass":
					var g := StandardMaterial3D.new()
					g.albedo_color = Color(0.35, 0.6, 0.85, 0.28)
					g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					g.metallic = 0.1
					g.roughness = 0.08
					mi.set_surface_override_material(i, g)
	for c in node.get_children():
		_apply_vending_glass(c)

func _build_hero_towers() -> void:
	# Distinct silhouettes on the skyline so the city has landmarks, not
	# just scaled copies of the same box (the main v1 tell vs. Night City).
	var root := Node3D.new()
	root.name = "HeroTowers"
	add_child(root)
	var defs: Array = [
		["res://assets/models/hero_tower_a.glb", 0.35, 475.0, 1.25, 0.4],
		["res://assets/models/hero_tower_b.glb", 2.35, 490.0, 1.15, 1.2],
		["res://assets/models/hero_tower_c.glb", 4.15, 465.0, 1.30, 0.0],
		["res://assets/models/hero_tower_a.glb", 5.55, 525.0, 1.55, 2.1],
	]
	for d in defs:
		var ang: float = d[1]
		var r: float = d[2]
		var pos := Vector3(cos(ang) * r, 0, sin(ang) * r)
		_place_model(d[0], root, pos, float(d[4]), float(d[3]))

func _process(delta: float) -> void:
	_t += delta
	if holo != null:
		holo.rotation.y += delta * 0.25
	for s in _searchlights:
		(s["pivot"] as Node3D).rotation = Vector3(0.0, _t * 0.35 + float(s["phase"]), 0.4)
	if _mat_beacon != null:
		_mat_beacon.emission_energy_multiplier = 1.4 + (sin(_t * 2.2) * 0.5 + 0.5) * 2.8

# --- v2 facades: Blender ground-floor storefront kits + relief ---------

var street_prop_count: int = 0

func _build_street_props() -> void:
	# v2.5: Quaternius CC0 street props (Poly Pizza) — benches and
	# trash cans on the sidewalks, dumpsters at the curb.
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	var root := Node3D.new()
	root.name = "StreetProps"
	add_child(root)
	street_prop_count = 0
	for b in sidewalk_blocks:
		var c: Vector3 = b["center"]
		var half: float = float(b["half"])
		if rng.randf() < 0.5:
			var side: int = rng.randi() % 4
			var along: float = rng.randf_range(-half * 0.45, half * 0.45)
			var inset: float = half - 1.15
			var pos := Vector3(c.x, 0.27, c.z)
			var rot: float = 0.0
			# The Quaternius bench's seat faces its local -Z, so
			# these rotations point it out toward the street.
			match side:
				0:
					pos += Vector3(along, 0, -inset)
				1:
					pos += Vector3(along, 0, inset)
					rot = PI
				2:
					pos += Vector3(inset, 0, along)
					rot = -PI * 0.5
				3:
					pos += Vector3(-inset, 0, along)
					rot = PI * 0.5
			var bench: Node3D = ModelLoader.load_model("res://assets/props_q/bench.glb", "res://assets/props_data/bench.tres")
			if bench != null:
				bench.position = pos
				bench.rotation.y = rot
				bench.scale = Vector3.ONE * 2.7
				root.add_child(bench)
				_add_collider(bench, Vector3(0.66, 0.34, 0.32), Vector3(0, 0.15, 0))
				street_prop_count += 1
		if rng.randf() < 0.55:
			var sx: float = 1.0 if rng.randf() < 0.5 else -1.0
			var sz: float = 1.0 if rng.randf() < 0.5 else -1.0
			var can: Node3D = ModelLoader.load_model("res://assets/props_q/trashcan.glb", "res://assets/props_data/trashcan.tres")
			if can != null:
				can.position = Vector3(c.x + sx * (half - 1.2), 0.27, c.z + sz * (half - 1.2))
				can.rotation.y = rng.randf() * TAU
				root.add_child(can)
				_add_collider(can, Vector3(0.55, 0.75, 0.55), Vector3(0, 0.36, 0))
				street_prop_count += 1
	# Dumpsters at the curb, mid-block so they clear intersections
	# and the traffic lanes.
	for i in range(-N, N + 1):
		var c: float = i * BLOCK
		for j in range(-N, N):
			if rng.randf() >= 0.16:
				continue
			var t: float = j * BLOCK + BLOCK * 0.5 + rng.randf_range(-9.0, 9.0)
			var side2: float = 1.0 if rng.randf() < 0.5 else -1.0
			var dum: Node3D = ModelLoader.load_model("res://assets/props_q/dumpster.glb", "res://assets/props_data/dumpster.tres")
			if dum == null:
				continue
			if rng.randf() < 0.5:
				dum.position = Vector3(t, 0.07, c + side2 * (ROAD_W * 0.5 - 1.5))
				dum.rotation.y = 0.0 if side2 > 0.0 else PI
			else:
				dum.position = Vector3(c + side2 * (ROAD_W * 0.5 - 1.5), 0.07, t)
				dum.rotation.y = PI * 0.5 if side2 > 0.0 else -PI * 0.5
			dum.scale = Vector3.ONE * 0.85
			root.add_child(dum)
			_add_collider(dum, Vector3(2.4, 1.3, 2.0), Vector3(0, 0.65, 0))
			street_prop_count += 1

func _add_collider(inst: Node3D, size: Vector3, offset: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = offset
	body.add_child(cs)
	inst.add_child(body)

func _tint_sign(inst: Node, color: Color) -> void:
	if inst is MeshInstance3D:
		var mi := inst as MeshInstance3D
		if mi.mesh != null:
			for i in range(mi.mesh.get_surface_count()):
				var base: Material = mi.mesh.surface_get_material(i)
				if base != null and base.resource_name == "SignPanel":
					var nm := StandardMaterial3D.new()
					nm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					nm.albedo_color = color
					nm.resource_name = "SignPanel"
					mi.set_surface_override_material(i, nm)
	for c in inst.get_children():
		_tint_sign(c, color)

func _build_facade_kits() -> void:
	var holder := Node3D.new()
	holder.name = "FacadeKits"
	add_child(holder)
	var krng := RandomNumberGenerator.new()
	krng.seed = 777
	var placed: int = 0
	for blk in sidewalk_blocks:
		if placed >= 130:
			break
		var c: Vector3 = blk["center"]
		var d: float = Vector2(c.x, c.z).length()
		var sides: int = 1
		if d < 140.0:
			sides = krng.randi_range(3, 4)
		elif d < 240.0:
			sides = krng.randi_range(2, 3)
		else:
			sides = krng.randi_range(0, 2)
		var order: Array = [0, 1, 2, 3]
		order.shuffle()
		for si in range(mini(sides, 4)):
			if placed >= 130:
				break
			var inst: Node3D = ModelLoader.load_model("res://assets/models/facade_kit.glb")
			if inst == null:
				continue
			var jit: float = krng.randf_range(-7.0, 7.0)
			var off: float = 20.9
			match order[si]:
				0:
					inst.position = Vector3(c.x + jit, 0.27, c.z + off)
					inst.rotation.y = 0.0
				1:
					inst.position = Vector3(c.x + jit, 0.27, c.z - off)
					inst.rotation.y = PI
				2:
					inst.position = Vector3(c.x + off, 0.27, c.z + jit)
					inst.rotation.y = PI * 0.5
				3:
					inst.position = Vector3(c.x - off, 0.27, c.z + jit)
					inst.rotation.y = -PI * 0.5
			inst.scale.x = krng.randf_range(1.05, 1.5)
			inst.name = "FacadeKit"
			holder.add_child(inst)
			_add_collider(inst, Vector3(10.3, 3.8, 1.9), Vector3(0, 1.9, 0.45))
			var sign_col: Color = _district_neon_color(c, krng)
			_tint_sign(inst, sign_col)
			# Fake neon reflection pool on the ground in front.
			var pool := MeshInstance3D.new()
			var pqm := QuadMesh.new()
			pqm.size = Vector2(4.2, 6.0)
			pool.mesh = pqm
			pool.rotation.x = -PI * 0.5
			pool.position = Vector3(0, 0.03, 3.4)
			var pmat := StandardMaterial3D.new()
			pmat.albedo_texture = _glow_tex
			pmat.albedo_color = Color(sign_col.r, sign_col.g, sign_col.b, 0.20)
			pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			pmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			pool.material_override = pmat
			inst.add_child(pool)
			placed += 1

func _build_facade_relief() -> void:
	_tank_xforms.clear()
	var relief: Array[Transform3D] = []
	var signs: Array[Transform3D] = []
	var sign_cols: Array[Color] = []
	var rr := RandomNumberGenerator.new()
	rr.seed = 4243
	for b in _buildings:
		var c: Vector3 = b["center"]
		var fp: Vector2 = b["fp"]
		var h: float = b["height"]
		for i in range(rr.randi_range(1, 2)):
			var y: float = h * rr.randf_range(0.3, 0.75) + 0.27
			relief.append(Transform3D(Basis.from_scale(Vector3(fp.x + 0.7, 0.32, fp.y + 0.7)), Vector3(c.x, y, c.z)))
		for i in range(rr.randi_range(0, 3)):
			var side: int = rr.randi() % 4
			var y2: float = rr.randf_range(3.0, maxf(3.5, h - 2.0)) + 0.27
			var p := Vector3.ZERO
			var s := Vector3(0.95, 0.7, 0.55)
			match side:
				0:
					p = Vector3(c.x + rr.randf_range(-fp.x * 0.35, fp.x * 0.35), y2, c.z + fp.y * 0.5 + 0.28)
				1:
					p = Vector3(c.x + rr.randf_range(-fp.x * 0.35, fp.x * 0.35), y2, c.z - fp.y * 0.5 - 0.28)
				2:
					p = Vector3(c.x + fp.x * 0.5 + 0.28, y2, c.z + rr.randf_range(-fp.y * 0.35, fp.y * 0.35))
					s = Vector3(0.55, 0.7, 0.95)
				3:
					p = Vector3(c.x - fp.x * 0.5 - 0.28, y2, c.z + rr.randf_range(-fp.y * 0.35, fp.y * 0.35))
					s = Vector3(0.55, 0.7, 0.95)
			relief.append(Transform3D(Basis.from_scale(s), p))
		if rr.randf() < 0.6:
			var px: float = c.x + (fp.x * 0.5 + 0.12) * (1.0 if rr.randf() < 0.5 else -1.0)
			var pz: float = c.z + (fp.y * 0.5 + 0.12) * (1.0 if rr.randf() < 0.5 else -1.0)
			relief.append(Transform3D(Basis.from_scale(Vector3(0.16, h * 0.85, 0.16)), Vector3(px, h * 0.425 + 0.27, pz)))
		if rr.randf() < 0.55:
			var side2: int = rr.randi() % 4
			var y3: float = rr.randf_range(3.4, 5.2)
			var bp := Vector3.ZERO
			var bs := Vector3.ONE
			match side2:
				0:
					bp = Vector3(c.x + rr.randf_range(-fp.x * 0.3, fp.x * 0.3), y3, c.z + fp.y * 0.5 + 0.5)
					bs = Vector3(0.14, 1.5, 0.95)
				1:
					bp = Vector3(c.x + rr.randf_range(-fp.x * 0.3, fp.x * 0.3), y3, c.z - fp.y * 0.5 - 0.5)
					bs = Vector3(0.14, 1.5, 0.95)
				2:
					bp = Vector3(c.x + fp.x * 0.5 + 0.5, y3, c.z + rr.randf_range(-fp.y * 0.3, fp.y * 0.3))
					bs = Vector3(0.95, 1.5, 0.14)
				3:
					bp = Vector3(c.x - fp.x * 0.5 - 0.5, y3, c.z + rr.randf_range(-fp.y * 0.3, fp.y * 0.3))
					bs = Vector3(0.95, 1.5, 0.14)
			signs.append(Transform3D(Basis.from_scale(bs), bp))
			sign_cols.append(_district_neon_color(c, rr))
		# Rooftop props: vent boxes near the roof edge, water tanks.
		if rr.randf() < 0.5:
			var bw: float = rr.randf_range(1.6, 3.2)
			var bh: float = rr.randf_range(0.8, 1.5)
			relief.append(Transform3D(Basis.from_scale(Vector3(bw, bh, bw)),
				Vector3(c.x + fp.x * 0.36, h + 0.27 + bh * 0.5, c.z + fp.y * rr.randf_range(-0.25, 0.25))))
		if rr.randf() < 0.3:
			_tank_xforms.append(Transform3D(Basis.from_scale(Vector3.ONE),
				Vector3(c.x - fp.x * 0.33, h + 0.27 + 1.3, c.z - fp.y * 0.3)))
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = unit
	mm.instance_count = relief.size()
	for i in range(relief.size()):
		mm.set_instance_transform(i, relief[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "FacadeRelief"
	mmi.multimesh = mm
	mmi.material_override = _mat_dark_metal
	add_child(mmi)
	var mm2 := MultiMesh.new()
	mm2.transform_format = MultiMesh.TRANSFORM_3D
	mm2.use_colors = true
	mm2.mesh = unit
	mm2.instance_count = signs.size()
	for i in range(signs.size()):
		mm2.set_instance_transform(i, signs[i])
		mm2.set_instance_color(i, sign_cols[i])
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.vertex_color_use_as_albedo = true
	smat.albedo_color = Color(1, 1, 1)
	var mmi2 := MultiMeshInstance3D.new()
	mmi2.name = "BladeSigns"
	mmi2.multimesh = mm2
	mmi2.material_override = smat
	add_child(mmi2)
	if not _tank_xforms.is_empty():
		var tank_mesh := CylinderMesh.new()
		tank_mesh.top_radius = 1.05
		tank_mesh.bottom_radius = 1.05
		tank_mesh.height = 2.6
		var mm3 := MultiMesh.new()
		mm3.transform_format = MultiMesh.TRANSFORM_3D
		mm3.mesh = tank_mesh
		mm3.instance_count = _tank_xforms.size()
		for i in range(_tank_xforms.size()):
			mm3.set_instance_transform(i, _tank_xforms[i])
		var mmi3 := MultiMeshInstance3D.new()
		mmi3.name = "RoofTanks"
		mmi3.multimesh = mm3
		mmi3.material_override = _mat_dark_metal
		add_child(mmi3)

func _build_road_tiles() -> void:
	# Photo-PBR asphalt surface: 15 m tiles at UV scale 1 (one draw
	# call). Z-running roads skip intersection tiles (the X tile
	# covers them) so no two tiles are ever coplanar.
	road_tile_count = 0
	if _mat_asphalt_pbr == null:
		return
	var plane := PlaneMesh.new()
	plane.size = Vector2(15.0, 15.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = plane
	var xforms: Array[Transform3D] = []
	var cols: Array[Color] = []
	var rr := RandomNumberGenerator.new()
	rr.seed = 90210
	for i in range(-N, N + 1):
		var c: float = i * BLOCK
		for k in range(44):
			var a: float = -322.5 + 15.0 * float(k)
			var rot := Basis(Vector3.UP, PI * 0.5 * float(rr.randi() % 4))
			var tint: float = rr.randf_range(0.9, 1.04)
			xforms.append(Transform3D(rot, Vector3(a, 0.073, c)))
			cols.append(Color(tint, tint, tint * rr.randf_range(1.0, 1.05)))
			# Z tiles run on a half-tile-shifted grid: they butt
			# exactly against the crossing X strips (no overlap, no
			# gap); only the intersection tile itself is skipped.
			var za: float = -315.0 + 15.0 * float(k)
			if absf(za - roundf(za / BLOCK) * BLOCK) > 0.1:
				xforms.append(Transform3D(rot, Vector3(c, 0.073, za)))
				cols.append(Color(tint, tint, tint))
	mm.instance_count = xforms.size()
	for k in range(xforms.size()):
		mm.set_instance_transform(k, xforms[k])
		mm.set_instance_color(k, cols[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "RoadTiles"
	mmi.multimesh = mm
	mmi.material_override = _mat_asphalt_pbr
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	road_tile_count = xforms.size()

# --- v2.1: elevated expressway, skybridges, horizon hills ---------------

func _build_elevated() -> void:
	var holder := Node3D.new()
	holder.name = "Expressway"
	add_child(holder)
	var deck_y: float = 9.5
	# Deck, barriers and crossbeams are solid: flying cars land on the
	# deck and drive along it (v2.5 — the deck used to be visual-only).
	_box(holder, Vector3(11, 0.5, EXTENT * 2.0), Vector3(0, deck_y, 0), _mat_asphalt, true)
	for sx in [-1.0, 1.0]:
		_box(holder, Vector3(0.35, 0.75, EXTENT * 2.0), Vector3(sx * 5.4, deck_y + 0.55, 0), _mat_dark_metal, true)
		_box(holder, Vector3(0.18, 0.12, EXTENT * 2.0), Vector3(sx * 5.4, deck_y + 1.0, 0), _neon_mats[1])
	# Pillars on the avenue centre line: traffic lanes run at x = ±3.3,
	# so a 1.4 m pillar at x = 0 stays clear of AI traffic.
	for i in range(-10, 11):
		var pz: float = float(i) * 31.5
		_box(holder, Vector3(1.4, deck_y, 1.4), Vector3(0, deck_y * 0.5, pz), _mat_dark_metal, true)
		_box(holder, Vector3(10.6, 0.7, 1.1), Vector3(0, deck_y - 0.6, pz), _mat_dark_metal, true)
	# Underpass light strips so the avenue below reads as a lit underpass.
	for z in range(-320, 321, 16):
		_box(holder, Vector3(2.4, 0.08, 0.5), Vector3(0, deck_y - 0.32, float(z)), _mat_bulb)
	# Skybridges between tall neighbours across a road.
	skybridge_count = 0
	var glass: Material = _mat(Color(0.09, 0.15, 0.23), 0.0, 0.3)
	(glass as StandardMaterial3D).metallic = 0.45
	var made: int = 0
	for i in range(_buildings.size()):
		if made >= 7:
			break
		var a: Dictionary = _buildings[i]
		if float(a["height"]) < 30.0:
			continue
		for j in range(i + 1, _buildings.size()):
			if made >= 7:
				break
			var b: Dictionary = _buildings[j]
			if float(b["height"]) < 30.0:
				continue
			var ca: Vector3 = a["center"]
			var cb: Vector3 = b["center"]
			var dx: float = absf(ca.x - cb.x)
			var dz: float = absf(ca.z - cb.z)
			var along_x: bool = dx > 50.0 and dx < 70.0 and dz < 12.0
			var along_z: bool = dz > 50.0 and dz < 70.0 and dx < 12.0
			if not along_x and not along_z:
				continue
			var y: float = minf(float(a["height"]), float(b["height"])) * 0.55
			var mid: Vector3 = (ca + cb) * 0.5
			mid.y = y
			var fa: Vector2 = a["fp"]
			var fb: Vector2 = b["fp"]
			if along_x:
				var len_x: float = dx - (fa.x + fb.x) * 0.5 + 1.5
				_box(holder, Vector3(len_x, 2.8, 2.6), mid, glass, true)
				_box(holder, Vector3(len_x, 0.18, 2.9), mid + Vector3(0, 1.5, 0), _district_neon_mat(mid))
			else:
				var len_z: float = dz - (fa.y + fb.y) * 0.5 + 1.5
				_box(holder, Vector3(2.6, 2.8, len_z), mid, glass, true)
				_box(holder, Vector3(2.9, 0.18, len_z), mid + Vector3(0, 1.5, 0), _district_neon_mat(mid))
			made += 1
	skybridge_count = made

func _build_hills() -> void:
	var holder := Node3D.new()
	holder.name = "Hills"
	add_child(holder)
	var hrng := RandomNumberGenerator.new()
	hrng.seed = 5150
	var hill_mat: Material = _mat(Color(0.02, 0.03, 0.07), 0.0, 1.0)
	for i in range(18):
		var ang: float = TAU * float(i) / 18.0 + hrng.randf_range(-0.08, 0.08)
		var dist: float = hrng.randf_range(430.0, 560.0)
		var hill := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 24
		sm.rings = 12
		hill.mesh = sm
		hill.scale = Vector3(hrng.randf_range(70.0, 130.0), hrng.randf_range(16.0, 38.0), hrng.randf_range(70.0, 130.0))
		hill.position = Vector3(cos(ang) * dist, -4.0, sin(ang) * dist)
		hill.material_override = hill_mat
		holder.add_child(hill)
