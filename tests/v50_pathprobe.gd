extends SceneTree
## Probe: how do runtime-imported track paths relate to the AP root?
func _initialize() -> void:
	var blob: Resource = load("res://assets/people_data/Punk.tres")
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_buffer((blob as ModelBlob).data, "", state)
	var inst: Node3D = doc.generate_scene(state)
	root.add_child(inst)
	var ap: AnimationPlayer = People.find_ap(inst)
	var skel: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	print("ap.root_node=", ap.root_node)
	var ap_root: Node = ap.get_node(ap.root_node)
	print("ap_root=", ap_root.name, " skel_np=", ap_root.get_path_to(skel))
	var a: Animation = ap.get_animation("CharacterArmature|Run")
	for t in range(mini(4, a.get_track_count())):
		var np: NodePath = a.track_get_path(t)
		print("track ", t, " names='", np.get_concatenated_names(), "' sub='", np.get_subname(0) if np.get_subname_count() > 0 else "", "' type=", a.track_get_type(t))
	quit()
