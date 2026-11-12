class_name ModelLoader
extends RefCounted
## Loads Blender GLB models, preferring a real .glb resource (local dev)
## and falling back to the ModelBlob .tres that ships in the web export.
## Instances are cached as PackedScenes, so repeated placements of the
## same model parse the glTF only once.

static var _cache: Dictionary = {}

static func load_model(glb_path: String) -> Node3D:
	if ResourceLoader.exists(glb_path):
		var ps: PackedScene = load(glb_path) as PackedScene
		if ps != null:
			return ps.instantiate() as Node3D
	if _cache.has(glb_path):
		var cached: PackedScene = _cache[glb_path] as PackedScene
		if cached != null:
			return cached.instantiate() as Node3D
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
		return packed.instantiate() as Node3D
	return node as Node3D
