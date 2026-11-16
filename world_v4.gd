extends "res://city.gd"
## NEON CITY 2099 v4 world: the terrain is authored in Blender as ONE
## piece (blender/build_terrain_v4.py -> assets/terrain/terrain_v4.glb:
## ground plates, NE terraces, canal, road ribbons with sidewalks,
## plaza, bridges, skyway) and the buildings/props are assembled HERE
## in Godot from the layout data (layout_v4.gd, generated from the
## same script). Exposes the contract main.gd / minimap.gd use
## (build, poi_kiosks/terminals/pickups, sidewalk_blocks) plus
## traffic_loops, deck_loop, race_points, road_lines, map_extent.
## Inherits city.gd's material/kit/sign machinery.

var traffic_loops: Array = []   # Array of Array[Vector3] (street tours)
var deck_loop: Array = []       # Array[Vector3] skyway two-way tour
var race_points: Array[Vector3] = []
var road_lines: Array = []      # Array of [Vector3, Vector3] for the map
var map_extent: float = 240.0
var plot_count: int = 0
var terrain_ok: bool = false

var _layout: Dictionary = {}
# v4 optimization: roof caps + neon cornice strips are collected as
# transforms and emitted as TWO MultiMeshes (was ~5 MeshInstances
# per tower, ~800 nodes city-wide).
var _cap_xforms: Array[Transform3D] = []
var _strip_xforms: Array[Transform3D] = []
var _strip_colors: Array[Color] = []

func build(font: Font) -> void:
	_rng.seed = 4242
	_font = font
	_make_materials()
	_mat_pool.albedo_color = Color(0.35, 0.6, 0.85, 0.15)
	_make_bld_materials()
	_layout = LayoutV4.DATA
	_build_terrain()
	_build_plots()
	_build_heroes()
	_build_roof_multimeshes()
	_build_pois()
	_build_holo()
	_tone_holo()
	_build_skyline_v4()
	_build_sky()
	_build_boundary_v4()
	_compute_routes()
	_build_atmosphere()
	_build_plinth_v4()
	_build_plaza_marks()
	_build_air_traffic()
	_build_roadworks_v53()

## Dawn sky override: at 3:52 AM there are no visible stars — the
## pale light-polluted sky swallows them. Keep only a faint moon.
func _build_sky() -> void:
	var moon_pos := Vector3(-430, 305, -690)
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_texture = _glow_tex
	disc_mat.albedo_color = Color(0.9, 1.0, 1.15, 0.55)
	disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	disc_mat.disable_fog = true
	var disc := MeshInstance3D.new()
	var dq := QuadMesh.new()
	dq.size = Vector2(70, 70)
	disc.mesh = dq
	disc.material_override = disc_mat
	disc.position = moon_pos
	add_child(disc)

# --- terrain ---------------------------------------------------------

var _terrain_mat_cache: Dictionary = {}

func _ground_tex(prefix: String, suffix: String) -> Texture2D:
	return TextureLoader.load_tex(
		"res://assets/textures/%s_%s.jpg" % [prefix, suffix],
		"res://assets/texture_data/%s_%s.tres" % [prefix, suffix])

