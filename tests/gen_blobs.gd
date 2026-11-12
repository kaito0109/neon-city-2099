extends SceneTree
## One-off generator: wrap each assets/models/*.glb into a ModelBlob .tres
## under assets/model_data/ (text resource -> ships in the web pck).
func _initialize() -> void:
	var names: Array[String] = ["hover_car", "vending_machine", "traffic_light",
		"holo_totem", "hero_tower_a", "hero_tower_b", "hero_tower_c"]
	DirAccess.make_dir_recursive_absolute("res://assets/model_data")
	for n in names:
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes("res://assets/models/" + n + ".glb")
		if bytes.is_empty():
			print("MISSING ", n)
			continue
		var blob := ModelBlob.new()
		blob.data = bytes
		var err: Error = ResourceSaver.save(blob, "res://assets/model_data/" + n + ".tres")
		print("saved ", n, " bytes=", bytes.size(), " err=", err)
	quit(0)
