extends SceneTree
## One-off generator: wrap each assets/models/*.glb into a ModelBlob .tres
## under assets/model_data/ (text resource -> ships in the web pck).
func _initialize() -> void:
	var names: Array[String] = ["hover_car", "vending_machine", "traffic_light",
		"holo_totem", "hero_tower_a", "hero_tower_b", "hero_tower_c", "facade_kit"]
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
	var people: Array[String] = ["Punk", "Casual", "CasualCharacter", "Suit",
		"AnimatedWoman", "Worker", "SciFi", "WomanCasual"]
	DirAccess.make_dir_recursive_absolute("res://assets/people_data")
	for n in people:
		var bytes2: PackedByteArray = FileAccess.get_file_as_bytes("res://assets/people_q/opt/" + n + ".glb")
		if bytes2.is_empty():
			print("MISSING person ", n)
			continue
		var blob2 := ModelBlob.new()
		blob2.data = bytes2
		var err2: Error = ResourceSaver.save(blob2, "res://assets/people_data/" + n + ".tres")
		print("saved person ", n, " bytes=", bytes2.size(), " err=", err2)
	var kits: Array[String] = ["tower_ent", "tower_kit", "tower_mil",
		"shop_a", "shop_b", "shop_c", "blade_sign", "blade_sign_y"]
	DirAccess.make_dir_recursive_absolute("res://assets/kit_data")
	for n in kits:
		var bytes4: PackedByteArray = FileAccess.get_file_as_bytes("res://assets/kits/" + n + ".glb")
		if bytes4.is_empty():
			print("MISSING kit ", n)
			continue
		var blob4 := ModelBlob.new()
		blob4.data = bytes4
		var err4: Error = ResourceSaver.save(blob4, "res://assets/kit_data/" + n + ".tres")
		print("saved kit ", n, " bytes=", bytes4.size(), " err=", err4)
	# v4 terrain (one authored Blender piece).
	DirAccess.make_dir_recursive_absolute("res://assets/terrain_data")
	var tbytes: PackedByteArray = FileAccess.get_file_as_bytes("res://assets/terrain/terrain_v4.glb")
	if tbytes.is_empty():
		print("MISSING terrain_v4")
	else:
		var tblob := ModelBlob.new()
		tblob.data = tbytes
		var terr: Error = ResourceSaver.save(tblob, "res://assets/terrain_data/terrain_v4.tres")
		print("saved terrain_v4 bytes=", tbytes.size(), " err=", terr)
	# v4 Phase 2: Blender building variants + heroes.
	DirAccess.make_dir_recursive_absolute("res://assets/bld_data")
	var bld_names: Array[String] = []
	for key in BldManifest.DATA.keys():
		bld_names.append(String(key))
		if bool(BldManifest.DATA[key]["far"]):
			bld_names.append(String(key) + "_far")
	bld_names.append("hero_mega")
	bld_names.append("hero_arch")
	bld_names.append("hero_cyl")
	for n in bld_names:
		var bytes5: PackedByteArray = FileAccess.get_file_as_bytes("res://assets/bld/" + n + ".glb")
		if bytes5.is_empty():
			print("MISSING bld ", n)
			continue
		var blob5 := ModelBlob.new()
		blob5.data = bytes5
		var err5: Error = ResourceSaver.save(blob5, "res://assets/bld_data/" + n + ".tres")
		print("saved bld ", n, " bytes=", bytes5.size(), " err=", err5)
	var props: Array[String] = ["bench", "trashcan", "dumpster"]
	DirAccess.make_dir_recursive_absolute("res://assets/props_data")
	for n in props:
		var bytes3: PackedByteArray = FileAccess.get_file_as_bytes("res://assets/props_q/" + n + ".glb")
		if bytes3.is_empty():
			print("MISSING prop ", n)
			continue
		var blob3 := ModelBlob.new()
		blob3.data = bytes3
		var err3: Error = ResourceSaver.save(blob3, "res://assets/props_data/" + n + ".tres")
		print("saved prop ", n, " bytes=", bytes3.size(), " err=", err3)
	quit(0)
