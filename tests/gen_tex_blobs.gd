extends SceneTree
## Wraps the PBR texture JPGs in assets/textures/ as ModelBlob .tres
## files in assets/texture_data/ so they can be pushed as text.

const PAIRS: Array = [
	["res://assets/textures/asphalt_color.jpg", "res://assets/texture_data/asphalt_color.tres"],
	["res://assets/textures/asphalt_normal.jpg", "res://assets/texture_data/asphalt_normal.tres"],
	["res://assets/textures/asphalt_rough.jpg", "res://assets/texture_data/asphalt_rough.tres"],
	["res://assets/textures/concrete_normal.jpg", "res://assets/texture_data/concrete_normal.tres"],
	["res://assets/textures/concrete_rough.jpg", "res://assets/texture_data/concrete_rough.tres"],
	["res://assets/textures/asphalt_ao.jpg", "res://assets/texture_data/asphalt_ao.tres"],
	["res://assets/textures/asphalt_disp.jpg", "res://assets/texture_data/asphalt_disp.tres"],
	["res://assets/textures/concrete_color.jpg", "res://assets/texture_data/concrete_color.tres"],
	["res://assets/textures/plaza_marks.jpg", "res://assets/texture_data/plaza_marks.tres"],
	["res://assets/textures/concrete_disp.jpg", "res://assets/texture_data/concrete_disp.tres"],
	["res://assets/textures/cracked_color.jpg", "res://assets/texture_data/cracked_color.tres"],
	["res://assets/textures/cracked_normal.jpg", "res://assets/texture_data/cracked_normal.tres"],
	["res://assets/textures/cracked_rough.jpg", "res://assets/texture_data/cracked_rough.tres"],
	["res://assets/textures/cracked_ao.jpg", "res://assets/texture_data/cracked_ao.tres"],
	["res://assets/textures/cracked_disp.jpg", "res://assets/texture_data/cracked_disp.tres"],
	["res://assets/textures/facade_a.jpg", "res://assets/texture_data/facade_a.tres"],
	["res://assets/textures/facade_b.jpg", "res://assets/texture_data/facade_b.tres"],
	["res://assets/textures/facade_c.jpg", "res://assets/texture_data/facade_c.tres"],
	["res://assets/textures/kit_atlas.jpg", "res://assets/texture_data/kit_atlas.tres"],
	["res://assets/textures/win_ent_a.jpg", "res://assets/texture_data/win_ent_a.tres"],
	["res://assets/textures/win_ent_b.jpg", "res://assets/texture_data/win_ent_b.tres"],
	["res://assets/textures/win_kit_a.jpg", "res://assets/texture_data/win_kit_a.tres"],
	["res://assets/textures/win_kit_b.jpg", "res://assets/texture_data/win_kit_b.tres"],
	["res://assets/textures/win_mil_a.jpg", "res://assets/texture_data/win_mil_a.tres"],
	["res://assets/textures/win_mil_b.jpg", "res://assets/texture_data/win_mil_b.tres"],
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
