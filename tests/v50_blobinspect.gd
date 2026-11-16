extends SceneTree
## Compare clip track structure: editor-imported Punk vs runtime
## GLTFDocument (blob) Punk — focused on the Foot bones.
func _dump(ap: AnimationPlayer, tag: String) -> void:
	print("== ", tag)
	for c in ap.get_animation_list():
		var a: Animation = ap.get_animation(c)
		var foot_info: Array = []
		for t in range(a.get_track_count()):
			var p: String = str(a.track_get_path(t))
			if p.contains("Foot"):
				foot_info.append(p.get_slice(":", 1) + ":" + str(a.track_get_type(t)) + " keys=" + str(a.track_get_key_count(t)))
		print(c, " tracks=", a.get_track_count(), " foot=", foot_info)

func _initialize() -> void:
	# Editor-imported route
	var inst1: Node3D = ModelLoader.load_model("res://assets/people_q/opt/Punk.glb", "res://assets/people_data/Punk.tres")
	root.add_child(inst1)
	_dump(People.find_ap(inst1), "EDITOR IMPORT")
	# Runtime blob route (what the web build uses)
	var blob: Resource = load("res://assets/people_data/Punk.tres")
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_buffer((blob as ModelBlob).data, "", state) != OK:
		print("BLOB PARSE FAIL")
		quit()
		return
	var inst2: Node3D = doc.generate_scene(state)
	root.add_child(inst2)
	_dump(People.find_ap(inst2), "RUNTIME BLOB")
	quit()
