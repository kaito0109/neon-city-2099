class_name ModelLoader
extends RefCounted
## Loads Blender GLB models, preferring a real .glb resource (local dev)
## and falling back to the ModelBlob .tres that ships in the web export.
## Instances are cached as PackedScenes, so repeated placements of the
## same model parse the glTF only once.

static var _cache: Dictionary = {}

static func load_model(glb_path: String) -> Node3D:
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
		var tres_path: String = glb_path.replace("res://assets/models/", "res://assets/model_data/").replace(".glb", ".tres")
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
		var packed := PackedScene.new()
		if packed.pack(node) == OK:
			_cache[glb_path] = packed
			inst = packed.instantiate() as Node3D
		else:
			inst = node as Node3D
	if inst != null:
		_repair_materials(inst)
	return inst

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