## Full PBR ground material from an ambientCG set: every map the
## set ships is connected — albedo, normal, roughness, AO (when
## the set includes one) and displacement as parallax heightmap.
## World-space triplanar mapping (the terrain mesh has no usable
## UVs), tinted into the dawn grade.
func _pbr_ground(prefix: String, scale: Vector3, tint: Color,
		normal_scale: float, height_scale: float, has_ao: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = _ground_tex(prefix, "color")
	m.albedo_color = tint
	m.texture_repeat = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_triplanar = true
	m.uv1_scale = scale
	m.normal_enabled = true
	m.normal_texture = _ground_tex(prefix, "normal")
	m.normal_scale = normal_scale
	m.roughness = 1.0
	m.roughness_texture = _ground_tex(prefix, "rough")
	if has_ao:
		m.ao_enabled = true
		m.ao_texture = _ground_tex(prefix, "ao")
		m.ao_light_affect = 0.55
	m.heightmap_enabled = true
	m.heightmap_texture = _ground_tex(prefix, "disp")
	m.heightmap_scale = height_scale
	return m

func _terrain_mat(name: String) -> StandardMaterial3D:
	if _terrain_mat_cache.has(name):
		return _terrain_mat_cache[name]
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	match name:
		"GroundMat":
			# Worn city floor: cracked asphalt (ambientCG Asphalt008).
			m = _pbr_ground("cracked", Vector3.ONE / 5.0, Color(0.52, 0.50, 0.44), 1.0, 1.0, true)
		"ApronMat":
			m.albedo_color = Color(0.04, 0.04, 0.07)
			m.roughness = 1.0
		"RoadMat":
			# ambientCG Asphalt006, 4 m tiles.
			m = _pbr_ground("asphalt", Vector3.ONE * 0.25, Color(0.55, 0.53, 0.48), 0.9, 0.7, true)
		"SideMat":
			# ambientCG Concrete034 (2:1 set, 5 m tiles).
			m = _pbr_ground("concrete", Vector3(0.2, 0.4, 0.4), Color(0.60, 0.59, 0.55), 0.7, 0.5, false)
		"PlazaMat":
			m = _pbr_ground("concrete", Vector3(1.0 / 6.0, 1.0 / 3.0, 1.0 / 3.0), Color(0.55, 0.54, 0.50), 0.7, 0.5, false)
		"WaterMat":
			m.albedo_color = Color(0.04, 0.22, 0.38)
			m.roughness = 0.18
			m.metallic = 0.65
			m.emission_enabled = true
			m.emission = Color(0.05, 0.3, 0.45)
			m.emission_energy_multiplier = 0.35
		"WallMat":
			m = _pbr_ground("concrete", Vector3(0.25, 0.5, 0.5), Color(0.55, 0.54, 0.50), 0.8, 0.6, false)
		"BankMat":
			m = _pbr_ground("cracked", Vector3.ONE / 3.5, Color(0.50, 0.49, 0.45), 1.25, 1.2, true)
		"DeckMat":
			m = _pbr_ground("asphalt", Vector3.ONE * 0.25, Color(0.46, 0.45, 0.42), 0.9, 0.7, true)
		"LineMat":
			m.albedo_color = Color(0.7, 0.74, 0.82)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_:
			m.albedo_color = Color(0.15, 0.15, 0.18)
	_terrain_mat_cache[name] = m
	return m

func _apply_terrain_mats(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.name == "PlazaDisc":
			# The holo plinth shipped with LineMat (pale) and read
			# as a white ellipse on device; a flat-black override
			# then read as a hole. Give it the plaza's own
			# concrete PBR (v4.3) — the cyan ring dressing is
			# added in _build_plinth_v4.
			mi.material_override = _terrain_mat("PlazaMat")
		elif mi.mesh != null:
			for i in range(mi.mesh.get_surface_count()):
				var sm: Material = mi.mesh.surface_get_material(i)
				if sm != null:
					mi.set_surface_override_material(i, _terrain_mat(sm.resource_name))
	for c in n.get_children():
		_apply_terrain_mats(c)

func _build_terrain() -> void:
	var inst: Node3D = ModelLoader.load_model(
		"res://assets/terrain/terrain_v4.glb",
		"res://assets/terrain_data/terrain_v4.tres")
	if inst == null:
		push_error("world_v4: terrain model failed to load")
		return
	_apply_terrain_mats(inst)
	add_child(inst)
	terrain_ok = true
	_build_collision()

## Collision is a heightfield sampled from the design functions, NOT
## the visual mesh: the authored terrain stacks coincident thin
## sheets (road ribbon + dashes + sidewalk + bank, all within ~15 cm)
## and CharacterBodies tunnel into the sandwich and wedge under a
## sheet (v24 climb debug). One sampled surface + solid boxes for
## the deck / bridges / pillars is robust everywhere.
func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	add_child(body)
	var step: float = 4.0
	var ext: float = 244.0
	var n: int = int(ext * 2.0 / step) + 1
	var faces := PackedVector3Array()
	var grid: Array = []
	for j in range(n):
		var row: Array = []
		for i in range(n):
			var x: float = -ext + float(i) * step
			var z: float = -ext + float(j) * step
			row.append(Vector3(x, _terrain_height(x, z), z))
		grid.append(row)
	for j in range(n - 1):
		for i in range(n - 1):
			var a: Vector3 = grid[j][i]
			var b: Vector3 = grid[j][i + 1]
			var c: Vector3 = grid[j + 1][i + 1]
			var d2: Vector3 = grid[j + 1][i]
			_push_face(faces, a, b, c)
			_push_face(faces, a, c, d2)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	# Skyway deck: one solid box per polyline segment.
	var dp: Array = _layout["deck"]
	for i in range(dp.size() - 1):
		var a := Vector2(float(dp[i][0]), float(dp[i][1]))
		var b := Vector2(float(dp[i + 1][0]), float(dp[i + 1][1]))
		var mid: Vector2 = (a + b) * 0.5
		var seg := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(a.distance_to(b) + 1.0, 0.75, 11.0)
		seg.shape = bs
		seg.position = Vector3(mid.x, 9.675, mid.y)
		seg.rotation.y = -atan2(b.y - a.y, b.x - a.x)
		body.add_child(seg)
	# Deck pillars (exported from the Blender build).
	for p in _layout["pillars"]:
		var px: float = float(p[0])
		var pz: float = float(p[1])
		var g: float = _terrain_height(px, pz)
		var pil := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.9
		cyl.height = 9.3 - g
		pil.shape = cyl
		pil.position = Vector3(px, g + (9.3 - g) * 0.5, pz)
		body.add_child(pil)

func _height_smooth_gd(x: float, z: float) -> float:
	var best: float = 0.0
	for t in [[66.0, -219.0, 219.0, -76.0, 6.0],
			[104.0, -219.0, 219.0, -114.0, 12.0],
			[142.0, -219.0, 219.0, -152.0, 18.0]]:
		var dx: float = maxf(maxf(t[0] - x, 0.0), x - t[2])
		var dz: float = maxf(maxf(t[1] - z, 0.0), z - t[3])
		var d: float = Vector2(dx, dz).length()
		if d <= 0.0:
			best = maxf(best, t[4])
		elif d < 20.0:
			var s: float = 1.0 - d / 20.0
			best = maxf(best, t[4] * (s * s * (3.0 - 2.0 * s)))
	return best

func _canal_dist(x: float, z: float) -> float:
	var pts: Array = _layout["canal"]
	var best: float = 1e9
	for i in range(pts.size() - 1):
		var a := Vector2(float(pts[i][0]), float(pts[i][1]))
		var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
		var ab: Vector2 = b - a
		var tt: float = clampf((Vector2(x, z) - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, Vector2(x, z).distance_to(a + ab * tt))
	return best

func _terrain_height(x: float, z: float) -> float:
	var h: float = _height_smooth_gd(x, z)
	if absf(x) <= 34.0 and absf(z) <= 34.0:
		h = maxf(h, 0.06)
	var dc: float = _canal_dist(x, z)
	if dc < 13.5:
		var t: float = clampf((dc - 8.5) / 5.0, 0.0, 1.0)
		var ch: float = lerpf(-2.7, h, t * t * (3.0 - 2.0 * t))
		h = minf(h, ch)
	# Bridges carry the road over the canal at deck height 0.16.
	for bx in [-146.0, 0.0, 121.0]:
		if absf(x - bx) < 5.5 and z > 160.0 and z < 199.0:
			h = maxf(h, 0.16)
	return h

## Append one collision triangle. Godot physics treats a triangle
## as front-facing when it winds CLOCKWISE seen from its outward
## side — i.e. the right-hand-rule normal (b-a)x(c-a) must point
## INWARD (down, for terrain tops). Faces wound the other way are
## ghosts: rays and bodies pass through them (proven by minimal
## repro, tests/v24_miniprobe.gd). So flip shallow faces until
## their RH normal points down.
func _push_face(faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.y > 0.0 and absf(n.y) > 0.5 * n.length():
		faces.append(a)
		faces.append(c)
		faces.append(b)
	else:
		faces.append(a)
		faces.append(b)
		faces.append(c)

func _ground_y(x: float, z: float) -> float:
	if x >= 142.0 and z <= -152.0:
		return 18.0
	if x >= 104.0 and z <= -114.0:
		return 12.0
	if x >= 66.0 and z <= -76.0:
		return 6.0
	if absf(x) <= 34.0 and absf(z) <= 34.0:
		return 0.06
	return 0.0

# --- Phase 2: Blender-modelled buildings ------------------------------

var _bld_mats: Dictionary = {}
var far_lod_count: int = 0
var model_building_count: int = 0

func _make_bld_materials() -> void:
	# Window facades are unshaded night textures (the photo-tower
	# lesson: the texture IS the lighting). UVs are in metres and
	# the texture repeats, so windows keep a constant real size.
	for pair in [["BldEntA", "win_ent_a"], ["BldEntB", "win_ent_b"],
			["BldKitA", "win_kit_a"], ["BldKitB", "win_kit_b"],
			["BldMilA", "win_mil_a"], ["BldMilB", "win_mil_b"]]:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = TextureLoader.load_tex(
			"res://assets/textures/" + pair[1] + ".jpg",
			"res://assets/texture_data/" + pair[1] + ".tres")
		m.texture_repeat = true  # Godot 4.6: bool (repeat sampling)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_bld_mats[pair[0]] = m
		# Baked per-face shading variants (generator assigns these
		# to side / back faces): same texture, tinted albedo.
		for suffix in ["S", "B"]:
			var vm := StandardMaterial3D.new()
			vm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			vm.albedo_texture = m.albedo_texture
			vm.texture_repeat = true
			vm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			vm.albedo_color = Color(0.74, 0.74, 0.78) if suffix == "S" else Color(0.52, 0.52, 0.58)
			_bld_mats[pair[0] + suffix] = vm
	var glass := StandardMaterial3D.new()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.albedo_color = Color(0.13, 0.20, 0.25)
	_bld_mats["BldGlass"] = glass
	# v5: lit shopfront glass — interiors glow warm, so the ground
	# floor reads as open businesses, not black voids (portrait
	# PDCA, v49_c).
	var glass_lit := StandardMaterial3D.new()
	glass_lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass_lit.albedo_color = Color(0.44, 0.34, 0.20)
	_bld_mats["BldGlassLit"] = glass_lit
	_bld_mats["BldDark"] = _mat_dark_metal
	_bld_mats["BldRoof"] = _mat_roof
	var conc := StandardMaterial3D.new()
	conc.albedo_color = Color(0.34, 0.35, 0.38)
	conc.roughness = 0.95
	_bld_mats["BldConc"] = conc
	var plas := StandardMaterial3D.new()
	plas.albedo_color = Color(0.05, 0.55, 0.59)
	plas.roughness = 0.5
	_bld_mats["BldPlas"] = plas
	var plas2 := StandardMaterial3D.new()
	plas2.albedo_color = Color(0.72, 0.38, 0.47)
	plas2.roughness = 0.5
	_bld_mats["BldPlas2"] = plas2
	var yel := StandardMaterial3D.new()
	yel.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	yel.albedo_color = Color(0.99, 0.93, 0.04)
	_bld_mats["BldYel"] = yel
	for pair in [["SignC", Color(0.1, 0.95, 1.0)], ["SignP", Color(1.0, 0.25, 0.65)],
			["SignY", Color(0.99, 0.93, 0.04)], ["SignW", Color(0.92, 0.96, 1.0)]]:
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.albedo_color = pair[1]
		_bld_mats[pair[0]] = sm

func _apply_bld_mats(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for i in range(mi.mesh.get_surface_count()):
				var m: Material = mi.mesh.surface_get_material(i)
				if m != null and _bld_mats.has(m.resource_name):
					mi.set_surface_override_material(i, _bld_mats[m.resource_name])
	for c in n.get_children():
		_apply_bld_mats(c)

func _set_vis(n: Node, begin: float, end: float) -> void:
	if n is GeometryInstance3D:
		var gi := n as GeometryInstance3D
		gi.visibility_range_begin = begin
		gi.visibility_range_end = end
	for c in n.get_children():
		_set_vis(c, begin, end)

# --- buildings on layout plots ---------------------------------------

func _build_plots() -> void:
	for p in _layout["plots"]:
		var plot: Dictionary = p
		var center := Vector3(float(plot["x"]), float(plot["y"]), float(plot["z"]))
		_place_building_v4(plot, center)
		plot_count += 1

func _place_building_v4(plot: Dictionary, center: Vector3) -> void:
	var style: String = String(plot["style"])
	var target_h: float = float(plot["h"])
	# Pick the archetype whose authored height is closest (log
	# scale); much-taller-than-plot models are penalised so a low
	# plot never grows a tower. The a/b pick is a stable hash of
	# the plot position, so the city is identical every run.
	var best_score: float = 1.0e9
	var tie: Array[String] = []
	for key in BldManifest.DATA.keys():
		var e: Dictionary = BldManifest.DATA[key]
		if String(e["style"]) != style:
			continue
		var fh: float = float(e["h"])
		var score: float = absf(log(target_h / fh))
		if fh > target_h * 1.25:
			score += 2.0
		if score < best_score - 0.001:
			best_score = score
			tie = [String(key)]
		elif absf(score - best_score) <= 0.001:
			tie.append(String(key))
	if tie.is_empty():
		_add_tower_v4(plot, center)
		return
	var hv: int = int(absf(center.x * 131.0 + center.z * 17.0)) % tie.size()
	var bname: String = tie[hv]
	var entry: Dictionary = BldManifest.DATA[bname]
	var inst: Node3D = ModelLoader.load_model(
		"res://assets/bld/" + bname + ".glb",
		"res://assets/bld_data/" + bname + ".tres")
	if inst == null:
		_add_tower_v4(plot, center)
		return
	_apply_bld_mats(inst)
	var fw: float = float(entry["w"])
	var fd: float = float(entry["d"])
	var fh2: float = float(entry["h"])
	var sx: float = float(plot["w"]) / fw
	var sz: float = float(plot["d"]) / fd
	var sy: float = clampf(target_h / fh2, 0.9, 1.15)
	inst.position = center
	inst.rotation.y = float(plot["rot"])
	inst.scale = Vector3(sx, sy, sz)
	inst.name = bname
	add_child(inst)
	if bool(entry["far"]):
		_set_vis(inst, 0.0, 125.0)  # v5: richer near models; swap a bit sooner (fog hides it)
		var finst: Node3D = ModelLoader.load_model(
			"res://assets/bld/" + bname + "_far.glb",
			"res://assets/bld_data/" + bname + "_far.tres")
		if finst != null:
			_apply_bld_mats(finst)
			finst.position = center
			finst.rotation.y = float(plot["rot"])
			finst.scale = Vector3(sx, sy, sz)
			finst.name = bname + "_far"
			add_child(finst)
			_set_vis(finst, 120.0, 0.0)
			far_lod_count += 1
	# Local-space collider: the parent instance carries the scale.
	_add_collider(inst, Vector3(fw, fh2, fd), Vector3(0, fh2 * 0.5, 0))
	_buildings.append({"center": center, "fp": Vector2(float(plot["w"]), float(plot["d"])),
		"height": fh2 * sy, "rot": float(plot["rot"])})
	kit_building_count += 1
	model_building_count += 1
	# Register a wet-street reflection spot at the front face.
	var dir2 := Vector2(sin(float(plot["rot"])), cos(float(plot["rot"])))
	_sign_spots_v4.append({
		"pos": center + Vector3(dir2.x, 0, dir2.y) * (fd * sz * 0.5),
		"dir": dir2, "color": _district_neon_color(center, _rng)})

func _add_tower_v4(plot: Dictionary, center: Vector3) -> void:
	var w: float = float(plot["w"])
	var d: float = float(plot["d"])
	var height: float = float(plot["h"])
	var root := Node3D.new()
	root.position = center
	root.rotation.y = float(plot["rot"])
	root.name = "TowerV4"
	add_child(root)
	var wm: StandardMaterial3D = (_window_mats[_rng.randi() % _window_mats.size()] as StandardMaterial3D).duplicate() as StandardMaterial3D
	var bright: float = _rng.randf_range(0.72, 1.12)
	wm.albedo_color = Color(bright * _rng.randf_range(0.9, 1.06), bright, bright * _rng.randf_range(0.9, 1.1))
	var neon: Material = _district_neon_mat(center)
	var trim: Material = neon if _rng.randf() < 0.35 else _mat_dark_metal
	var photo: bool = not _photo_mats.is_empty() and height >= 19.0 and w <= 31.0 and d <= 31.0 and _rng.randf() < 0.42
	if photo:
		photo_building_count += 1
		var pm: Material = _photo_mats[_rng.randi() % _photo_mats.size()]
		var segs: int = int(ceil(height / 13.0))
		var seg_h: float = height / float(segs)
		for s in range(segs):
			var seg: MeshInstance3D = _box(root, Vector3(w, seg_h, d), Vector3(0, seg_h * (float(s) + 0.5), 0), pm)
			if s % 2 == 1:
				seg.rotation.y = PI
		_box(root, Vector3(w - 0.04, height, d - 0.04), Vector3(0, height * 0.5, 0), _mat_dark_metal, true)
	else:
		_box(root, Vector3(w, height, d), Vector3(0, height * 0.5, 0), wm, true)
	# Ground-floor storefront band on the +Z face (v3 discipline:
	# the street level is always lit, the mass above stays dark).
	_box(root, Vector3(w * 0.92, 3.1, 0.18), Vector3(0, 1.55, d * 0.5 + 0.06), _mat_dark_metal)
	_box(root, Vector3(w * 0.8, 2.2, 0.14), Vector3(0, 1.45, d * 0.5 + 0.16), neon)
	_roof_finish_local(root, Vector2(w, d), height, trim)
	if not photo and height > 34.0:
		var h2: float = height * _rng.randf_range(0.22, 0.4)
		var fp2 := Vector2(w, d) * _rng.randf_range(0.55, 0.72)
		_box(root, Vector3(fp2.x, h2, fp2.y), Vector3(0, height + h2 * 0.5, 0), wm, true)
		_roof_finish_local(root, fp2, height + h2, trim)
	# Detail nodes (antennas, billboards, wall signs, labels) get a
	# visibility range: past 170 m they are unreadable at night but
	# each still costs a draw call in long avenue/flight views.
	if height > 38.0:
		var ant := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.14
		cyl.height = _rng.randf_range(3.5, 6.5)
		ant.mesh = cyl
		ant.position = Vector3(0, height + cyl.height * 0.5, 0)
		ant.material_override = _mat_dark_metal
		ant.visibility_range_end = 170.0
		root.add_child(ant)
		var bec := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.3
		sph.height = 0.6
		bec.mesh = sph
		bec.position = Vector3(0, height + cyl.height + 0.3, 0)
		bec.material_override = _mat_beacon
		bec.visibility_range_end = 170.0
		root.add_child(bec)
	if height > 36.0 and _rng.randf() < 0.5:
		var bw: float = _rng.randf_range(9.0, 13.0)
		var bh: float = bw * 1.9
		var plane := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(bw, bh)
		plane.mesh = qm
		plane.position = Vector3(0, height * 0.58, d * 0.5 + 0.18)
		plane.material_override = _billboard_mats[billboard_count % _billboard_mats.size()]
		plane.visibility_range_end = 170.0
		root.add_child(plane)
		billboard_count += 1
		if _font != null:
			var blab := Label3D.new()
			blab.text = BILLBOARD_BRANDS[billboard_count % BILLBOARD_BRANDS.size()]
			blab.font = _font
			blab.font_size = 144
			blab.pixel_size = 0.016
			blab.modulate = Color(1, 1, 1)
			blab.outline_size = 10
			blab.position = Vector3(0, height * 0.58 + bh * 0.3, d * 0.5 + 0.33)
			blab.visibility_range_end = 170.0
			root.add_child(blab)
	if _rng.randf() < 0.35:
		var ssize := Vector3(1.6, _rng.randf_range(3.0, 5.5), 0.3)
		var spos := Vector3(w * 0.5 + 0.2, _rng.randf_range(6.0, maxf(7.0, height * 0.55)), 0)
		var sign_box: MeshInstance3D = _box(root, ssize, spos, neon)
		sign_box.visibility_range_end = 170.0
		if _font != null and _rng.randf() < 0.6:
			var lab := Label3D.new()
			lab.text = SIGN_WORDS[_rng.randi() % SIGN_WORDS.size()]
			lab.font = _font
			lab.font_size = 96
			lab.pixel_size = 0.011
			lab.modulate = Color(1, 1, 1)
			lab.outline_size = 8
			lab.position = spos + Vector3(0.25, 0, 0)
			lab.rotation.y = PI * 0.5
			lab.visibility_range_end = 170.0
			root.add_child(lab)
	_buildings.append({"center": center, "fp": Vector2(w, d), "height": height})

func _roof_finish_local(root: Node3D, fp: Vector2, top_y: float, neon: Material) -> void:
	# Collect into the roof MultiMeshes instead of spawning boxes:
	# instance transform = root transform * (scale=size, offset=pos).
	var rt := Transform3D(Basis.from_euler(Vector3(0, root.rotation.y, 0)), root.position)
	var col: Color = (neon as StandardMaterial3D).albedo_color
	_cap_xforms.append(rt * Transform3D(Basis.from_scale(Vector3(fp.x + 0.2, 0.12, fp.y + 0.2)), Vector3(0, top_y - 0.04, 0)))
	var t: float = 0.4
	var y: float = top_y + 0.05
	var locals: Array = [
		[Vector3(fp.x + 0.55, 0.16, t), Vector3(0, y, -fp.y * 0.5 - 0.05)],
		[Vector3(fp.x + 0.55, 0.16, t), Vector3(0, y, fp.y * 0.5 + 0.05)],
		[Vector3(t, 0.16, fp.y + 0.55), Vector3(-fp.x * 0.5 - 0.05, y, 0)],
		[Vector3(t, 0.16, fp.y + 0.55), Vector3(fp.x * 0.5 + 0.05, y, 0)],
	]
	for pair in locals:
		_strip_xforms.append(rt * Transform3D(Basis.from_scale(pair[0]), pair[1]))
		_strip_colors.append(col)

func _build_roof_multimeshes() -> void:
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	if not _cap_xforms.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = unit
		mm.instance_count = _cap_xforms.size()
		for i in range(_cap_xforms.size()):
			mm.set_instance_transform(i, _cap_xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "RoofCaps"
		mmi.multimesh = mm
		mmi.material_override = _mat_roof
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	if not _strip_xforms.is_empty():
		var smat := StandardMaterial3D.new()
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.vertex_color_use_as_albedo = true
		smat.albedo_color = Color(1, 1, 1)
		var mm2 := MultiMesh.new()
		mm2.transform_format = MultiMesh.TRANSFORM_3D
		mm2.use_colors = true
		mm2.mesh = unit
		mm2.instance_count = _strip_xforms.size()
		for i in range(_strip_xforms.size()):
			mm2.set_instance_transform(i, _strip_xforms[i])
			mm2.set_instance_color(i, _strip_colors[i])
		var mmi2 := MultiMeshInstance3D.new()
		mmi2.name = "RoofCornices"
		mmi2.multimesh = mm2
		mmi2.material_override = smat
		mmi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi2)

## v4 skyline: same ring of backdrop mega-towers as city.gd's, but
## grouped into one MultiMesh per window material (was ~70 nodes,
## and the antennas/beacons are sub-pixel at 425 m+ — dropped).
var _skyline_dark: Dictionary = {}

func _build_searchlights() -> void:
	# v4.2: the v2.3 searchlight cones read as geometry errors on
	# the authored terrain (a bright wedge/disc where the tilted
	# additive cone crosses the view — his iPhone photo 4 and the
	# v47 bisect). Cut for v4; the city's light comes from signs,
	# lamps and screens instead.
	pass

func _build_skyline_v4() -> void:
	var by_mat: Dictionary = {}
	var cornice_xf: Array[Transform3D] = []
	var cornice_col: Array[Color] = []
	var idx: int = 0
	var ang: float = 0.0
	while ang < TAU:
		var r: float = _rng.randf_range(425.0, 540.0)
		var pos := Vector3(cos(ang) * r, 0, sin(ang) * r)
		var w: float = _rng.randf_range(28.0, 58.0)
		var h: float = _rng.randf_range(55.0, 165.0)
		if idx % 9 == 4:
			h = _rng.randf_range(180.0, 235.0)
		var src_wm: StandardMaterial3D = _window_mats[_rng.randi() % _window_mats.size()]
		if not _skyline_dark.has(src_wm):
			var dm: StandardMaterial3D = src_wm.duplicate()
			dm.albedo_color = Color(0.30, 0.34, 0.42)
			_skyline_dark[src_wm] = dm
		var wm: StandardMaterial3D = _skyline_dark[src_wm]
		var rot: float = _rng.randf() * PI
		var xf := Transform3D(Basis.from_euler(Vector3(0, rot, 0)) * Basis.from_scale(Vector3(w, h, w)), Vector3(pos.x, h * 0.5, pos.z))
		if not by_mat.has(wm):
			by_mat[wm] = []
		(by_mat[wm] as Array).append(xf)
		if _rng.randf() < 0.22:
			var nm: StandardMaterial3D = _neon_mats[_rng.randi() % _neon_mats.size()]
			cornice_xf.append(Transform3D(Basis.from_euler(Vector3(0, rot, 0)) * Basis.from_scale(Vector3(w + 0.6, 0.5, w + 0.6)), Vector3(pos.x, h + 0.3, pos.z)))
			var nc: Color = nm.albedo_color
			cornice_col.append(Color(nc.r * 0.65, nc.g * 0.65, nc.b * 0.65))
		ang += _rng.randf_range(0.10, 0.17)
		idx += 1
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	for wm in by_mat.keys():
		var arr: Array = by_mat[wm]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = unit
		mm.instance_count = arr.size()
		for i in range(arr.size()):
			mm.set_instance_transform(i, arr[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Skyline"
		mmi.multimesh = mm
		mmi.material_override = wm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	if not cornice_xf.is_empty():
		var smat := StandardMaterial3D.new()
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.vertex_color_use_as_albedo = true
		smat.albedo_color = Color(1, 1, 1)
		var mm2 := MultiMesh.new()
		mm2.transform_format = MultiMesh.TRANSFORM_3D
		mm2.use_colors = true
		mm2.mesh = unit
		mm2.instance_count = cornice_xf.size()
		for i in range(cornice_xf.size()):
			mm2.set_instance_transform(i, cornice_xf[i])
			mm2.set_instance_color(i, cornice_col[i])
		var mmi2 := MultiMeshInstance3D.new()
		mmi2.name = "SkylineCornices"
		mmi2.multimesh = mm2
		mmi2.material_override = smat
		mmi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi2)

# --- hero buildings ----------------------------------------------------

func _solid(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	# Collider-only box (no mesh): hero visuals come from Blender.
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)
	parent.add_child(body)

func _hero_model(parent: Node3D, bname: String) -> void:
	var inst: Node3D = ModelLoader.load_model(
		"res://assets/bld/" + bname + ".glb",
		"res://assets/bld_data/" + bname + ".tres")
	if inst != null:
		_apply_bld_mats(inst)
		inst.name = bname
		parent.add_child(inst)

func _build_heroes() -> void:
	var heroes: Dictionary = _layout["heroes"]
	# 1) Megabuilding north of the plaza (Blender hero_mega: three
	# stepped mil-glass tiers, courtyard glow frame, yellow cornice).
	var mg: Dictionary = heroes["mega"]
	var mroot := Node3D.new()
	mroot.position = Vector3(float(mg["x"]), 0, float(mg["z"]))
	mroot.name = "Megabuilding"
	add_child(mroot)
	_hero_model(mroot, "hero_mega")
	_solid(mroot, Vector3(104, 38, 56), Vector3(0, 19, 0))
	_solid(mroot, Vector3(84, 34, 44), Vector3(0, 38 + 17, 0))
	_solid(mroot, Vector3(60, 38, 32), Vector3(0, 72 + 19, 0))
	if _font != null:
		var lab := Label3D.new()
		lab.text = "キバラ・ワン"
		lab.font = _font
		lab.font_size = 200
		lab.pixel_size = 0.02
		lab.modulate = Color(1.0, 0.93, 0.25)
		lab.outline_size = 12
		lab.position = Vector3(0, 34.2, 28.45)
		mroot.add_child(lab)
	# The mega's "face": a big ad screen + vertical sign strips on
	# the spawn-facing front, with a light pool spilling onto the
	# plaza — in the reference, screens are the landmarks, not
	# window grids.
	_box(mroot, Vector3(27, 11.5, 0.3), Vector3(17, 20, 28.25), _billboard_mats[1])
	_box(mroot, Vector3(1.15, 17, 0.3), Vector3(-33, 22, 28.25), _bld_mats["SignP"])
	_box(mroot, Vector3(1.15, 12.5, 0.3), Vector3(-38.5, 19.5, 28.25), _bld_mats["SignC"])
	var pool := MeshInstance3D.new()
	var pq := PlaneMesh.new()
	pq.size = Vector2(34, 12)
	pool.mesh = pq
	pool.position = Vector3(17, 0.16, 35)
	pool.material_override = _mat_pool
	mroot.add_child(pool)
	_buildings.append({"center": mroot.position, "fp": Vector2(104, 56), "height": 110.0, "fixed": true})
	# 2) Arch building straddling the SW diagonal avenue (Blender
	# hero_arch: entropism legs + slab, cyan under-glow).
	var ar: Dictionary = heroes["arch"]
	var aroot := Node3D.new()
	aroot.position = Vector3(float(ar["x"]), 0, float(ar["z"]))
	aroot.rotation.y = float(ar["rot"])
	aroot.name = "ArchBuilding"
	add_child(aroot)
	_hero_model(aroot, "hero_arch")
	_solid(aroot, Vector3(26, 26, 9), Vector3(0, 13, -13.5))
	_solid(aroot, Vector3(26, 26, 9), Vector3(0, 13, 13.5))
	_solid(aroot, Vector3(30, 8, 36), Vector3(0, 30, 0))
	_solid(aroot, Vector3(24, 6, 28), Vector3(0, 37, 0))
	_buildings.append({"center": aroot.position, "fp": Vector2(30, 36), "height": 40.0, "fixed": true})
	# 3) Cylinder tower east of the plaza (Blender hero_cyl: wrapped
	# mil-glass drum, balcony rings, one cyan).
	var cy: Dictionary = heroes["cylinder"]
	var croot := Node3D.new()
	croot.position = Vector3(float(cy["x"]), 0, float(cy["z"]))
	croot.name = "CylinderTower"
	add_child(croot)
	_hero_model(croot, "hero_cyl")
	var cbody := StaticBody3D.new()
	var ccs := CollisionShape3D.new()
	var csh := CylinderShape3D.new()
	csh.radius = float(cy["r"])
	csh.height = float(cy["h"])
	ccs.shape = csh
	ccs.position.y = float(cy["h"]) * 0.5
	cbody.add_child(ccs)
	croot.add_child(cbody)
	_buildings.append({"center": croot.position, "fp": Vector2(28, 28), "height": float(cy["h"])})

# --- POIs ---------------------------------------------------------------

func _build_pois() -> void:
	var pois: Dictionary = _layout["pois"]
	for k in pois["kiosks"]:
		_add_kiosk(Vector3(float(k[0]), _ground_y(float(k[0]), float(k[2])), float(k[2])))
	for t in pois["terminals"]:
		var tp := Vector3(float(t[0]), _ground_y(float(t[0]), float(t[2])), float(t[2]))
		poi_terminals.append(tp)
		_add_terminal(tp)
	for p in pois["pickups"]:
		poi_pickups.append(Vector3(float(p[0]), _ground_y(float(p[0]), float(p[2])) + 0.05, float(p[2])))
	for wb in _layout["walk_blocks"]:
		sidewalk_blocks.append({
			"center": Vector3(float(wb["cx"]), float(wb["y"]) - 0.27, float(wb["cz"])),
			"half": float(wb["half"]),
		})
	# Clinic visual (respawn point): low white block + red cross,
	# east of the plaza.
	var clinic := Node3D.new()
	clinic.position = Vector3(46, 0, 16)
	clinic.name = "Clinic"
	add_child(clinic)
	_box(clinic, Vector3(10, 5, 8), Vector3(0, 2.5, 0), _mat(Color(0.55, 0.58, 0.62), 0.0, 0.6), true)
	_box(clinic, Vector3(0.5, 2.4, 0.5), Vector3(-5.2, 6.2, 0), _mat(Color(1, 0.15, 0.2), 2.2, 0.4))
	_box(clinic, Vector3(0.5, 0.5, 2.4), Vector3(-5.2, 6.2, 0), _mat(Color(1, 0.15, 0.2), 2.2, 0.4))
	if _font != null:
		var lab := Label3D.new()
		lab.text = "クリニック"
		lab.font = _font
		lab.font_size = 72
		lab.pixel_size = 0.01
		lab.modulate = Color(1, 1, 1)
		lab.position = Vector3(-5.4, 3.4, 0)
		lab.rotation.y = -PI * 0.5
		clinic.add_child(lab)

func _build_boundary_v4() -> void:
	var body := StaticBody3D.new()
	body.name = "BoundaryV4"
	add_child(body)
	for spec in [
		[Vector3(4, 150, 496), Vector3(237, 62, 0)],
		[Vector3(4, 150, 496), Vector3(-237, 62, 0)],
		[Vector3(496, 150, 4), Vector3(0, 62, 237)],
		[Vector3(496, 150, 4), Vector3(0, 62, -237)],
	]:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = spec[0]
		cs.shape = sh
		cs.position = spec[1]
		body.add_child(cs)

# --- routes for traffic / minimap / races -------------------------------

func _compute_routes() -> void:
	var by_name: Dictionary = {}
	for r in _layout["roads"]:
		var pts: Array = r["pts"]
		by_name[String(r["name"])] = pts
		for i in range(pts.size() - 1):
			road_lines.append([Vector3(float(pts[i][0]), 0, float(pts[i][1])),
				Vector3(float(pts[i + 1][0]), 0, float(pts[i + 1][1]))])
	# canal + deck read as routes on the map too
	var canal: Array = _layout["canal"]
	for i in range(canal.size() - 1):
		road_lines.append([Vector3(float(canal[i][0]), 0, float(canal[i][1])),
			Vector3(float(canal[i + 1][0]), 0, float(canal[i + 1][1]))])
	var ring: Array = by_name["ring"]
	var tour: Array = []
	for p in ring:
		tour.append(Vector3(float(p[0]), 0, float(p[1])))
	var rev: Array = tour.duplicate()
	rev.reverse()
	traffic_loops = [tour, rev]
	# Skyway: two-way tour, offset to each side of the deck centreline.
	var dp: Array = _layout["deck"]
	var fwd: Array = []
	var back: Array = []
	for i in range(dp.size()):
		var a: Array = dp[maxi(0, i - 1)]
		var b: Array = dp[mini(dp.size() - 1, i + 1)]
		var dir := Vector2(float(b[0]) - float(a[0]), float(b[1]) - float(a[1])).normalized()
		var perp := Vector2(-dir.y, dir.x)
		fwd.append(Vector3(float(dp[i][0]) + perp.x * 2.9, 0, float(dp[i][1]) + perp.y * 2.9))
		back.append(Vector3(float(dp[i][0]) - perp.x * 2.9, 0, float(dp[i][1]) - perp.y * 2.9))
	back.reverse()
	deck_loop = fwd + back
	for rp in _layout["race_points"]:
		race_points.append(Vector3(float(rp[0]), _ground_y(float(rp[0]), float(rp[1])) + 0.5, float(rp[1])))

# --- Phase 2.5: atmosphere (light, haze, reflections) ----------------
# The reference look: buildings are dark masses, the LIGHT comes
# from signs, screens and street lamps — and wet asphalt stretches
# that light toward the viewer. All of it is faked cheaply:
# additive streak/pool MultiMeshes, sprite steam, no real lights.

var _sign_spots_v4: Array = []
var lamp_count: int = 0
var gantry_count: int = 0
var streak_count_v4: int = 0
var steam_count_v4: int = 0

func _streak_texture() -> ImageTexture:
	var img := Image.create(16, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		var a: float = pow(1.0 - float(y) / 127.0, 1.6)
		for x in range(16):
			var edge: float = 1.0 - absf(float(x) / 15.0 - 0.5) * 1.7
			img.set_pixel(x, y, Color(1, 1, 1, a * clampf(edge, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

func _build_atmosphere() -> void:
	# The mega's ad screen spills cyan light across the plaza.
	for sx in [4.0, 17.0, 30.0]:
		_sign_spots_v4.append({"pos": Vector3(sx, 0, 28.6),
			"dir": Vector2(0, 1), "color": Color(0.35, 0.8, 1.0)})
	_build_streaks_v4()
	_build_lamps_v4()
	_build_steam_v4()
	_build_gantries_v4()
	_build_blade_signs_v4()
	_build_rooftops_v4()
	_build_cables_v4()

func _build_streaks_v4() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _streak_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 1, 1)
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var srng := RandomNumberGenerator.new()
	srng.seed = 909
	for spot in _sign_spots_v4:
		var dir2: Vector2 = spot["dir"]
		var base: Vector3 = spot["pos"]
		var len_: float = srng.randf_range(6.0, 11.0)
		var wid: float = srng.randf_range(0.9, 1.9)
		var c: Vector3 = base + Vector3(dir2.x, 0, dir2.y) * (1.6 + len_ * 0.34)
		if _terrain_height(c.x, c.z) < -1.0:
			continue  # front faces the canal: no road to reflect on
		c.y = _terrain_height(c.x, c.z) + 0.13
		var yaw: float = atan2(dir2.x, dir2.y)
		var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(wid, 1, len_))
		xforms.append(Transform3D(basis, c))
		var col: Color = spot["color"]
		colors.append(Color(col.r * 0.36, col.g * 0.36, col.b * 0.36))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = plane
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "WetStreaksV4"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	streak_count_v4 = xforms.size()

func _build_lamps_v4() -> void:
	var pole_xf: Array[Transform3D] = []
	var bulb_xf: Array[Transform3D] = []
	var pool_xf: Array[Transform3D] = []
	for road in _layout["roads"]:
		var kind: String = String(road["kind"])
		if kind == "deck":
			continue
		var pts: Array = road["pts"]
		var w: float = float(road["w"])
		var step: float = 26.0 if kind == "market" else 31.0
		var side: float = 1.0
		for i in range(pts.size() - 1):
			var a := Vector2(float(pts[i][0]), float(pts[i][1]))
			var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
			var seg: Vector2 = b - a
			var seglen: float = seg.length()
			if seglen < 1.0:
				continue
			var dirv: Vector2 = seg / seglen
			var perp := Vector2(-dirv.y, dirv.x)
			var t: float = step * 0.5
			while t < seglen:
				side = -side
				var p: Vector2 = a + dirv * t + perp * (side * (w * 0.5 + 1.3))
				t += step
				if absf(p.x) > 233.0 or absf(p.y) > 233.0:
					continue
				var gy: float = _terrain_height(p.x, p.y)
				if gy < -1.0:
					continue
				var top := Vector3(p.x, gy + 5.3, p.y)
				pole_xf.append(Transform3D(Basis.from_scale(Vector3(1, 5.4, 1)),
					Vector3(p.x, gy + 2.7, p.y)))
				var inward := Vector3(-perp.x * side, 0, -perp.y * side)
				bulb_xf.append(Transform3D(Basis.from_scale(Vector3(1.7, 0.75, 1.7)),
					top + inward * 0.85))
				pool_xf.append(Transform3D(Basis.IDENTITY,
					Vector3(p.x, gy + 0.14, p.y) + inward * 1.6))
	# Plaza perimeter lamps: the spawn square must not be a black
	# void — in the reference, open spaces are lamp-lit mid-grey.
	for t in range(-24, 25, 16):
		for pp in [Vector2(37, t), Vector2(-37, t), Vector2(t, 37), Vector2(t, -37)]:
			var gy2: float = _terrain_height(pp.x, pp.y)
			pole_xf.append(Transform3D(Basis.from_scale(Vector3(1, 5.4, 1)),
				Vector3(pp.x, gy2 + 2.7, pp.y)))
			var inw: Vector3 = -Vector3(pp.x, 0, pp.y).normalized()
			bulb_xf.append(Transform3D(Basis.from_scale(Vector3(1.7, 0.75, 1.7)),
				Vector3(pp.x, gy2 + 5.3, pp.y) + inw * 0.85))
			pool_xf.append(Transform3D(Basis.IDENTITY,
				Vector3(pp.x, gy2 + 0.14, pp.y) + inw * 1.6))
	for pp in [Vector2(19, 19), Vector2(-19, 19), Vector2(19, -19), Vector2(-19, -19)]:
		var gy3: float = _terrain_height(pp.x, pp.y)
		pole_xf.append(Transform3D(Basis.from_scale(Vector3(1, 5.4, 1)),
			Vector3(pp.x, gy3 + 2.7, pp.y)))
		var inw3: Vector3 = -Vector3(pp.x, 0, pp.y).normalized()
		bulb_xf.append(Transform3D(Basis.from_scale(Vector3(1.7, 0.75, 1.7)),
			Vector3(pp.x, gy3 + 5.3, pp.y) + inw3 * 0.85))
		pool_xf.append(Transform3D(Basis.IDENTITY,
			Vector3(pp.x, gy3 + 0.14, pp.y) + inw3 * 1.6))
	lamp_count = pole_xf.size()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.09
	pole_mesh.bottom_radius = 0.12
	pole_mesh.height = 1.0
	_scatter_mm("LampPoles", pole_xf, [], pole_mesh, _mat_dark_metal)
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb_mat.albedo_color = Color(1.0, 0.72, 0.42)
	var sm := SphereMesh.new()
	sm.radius = 0.32
	sm.height = 0.64
	_scatter_mm("LampBulbs", bulb_xf, [], sm, bulb_mat)
	var pm := PlaneMesh.new()
	pm.size = Vector2(10.5, 10.5)
	var warm_pool := StandardMaterial3D.new()
	warm_pool.albedo_texture = _soft_pool_texture()
	warm_pool.albedo_color = Color(1.0, 0.62, 0.30, 0.13)
	warm_pool.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	warm_pool.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	warm_pool.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_scatter_mm("LampPools", pool_xf, [], pm, warm_pool)

func _scatter_mm(mname: String, xforms: Array, colors: Array, mesh: Mesh, mat: Material, range_end: float = 0.0) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	if not colors.is_empty():
		mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
		if not colors.is_empty():
			mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = mname
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if range_end > 0.0:
		mmi.visibility_range_end = range_end
	add_child(mmi)

func _build_steam_v4() -> void:
	var srng := RandomNumberGenerator.new()
	srng.seed = 555
	var spots: Array[Vector2] = []
	var x: float = -130.0
	while x < 130.0:
		spots.append(Vector2(x, 131.0))
		spots.append(Vector2(x + 13.0, 145.0))
		x += 27.0
	x = -120.0
	while x < 130.0:
		spots.append(Vector2(x, 171.0))
		x += 43.0
	for c in [Vector2(30, 30), Vector2(-30, 30), Vector2(30, -30), Vector2(-30, -30),
			Vector2(62, -60), Vector2(-96, -52), Vector2(120, 40), Vector2(-140, 96)]:
		spots.append(c)
	var holder := Node3D.new()
	holder.name = "SteamV4"
	add_child(holder)
	for p in spots:
		var gy: float = _terrain_height(p.x, p.y)
		if gy < -1.0:
			continue
		var vent := Node3D.new()
		vent.position = Vector3(p.x, gy + 0.05, p.y)
		holder.add_child(vent)
		var tint: Color = _district_neon_color(vent.position, srng).lerp(
			Color(0.72, 0.76, 0.84), 0.62)
		var sprites: Array = []
		for s in range(3):
			var sp := Sprite3D.new()
			sp.texture = _glow_tex
			sp.modulate = Color(tint.r, tint.g, tint.b, 0.11 - float(s) * 0.022)
			sp.pixel_size = 0.021
			sp.visibility_range_end = 95.0
			sp.position = Vector3(0, 0.8 + float(s) * 1.15, 0)
			vent.add_child(sp)
			sprites.append(sp)
		_steam.append({"phase": srng.randf() * 10.0, "sprites": sprites})
		steam_count_v4 += 1

func _build_gantries_v4() -> void:
	# Overhead sign bridges across the avenues — the reference's
	# strongest "street canyon" cue (MARMUR BANK gantry).
	var picks: Array = []
	for road in _layout["roads"]:
		if String(road["kind"]) == "avenue":
			picks.append([road, 0.5])
		if String(road["name"]) == "ns_main":
			picks.append([road, 0.32])
	for pick in picks:
		var road: Dictionary = pick[0]
		var frac: float = float(pick[1])
		var pts: Array = road["pts"]
		# Point + direction at the polyline fraction.
		var total: float = 0.0
		var lens: Array[float] = []
		for i in range(pts.size() - 1):
			var l: float = Vector2(float(pts[i + 1][0]) - float(pts[i][0]),
				float(pts[i + 1][1]) - float(pts[i][1])).length()
			lens.append(l)
			total += l
		var target: float = total * frac
		var pos := Vector2(float(pts[0][0]), float(pts[0][1]))
		var dirv := Vector2.RIGHT
		for i in range(lens.size()):
			if target <= lens[i]:
				var a := Vector2(float(pts[i][0]), float(pts[i][1]))
				var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
				dirv = (b - a).normalized()
				pos = a + dirv * target
				break
			target -= lens[i]
		var w: float = float(road["w"])
		var span: float = w + 8.0
		var perp := Vector2(-dirv.y, dirv.x)
		var gy: float = _terrain_height(pos.x, pos.y)
		var root := Node3D.new()
		root.position = Vector3(pos.x, gy, pos.y)
		root.rotation.y = atan2(dirv.x, dirv.y)
		root.name = "Gantry"
		add_child(root)
		# Local frame: road runs along +Z, span across X.
		for sx in [-1.0, 1.0]:
			_box(root, Vector3(0.55, 8.6, 0.55), Vector3(sx * span * 0.5, 4.3, 0), _mat_dark_metal)
			_add_collider(root, Vector3(0.55, 8.6, 0.55), Vector3(sx * span * 0.5, 4.3, 0))
		_box(root, Vector3(span + 1.0, 0.8, 0.7), Vector3(0, 8.3, 0), _mat_dark_metal)
		var bmat: Material = _billboard_mats[gantry_count % _billboard_mats.size()]
		_box(root, Vector3(span * 0.74, 2.9, 0.35), Vector3(0, 6.4, 0), bmat)
		var sign_names: Array = ["SignC", "SignP", "SignY", "SignW"]
		_box(root, Vector3(span * 0.7, 0.22, 0.5), Vector3(0, 4.75, 0),
			_bld_mats[sign_names[gantry_count % sign_names.size()]])
		if _font != null:
			for sz in [0.35, -0.35]:
				var lab := Label3D.new()
				lab.text = BILLBOARD_BRANDS[gantry_count % BILLBOARD_BRANDS.size()]
				lab.font = _font
				lab.font_size = 160
				lab.pixel_size = 0.02
				lab.modulate = Color(1, 1, 1)
				lab.outline_size = 10
				lab.position = Vector3(0, 6.5, sz * 1.6)
				if sz < 0.0:
					lab.rotation.y = PI
				root.add_child(lab)
		for ch in root.get_children():
			if ch is GeometryInstance3D:
				(ch as GeometryInstance3D).visibility_range_end = 260.0
		gantry_count += 1

# --- Phase 2.6: the density finish -----------------------------------
# What the reference has that a clean model city lacks: signs
# jutting at every height, junk on every roof, wires across every
# street. All MultiMesh-scattered from the placed-building data.

var blade_sign_count: int = 0
var roof_prop_count: int = 0
var cable_count: int = 0

func _tone_holo() -> void:
	if holo == null:
		return
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(0.55, 0.85, 1.0)
	for ch in holo.get_children():
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh is TorusMesh:
			(ch as MeshInstance3D).material_override = ring_mat
		elif ch is Label3D:
			(ch as Label3D).modulate = Color(0.72, 0.93, 1.0)

func _sign_groups() -> Array:
	var mats: Dictionary = {}
	var cols: Dictionary = {}
	var sign_names: Array = ["SignC", "SignP", "SignY", "SignW"]
	var sign_cols: Array = [Color(0.1, 0.95, 1.0), Color(1.0, 0.25, 0.65),
		Color(0.99, 0.93, 0.04), Color(0.92, 0.96, 1.0)]
	for i in range(sign_names.size()):
		mats["s%d" % i] = _bld_mats[sign_names[i]]
		cols["s%d" % i] = sign_cols[i]
	for i in range(_billboard_mats.size()):
		mats["b%d" % i] = _billboard_mats[i]
		cols["b%d" % i] = Color(0.85, 0.8, 0.7)
	return [mats, cols]

func _build_blade_signs_v4() -> void:
	var pair: Array = _sign_groups()
	var mats: Dictionary = pair[0]
	var cols: Dictionary = pair[1]
	var groups: Dictionary = {}
	var pool_xf: Array[Transform3D] = []
	var pool_col: Array[Color] = []
	var srng := RandomNumberGenerator.new()
	srng.seed = 2026
	for b in _buildings:
		if bool(b.get("fixed", false)):
			continue
		var h: float = float(b["height"])
		if h < 10.0:
			continue
		var center: Vector3 = b["center"]
		var fp: Vector2 = b["fp"]
		var rot: float = float(b.get("rot", 0.0))
		var dir3 := Vector3(sin(rot), 0, cos(rot))
		var tan3 := Vector3(cos(rot), 0, -sin(rot))
		var front: Vector3 = center + dir3 * (fp.y * 0.5)
		var n: int = 0
		var r: float = srng.randf()
		if r < 0.55:
			n = 1
		elif r < 0.78:
			n = 2
		for k in range(n):
			var along: float = srng.randf_range(-0.32, 0.32) * fp.x
			var sy: float = minf(srng.randf_range(4.2, 7.6), h - 2.0)
			if sy < 3.5:
				continue
			var key: String
			var basis: Basis
			var pos: Vector3
			if srng.randf() < 0.62:
				# Blade sign jutting perpendicular from the facade.
				if srng.randf() < 0.7:
					key = "s%d" % (srng.randi() % 4)
				else:
					key = "b%d" % (srng.randi() % _billboard_mats.size())
				var ws: float = srng.randf_range(0.95, 1.5)
				var hs: float = srng.randf_range(2.2, 3.4)
				basis = Basis(tan3 * 0.30, Vector3(0, hs, 0), dir3 * ws)
				pos = front + dir3 * (ws * 0.5 - 0.05) + tan3 * along
			else:
				# Flat sign panel on the facade.
				key = "s%d" % (srng.randi() % 4)
				var ws2: float = srng.randf_range(2.6, 4.2)
				basis = Basis(tan3 * ws2, Vector3(0, 1.05, 0), dir3 * 0.20)
				pos = front + dir3 * 0.16 + tan3 * along
			pos.y = center.y + sy
			if not groups.has(key):
				groups[key] = []
			(groups[key] as Array).append(Transform3D(basis, pos))
			blade_sign_count += 1
			if srng.randf() < 0.45:
				var pp: Vector3 = front + dir3 * 1.9 + tan3 * along
				pp.y = _terrain_height(pp.x, pp.z) + 0.13
				pool_xf.append(Transform3D(Basis.from_scale(Vector3(5.5, 1, 5.5)), pp))
				var cc: Color = cols[key]
				pool_col.append(Color(cc.r, cc.g, cc.b, 0.11))
	var unit_box := BoxMesh.new()
	for key in groups.keys():
		_scatter_mm("BladeSigns_" + key, groups[key], [], unit_box, mats[key], 175.0)
	if not pool_xf.is_empty():
		var pmat := StandardMaterial3D.new()
		pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pmat.albedo_texture = _soft_pool_texture()
		pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		pmat.vertex_color_use_as_albedo = true
		var pm := PlaneMesh.new()
		pm.size = Vector2(1, 1)
		_scatter_mm("SignPools", pool_xf, pool_col, pm, pmat, 175.0)

func _build_rooftops_v4() -> void:
	var ac_xf: Array[Transform3D] = []
	var ant_xf: Array[Transform3D] = []
	var bec_xf: Array[Transform3D] = []
	var tank_xf: Array[Transform3D] = []
	var pyl_xf: Array[Transform3D] = []
	var pair: Array = _sign_groups()
	var mats: Dictionary = pair[0]
	var bb_groups: Dictionary = {}
	var srng := RandomNumberGenerator.new()
	srng.seed = 777
	for b in _buildings:
		if bool(b.get("fixed", false)):
			continue
		var center: Vector3 = b["center"]
		var fp: Vector2 = b["fp"]
		var h: float = float(b["height"])
		var rot: float = float(b.get("rot", 0.0))
		var brot := Basis(Vector3.UP, rot)
		var roof_y: float = center.y + h
		if srng.randf() < 0.62:
			for k in range(srng.randi_range(1, 3)):
				var off := Vector3(srng.randf_range(-0.28, 0.28) * fp.x, 0,
					srng.randf_range(-0.28, 0.28) * fp.y)
				var pos: Vector3 = center + brot * off
				pos.y = roof_y + 0.45
				ac_xf.append(Transform3D(brot * Basis.from_scale(Vector3(
					srng.randf_range(1.2, 2.6), 0.9, srng.randf_range(1.0, 1.9))), pos))
		if srng.randf() < 0.30:
			var off2 := Vector3(srng.randf_range(-0.4, 0.4) * fp.x, 0,
				srng.randf_range(-0.4, 0.4) * fp.y)
			var pos2: Vector3 = center + brot * off2
			var ah: float = srng.randf_range(4.5, 9.0)
			ant_xf.append(Transform3D(Basis.from_scale(Vector3(1, ah, 1)),
				pos2 + Vector3(0, roof_y + ah * 0.5, 0)))
			bec_xf.append(Transform3D(Basis.IDENTITY,
				pos2 + Vector3(0, roof_y + ah + 0.3, 0)))
		if srng.randf() < 0.10:
			var off3 := Vector3(srng.randf_range(-0.25, 0.25) * fp.x, 0,
				srng.randf_range(-0.25, 0.25) * fp.y)
			var pos3: Vector3 = center + brot * off3
			var th: float = srng.randf_range(2.2, 3.0)
			tank_xf.append(Transform3D(Basis.from_scale(Vector3(1, th, 1)),
				pos3 + Vector3(0, roof_y + th * 0.5, 0)))
		if h > 26.0 and srng.randf() < 0.16:
			var off4 := Vector3(0, 0, fp.y * 0.30)
			var pos4: Vector3 = center + brot * off4
			pyl_xf.append(Transform3D(brot * Basis.from_scale(Vector3(0.35, 7.0, 0.35)),
				pos4 + Vector3(0, roof_y + 3.5, 0)))
			var key: String = "b%d" % (srng.randi() % _billboard_mats.size())
			if not bb_groups.has(key):
				bb_groups[key] = []
			(bb_groups[key] as Array).append(Transform3D(
				brot * Basis.from_scale(Vector3(3.4, 1.9, 0.25)),
				pos4 + Vector3(0, roof_y + 6.6, 0)))
	roof_prop_count = ac_xf.size() + ant_xf.size() + tank_xf.size() + pyl_xf.size()
	var unit_box := BoxMesh.new()
	_scatter_mm("RoofAC", ac_xf, [], unit_box, _bld_mats["BldConc"], 260.0)
	var ant_mesh := CylinderMesh.new()
	ant_mesh.top_radius = 0.07
	ant_mesh.bottom_radius = 0.07
	ant_mesh.height = 1.0
	_scatter_mm("RoofAntennas", ant_xf, [], ant_mesh, _mat_dark_metal, 260.0)
	var bec_mesh := SphereMesh.new()
	bec_mesh.radius = 0.22
	bec_mesh.height = 0.44
	_scatter_mm("RoofBeacons", bec_xf, [], bec_mesh, _mat_beacon, 260.0)
	var tank_mesh := CylinderMesh.new()
	tank_mesh.top_radius = 1.35
	tank_mesh.bottom_radius = 1.35
	tank_mesh.height = 1.0
	_scatter_mm("RoofTanks", tank_xf, [], tank_mesh, _mat_dark_metal, 260.0)
	_scatter_mm("RoofPylons", pyl_xf, [], unit_box, _mat_dark_metal, 260.0)
	for key in bb_groups.keys():
		_scatter_mm("RoofSigns_" + key, bb_groups[key], [], unit_box, mats[key], 260.0)

func _cable_seg(xf: Array, a: Vector3, b: Vector3) -> void:
	var d: Vector3 = b - a
	var len_: float = d.length()
	if len_ < 0.5:
		return
	var basis := Basis.looking_at(d / len_, Vector3.UP) * Basis.from_scale(Vector3(0.06, 0.06, len_))
	xf.append(Transform3D(basis, (a + b) * 0.5))

func _build_cables_v4() -> void:
	var xf: Array[Transform3D] = []
	var srng := RandomNumberGenerator.new()
	srng.seed = 31337
	for road in _layout["roads"]:
		var kind: String = String(road["kind"])
		if kind != "avenue" and kind != "street":
			continue
		var pts: Array = road["pts"]
		var w: float = float(road["w"])
		for i in range(pts.size() - 1):
			var a := Vector2(float(pts[i][0]), float(pts[i][1]))
			var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
			var seg: Vector2 = b - a
			var seglen: float = seg.length()
			if seglen < 20.0:
				continue
			var dirv: Vector2 = seg / seglen
			var perp := Vector2(-dirv.y, dirv.x)
			var t: float = 19.0
			while t < seglen:
				var p: Vector2 = a + dirv * t
				t += 38.0
				var gy: float = _terrain_height(p.x, p.y)
				if gy < -1.0:
					continue
				var hgt: float = gy + srng.randf_range(9.0, 13.5)
				var pa: Vector2 = p + perp * (w * 0.5 + 3.5)
				var pb: Vector2 = p - perp * (w * 0.5 + 3.5)
				var va := Vector3(pa.x, hgt + srng.randf_range(-0.8, 0.8), pa.y)
				var vb := Vector3(pb.x, hgt + srng.randf_range(-0.8, 0.8), pb.y)
				var vm: Vector3 = (va + vb) * 0.5 - Vector3(0, 1.0, 0)
				_cable_seg(xf, va, vm)
				_cable_seg(xf, vm, vb)
	# Plaza diagonals (under the holo, over the square).
	for pair2 in [[Vector2(-33, -33), Vector2(33, 33)], [Vector2(-33, 33), Vector2(33, -33)]]:
		var va2 := Vector3(pair2[0].x, 12.5, pair2[0].y)
		var vb2 := Vector3(pair2[1].x, 12.5, pair2[1].y)
		var vm2: Vector3 = (va2 + vb2) * 0.5 - Vector3(0, 1.3, 0)
		_cable_seg(xf, va2, vm2)
		_cable_seg(xf, vm2, vb2)
	cable_count = xf.size()
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.03, 0.03, 0.045)
	cmat.roughness = 0.9
	_scatter_mm("Cables", xf, [], BoxMesh.new(), cmat, 200.0)

# ------------------------------------------------------------------
# v4.3: device-photo PDCA — softer pools, a designed plaza plinth,
# painted plaza markings, and air traffic for the aerial view.
# ------------------------------------------------------------------

var _soft_pool_tex: ImageTexture

## Steeper falloff than the shared glow texture: on device, pools
## rendered as hard-edged discs; pow 3 keeps a visible core but the
## rim melts into the ground.
func _soft_pool_texture() -> ImageTexture:
	if _soft_pool_tex != null:
		return _soft_pool_tex
	var s: int = 128
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var center: float = (s - 1) * 0.5
	for y in range(s):
		for x in range(s):
			var d: float = Vector2(x - center, y - center).length() / center
			var a: float = pow(clampf(1.0 - d, 0.0, 1.0), 3.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_soft_pool_tex = ImageTexture.create_from_image(img)
	return _soft_pool_tex

func _build_plinth_v4() -> void:
	var holder := Node3D.new()
	holder.name = "PlazaPlinth"
	add_child(holder)
	var cyan := StandardMaterial3D.new()
	cyan.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cyan.albedo_color = Color(0.25, 0.85, 1.0)
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 6.8
	tor.outer_radius = 7.25
	ring.mesh = tor
	ring.material_override = cyan
	ring.position = Vector3(0, 0.21, 0)
	holder.add_child(ring)
	var plate := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 5.5
	cyl.bottom_radius = 5.5
	cyl.height = 0.12
	plate.mesh = cyl
	plate.material_override = _mat_dark_metal
	plate.position = Vector3(0, 0.17, 0)
	holder.add_child(plate)
	var ring2 := MeshInstance3D.new()
	var tor2 := TorusMesh.new()
	tor2.inner_radius = 5.3
	tor2.outer_radius = 5.55
	ring2.mesh = tor2
	var cyan_dim := StandardMaterial3D.new()
	cyan_dim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cyan_dim.albedo_color = Color(0.12, 0.45, 0.58)
	ring2.material_override = cyan_dim
	ring2.position = Vector3(0, 0.24, 0)
	holder.add_child(ring2)
	# Bollard lights around the plinth.
	var bol_xf: Array[Transform3D] = []
	var bulb_xf: Array[Transform3D] = []
	for i in range(6):
		var a: float = float(i) * TAU / 6.0 + 0.26
		var p := Vector3(cos(a) * 9.6, 0.06, sin(a) * 9.6)
		bol_xf.append(Transform3D(Basis.from_scale(Vector3(1, 0.85, 1)),
			p + Vector3(0, 0.43, 0)))
		bulb_xf.append(Transform3D(Basis.from_scale(Vector3(0.55, 0.4, 0.55)),
			p + Vector3(0, 0.92, 0)))
	var bol_mesh := CylinderMesh.new()
	bol_mesh.top_radius = 0.09
	bol_mesh.bottom_radius = 0.11
	bol_mesh.height = 1.0
	_scatter_mm("PlinthBollards", bol_xf, [], bol_mesh, _mat_dark_metal, 130.0)
	var sm := SphereMesh.new()
	sm.radius = 0.32
	sm.height = 0.64
	_scatter_mm("PlinthBulbs", bulb_xf, [], sm, cyan, 130.0)
	# Benches + planters on the plaza rim fill the empty square.
	var bench_xf: Array[Transform3D] = []
	for i in range(8):
		var a2: float = float(i) * TAU / 8.0 + 0.39
		var bp := Vector3(cos(a2) * 25.5, 0.06, sin(a2) * 25.5)
		var rot := Basis(Vector3.UP, -a2 + PI * 0.5)
		bench_xf.append(Transform3D(rot.scaled(Vector3(2.2, 0.4, 0.5)),
			bp + Vector3(0, 0.2, 0)))
		bench_xf.append(Transform3D(rot.scaled(Vector3(2.3, 0.1, 0.62)),
			bp + Vector3(0, 0.45, 0)))
		var back_off: Vector3 = (rot * Vector3(0, 0, 0.28))
		bench_xf.append(Transform3D(rot.scaled(Vector3(2.3, 0.55, 0.1)),
			bp + Vector3(0, 0.72, 0) + back_off))
	# Concrete, not near-black metal: in the cycle-2 shot the dark
	# metal benches read as featureless black cubes.
	var bench_mat := StandardMaterial3D.new()
	bench_mat.albedo_color = Color(0.32, 0.33, 0.36)
	bench_mat.roughness = 0.9
	_scatter_mm("PlazaBenches", bench_xf, [], BoxMesh.new(), bench_mat, 130.0)
	var plant_xf: Array[Transform3D] = []
	var leaf_xf: Array[Transform3D] = []
	for i in range(4):
		var a3: float = float(i) * TAU / 4.0
		var pp := Vector3(cos(a3) * 23.0, 0.06, sin(a3) * 23.0)
		var rot3 := Basis(Vector3.UP, -a3 + PI * 0.5)
		plant_xf.append(Transform3D(rot3.scaled(Vector3(3.4, 0.8, 1.1)),
			pp + Vector3(0, 0.4, 0)))
		leaf_xf.append(Transform3D(rot3.scaled(Vector3(3.1, 0.4, 0.85)),
			pp + Vector3(0, 0.95, 0)))
	_scatter_mm("PlazaPlanters", plant_xf, [], BoxMesh.new(), _mat_dark_metal, 130.0)
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.05, 0.15, 0.11)
	leaf_mat.roughness = 1.0
	_scatter_mm("PlazaLeaves", leaf_xf, [], BoxMesh.new(), leaf_mat, 130.0)

func _build_plaza_marks() -> void:
	var tex: Texture2D = TextureLoader.load_tex(
		"res://assets/textures/plaza_marks.jpg",
		"res://assets/texture_data/plaza_marks.tres")
	if tex == null:
		return
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.albedo_color = Color(0.78, 0.78, 0.78, 1.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(67, 67)
	mi.mesh = pm
	mi.material_override = m
	mi.position = Vector3(0, 0.085, 0)
	mi.name = "PlazaMarks"
	add_child(mi)

var _air: Array = []

func _build_air_traffic() -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.05, 0.06, 0.09)
	body_mat.metallic = 0.6
	body_mat.roughness = 0.4
	var strip_mat := StandardMaterial3D.new()
	strip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	strip_mat.albedo_color = Color(0.45, 0.9, 1.0)
	var tail_mat := StandardMaterial3D.new()
	tail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tail_mat.albedo_color = Color(1.0, 0.25, 0.3)
	var trail_mat := StandardMaterial3D.new()
	trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_mat.albedo_color = Color(0.2, 0.7, 0.9, 0.17)
	trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var lanes: Array = [
		[Vector3(-275, 37, -58), Vector3(275, 37, -58), 26.0],
		[Vector3(86, 45, 275), Vector3(86, 45, -275), 31.0],
		[Vector3(275, 30, 148), Vector3(-275, 30, 148), 22.0],
	]
	for li in range(lanes.size()):
		var from: Vector3 = lanes[li][0]
		var to: Vector3 = lanes[li][1]
		var dir: Vector3 = (to - from).normalized()
		var span: float = (to - from).length()
		for k in range(3):
			var root := Node3D.new()
			root.name = "AirAV"
			var body := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(2.1, 1.0, 4.8)
			body.mesh = bm
			body.material_override = body_mat
			root.add_child(body)
			var strip := MeshInstance3D.new()
			var sm2 := BoxMesh.new()
			sm2.size = Vector3(2.14, 0.32, 2.2)
			strip.mesh = sm2
			strip.material_override = strip_mat
			strip.position = Vector3(0, 0.12, -0.9)
			root.add_child(strip)
			var tail := MeshInstance3D.new()
			var tm := BoxMesh.new()
			tm.size = Vector3(2.14, 0.22, 0.3)
			tail.mesh = tm
			tail.material_override = tail_mat
			tail.position = Vector3(0, 0.1, 2.4)
			root.add_child(tail)
			var trail := MeshInstance3D.new()
			var trm := BoxMesh.new()
			trm.size = Vector3(0.55, 0.05, 14.0)
			trail.mesh = trm
			trail.material_override = trail_mat
			trail.position = Vector3(0, 0, 9.7)
			root.add_child(trail)
			add_child(root)
			root.global_position = from
			root.look_at(from + dir, Vector3.UP)
			_air.append({
				"n": root, "from": from, "dir": dir, "span": span,
				"speed": float(lanes[li][2]) * (0.9 + 0.2 * float(k)),
				"d": span * (float(k) * 0.34 + 0.13 * float(li)),
				"ph": randf() * TAU,
			})

func _process(delta: float) -> void:
	super._process(delta)
	for e in _air:
		e["d"] = fmod(float(e["d"]) + float(e["speed"]) * delta,
			float(e["span"]))
		var n := e["n"] as Node3D
		var p: Vector3 = (e["from"] as Vector3) + (e["dir"] as Vector3) * float(e["d"])
		p.y += sin(Time.get_ticks_msec() * 0.001 + float(e["ph"])) * 0.35
		n.global_position = p

# --- v5.3 roadworks ---------------------------------------------------
## His 2026-11-16 report: the roads feel incomplete and the cars feel
## wrong on them. Three dressings, all derived from the layout data:
## 1) Retaining walls with a pale cap wherever a road's edge drops
##    more than ~1 m (terrace switchbacks, avenue climbs, bridge
##    parapets) — roads read as carved into the hill, not painted on.
## 2) Center dashes across the three canal bridges (the road entries
##    stop at the banks, so the baked dashes stopped too).
## 3) An asphalt apron under the skyway deck, with its own dashes —
##    the deck's underside was bare cracked lot.
## Walls are visual only; the collision heightfield is unchanged.

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)

func _dash(st: SurfaceTool, center: Vector2, dirv: Vector2, y: float) -> void:
	var fwd := Vector3(dirv.x, 0, dirv.y) * 1.5
	var rgt := Vector3(-dirv.y, 0, dirv.x) * 0.18
	var c := Vector3(center.x, y, center.y)
	_quad(st, c - fwd - rgt, c - fwd + rgt, c + fwd + rgt, c + fwd - rgt)

func _build_roadworks_v53() -> void:
	var wall_st := SurfaceTool.new()
	wall_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trim_st := SurfaceTool.new()
	trim_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 1) Retaining walls + caps along dropping road edges.
	for road in _layout["roads"]:
		if String(road["kind"]) == "deck":
			continue
		var pts: Array = road["pts"]
		var w: float = float(road["w"])
		for i in range(pts.size() - 1):
			var a := Vector2(float(pts[i][0]), float(pts[i][1]))
			var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
			var seg: Vector2 = b - a
			var seglen: float = seg.length()
			if seglen < 2.0:
				continue
			var dirv: Vector2 = seg / seglen
			var perp := Vector2(-dirv.y, dirv.x)
			var steps: int = maxi(1, int(seglen / 3.0))
			for side in [-1.0, 1.0]:
				var p_top := Vector3.ZERO
				var p_bot := Vector3.ZERO
				var p_ok: bool = false
				for k in range(steps + 1):
					var t: float = seglen * float(k) / float(steps)
					var c: Vector2 = a + dirv * t
					var e: Vector2 = c + perp * (side * (w * 0.5 + 0.15))
					var o: Vector2 = c + perp * (side * (w * 0.5 + 3.4))
					var o2: Vector2 = c + perp * (side * (w * 0.5 + 6.5))
					var h_e: float = _terrain_height(e.x, e.y)
					var h_o: float = _terrain_height(o.x, o.y)
					var ok: bool = h_e - h_o > 1.1
					var top := Vector3(e.x, h_e + 0.30, e.y)
					# The wall plane stands at the road edge but reaches
					# down to the height 6.5 m out: on a smooth bank the
					# lower part is buried in the slope and the exposed
					# face reads twice as tall (v5.3 PDCA round 1).
					var bot := Vector3(e.x, _terrain_height(o2.x, o2.y) - 0.4, e.y)
					if ok and p_ok:
						_quad(wall_st, p_top, top, bot, p_bot)
						var po := Vector3(perp.x * side * 0.45, 0, perp.y * side * 0.45)
						_quad(trim_st, p_top, p_top + po, top + po, top)
					p_top = top
					p_bot = bot
					p_ok = ok
	# 2) Dashes across the canal bridges.
	var connectors: Array = [["ns_main", "ns_south"], ["e_st", "e_south"], ["w_st", "w_south"]]
	var by_name: Dictionary = {}
	for road in _layout["roads"]:
		by_name[String(road["name"])] = road
	for pair in connectors:
		if not by_name.has(pair[0]) or not by_name.has(pair[1]):
			continue
		var npts: Array = by_name[pair[0]]["pts"]
		var spts: Array = by_name[pair[1]]["pts"]
		var a := Vector2(float(npts[npts.size() - 1][0]), float(npts[npts.size() - 1][1]))
		var b := Vector2(float(spts[0][0]), float(spts[0][1]))
		var seg: Vector2 = b - a
		var seglen: float = seg.length()
		if seglen < 4.0:
			continue
		var dirv: Vector2 = seg / seglen
		var t: float = 2.0
		while t < seglen - 1.0:
			var c: Vector2 = a + dirv * t
			_dash(trim_st, c, dirv, _terrain_height(c.x, c.y) + 0.09)
			t += 5.5
	# 3) Apron + dashes under the skyway deck.
	var ap_st := SurfaceTool.new()
	ap_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dp: Array = _layout["deck"]
	for i in range(dp.size() - 1):
		var a := Vector2(float(dp[i][0]), float(dp[i][1]))
		var b := Vector2(float(dp[i + 1][0]), float(dp[i + 1][1]))
		var seg: Vector2 = b - a
		var seglen: float = seg.length()
		if seglen < 2.0:
			continue
		var dirv: Vector2 = seg / seglen
		var perp := Vector2(-dirv.y, dirv.x)
		var steps: int = maxi(1, int(seglen / 6.0))
		var pl := Vector3.ZERO
		var pr := Vector3.ZERO
		for k in range(steps + 1):
			var t: float = seglen * float(k) / float(steps)
			var c: Vector2 = a + dirv * t
			var lp: Vector2 = c + perp * 13.0
			var rp: Vector2 = c - perp * 13.0
			var lv := Vector3(lp.x, _terrain_height(lp.x, lp.y) + 0.06, lp.y)
			var rv := Vector3(rp.x, _terrain_height(rp.x, rp.y) + 0.06, rp.y)
			if k > 0:
				_quad(ap_st, pl, lv, rv, pr)
			pl = lv
			pr = rv
		var td: float = 5.0
		while td < seglen - 2.0:
			var c2: Vector2 = a + dirv * td
			_dash(trim_st, c2, dirv, _terrain_height(c2.x, c2.y) + 0.12)
			td += 11.0
	var wall_mesh := MeshInstance3D.new()
	wall_mesh.name = "V53Walls"
	wall_st.generate_normals()
	wall_mesh.mesh = wall_st.commit()
	wall_mesh.material_override = _terrain_mat("WallMat")
	add_child(wall_mesh)
	var trim_mesh := MeshInstance3D.new()
	trim_mesh.name = "V53Trim"
	trim_st.generate_normals()
	trim_mesh.mesh = trim_st.commit()
	trim_mesh.material_override = _terrain_mat("LineMat")
	add_child(trim_mesh)
	var apron := MeshInstance3D.new()
	apron.name = "V53Apron"
	ap_st.generate_normals()
	apron.mesh = ap_st.commit()
	apron.material_override = _terrain_mat("RoadMat")
	add_child(apron)
