extends SceneTree
## Wraps the PBR texture JPGs in assets/textures/ as ModelBlob .tres
## files in assets/texture_data/ so they can be pushed as text.

const PAIRS: Array = [
	["res://assets/textures/asphalt_color.jpg", "res://assets/texture_data/asphalt_color.tres"],
	["res://assets/textures/asphalt_normal.jpg", "res://assets/texture_data/asphalt_normal.tres"],
	["res://assets/textures/asphalt_rough.jpg", "res://assets/texture_data/asphalt_rough.tres"],
	["res://assets/textures/concrete_normal.jpg", "res://assets/texture_data/concrete_normal.tres"],
	["res://assets/textures/concrete_rough.jpg", "res://assets/texture_data/concrete_rough.tres"],
	["res://assets/textures/facade_a.jpg", "res://assets/texture_data/facade_a.tres"],
	["res://assets/textures/facade_b.jpg", "res://assets/texture_data/facade_b.tres"],
	["res://assets/textures/facade_c.jpg", "res://assets/texture_data/facade_c.tres"],
	["res://assets/textures/kit_atlas.jpg", "res://assets/texture_data/kit_atlas.tres"],
]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/texture_data")
	for pair in PAIRS:
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(pair[0])
		if bytes.is_empty():
			printerr("MISSING ", pair[0])
			continue
		var blob := ModelBlob.new()
		blob.data = bytes
		var err: int = ResourceSaver.save(blob, pair[1])
		print("saved ", pair[1], " bytes=", bytes.size(), " err=", err)
	quit(0)
