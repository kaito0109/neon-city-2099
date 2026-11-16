extends SceneTree
## v5.5: wrap each assets/skf/*.glb (Sketchfab finds, cleaned in
## Blender) into a ModelBlob .tres under assets/skf_data/ so the
## models ship in the web pck (the repo carries no .glb files).
func _initialize() -> void:
	var names: Array[String] = ["sky_t_021", "bg_apartment", "milk_peach",
		"revolving_tower", "iqinso_hotel", "hovercar", "scifi_car",
		"cyberpunk_car", "flying_car2", "noodle_vending", "vending"]
	DirAccess.make_dir_recursive_absolute("res://assets/skf_data")
	for n in names:
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes("res://assets/skf/" + n + ".glb")
		if bytes.is_empty():
			print("MISSING ", n)
			continue
		var blob := ModelBlob.new()
		blob.data = bytes
		var err: Error = ResourceSaver.save(blob, "res://assets/skf_data/" + n + ".tres")
		print("saved ", n, " bytes=", bytes.size(), " err=", err)

	# The protagonist's GLB is ~9 MB: one ModelBlob tres would be
	# ~12 MB of base64, over the GitHub push body limit. Split the
	# raw bytes into ~2.27 MB parts (tres ~3.0 MB each); the loader
	# concatenates them back (ModelLoader.load_model_parts).
	var cbytes: PackedByteArray = FileAccess.get_file_as_bytes("res://assets/skf/cyberpunk_character.glb")
	var chunk := 2270000
	var nparts := int(ceil(float(cbytes.size()) / float(chunk)))
	for i in range(nparts):
		var part := ModelBlob.new()
		part.data = cbytes.slice(i * chunk, mini((i + 1) * chunk, cbytes.size()))
		var perr: Error = ResourceSaver.save(part, "res://assets/skf_data/cyberpunk_character_p" + str(i) + ".tres")
		print("saved part ", i, " bytes=", part.data.size(), " err=", perr)
	quit()
