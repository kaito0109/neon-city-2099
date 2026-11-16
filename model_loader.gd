class_name ModelLoader
extends RefCounted
## Loads Blender GLB models, preferring a real .glb resource (local dev)
## and falling back to the ModelBlob .tres that ships in the web export.
## Instances are cached as PackedScenes, so repeated placements of the
## same model parse the glTF only once.

static var _cache: Dictionary = {}

static func load_model(glb_path: String, tres_override: String = "") -> Node3D:
	var inst: Node3D = null
	if ResourceLoader.exists(glb_path):
		var ps: PackedScene = load(glb_path) as PackedScene
		if ps != null:
			inst = ps.instantiate() as Node3D
	if inst == null and _cache.has(glb_path):
		var cached: PackedScene = _cache[glb_path] as PackedScene
		if cached != null:
			inst = cached.instantiate() as Node3D
	if inst == null:
		var tres_path: String = tres_override
		if tres_path.is_empty():
			tres_path = glb_path.replace("res://assets/models/", "res://assets/model_data/").replace(".glb", ".tres")
		if not ResourceLoader.exists(tres_path):
			return null
		var blob: Resource = load(tres_path)
		if blob == null or not (blob is ModelBlob):
			return null
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_buffer((blob as ModelBlob).data, "", state) != OK:
			return null
		var node: Node = doc.generate_scene(state)
		if node == null:
			return null
		_complete_bone_tracks(node)
		var packed := PackedScene.new()
		if packed.pack(node) == OK:
			_cache[glb_path] = packed
			inst = packed.instantiate() as Node3D
		else:
			inst = node as Node3D
	if inst != null:
		_repair_materials(inst)
	return inst

## The runtime glTF importer (the web build's only route — the repo
## carries no .glb files) drops bone tracks whose pose is constant in
## the source clip: its Idle has NO Foot tracks at all, Walk only 27 of
## 60. A bone a clip does not drive keeps the pose the PREVIOUS clip
## left behind, so after any walk/run the feet stayed frozen at gait
## extremes (measured: Foot.R 2.2 rad while idling) — his 2026-11-16
## "legs collapse after walking/jumping" report. The editor importer
## emits a 1-key track for every bone instead. Mirror that here: give
## every animation a rest-pose key for every bone track it lacks, so
## switching clips always drives every bone.
static func _complete_bone_tracks(root_node: Node) -> void:
	var skel: Skeleton3D = null
	var ap: AnimationPlayer = null
	var stack: Array = [root_node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Skeleton3D and skel == null:
			skel = n as Skeleton3D
		if n is AnimationPlayer and ap == null:
			ap = n as AnimationPlayer
		for c in n.get_children():
			stack.append(c)
	if skel == null or ap == null:
		return
	# Node path of the skeleton as animation tracks address it
	# (relative to the AnimationPlayer's root node).
	var ap_root: Node = ap.get_node(ap.root_node)
	if ap_root == null:
		return
	var skel_np: NodePath = ap_root.get_path_to(skel)
	for cname in ap.get_animation_list():
		var anim: Animation = ap.get_animation(cname)
		if anim == null:
			continue
		var have: Dictionary = {}  # "bone|type" -> true
		for t in range(anim.get_track_count()):
			var np: NodePath = anim.track_get_path(t)
			if np.get_subname_count() > 0 and np.get_concatenated_names() == str(skel_np):
				have[str(np.get_subname(0)) + "|" + str(anim.track_get_type(t))] = true
		for b in range(skel.get_bone_count()):
			var bname: String = skel.get_bone_name(b)
			var rest: Transform3D = skel.get_bone_rest(b)
			var need: Array = [
				[Animation.TYPE_POSITION_3D, rest.origin],
				[Animation.TYPE_ROTATION_3D, rest.basis.get_rotation_quaternion()],
				[Animation.TYPE_SCALE_3D, rest.basis.get_scale()],
			]
			for pair in need:
				var key: String = bname + "|" + str(pair[0])
				if have.has(key):
					continue
				var t: int = anim.add_track(pair[0])
				var tp: NodePath = NodePath(str(skel_np) + ":" + bname)
				anim.track_set_path(t, tp)
				anim.track_insert_key(t, 0.0, pair[1])

## Shaded emission blows out to pure white in the web (WebGL) renderer
## and under llvmpipe, so convert every emissive glTF surface into an
## unshaded material with the emission color as albedo — the same neon
## language as the rest of the city (signs, windows, light pools).
static func _repair_materials(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for i in range(mi.mesh.get_surface_count()):
				var m: Material = mi.mesh.surface_get_material(i)
				if m is StandardMaterial3D:
					var sm := m as StandardMaterial3D
					if sm.emission_enabled:
						var nm := StandardMaterial3D.new()
						nm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
						nm.albedo_color = sm.emission
						nm.resource_name = sm.resource_name
						mi.set_surface_override_material(i, nm)
	for c in n.get_children():
		_repair_materials(c)
