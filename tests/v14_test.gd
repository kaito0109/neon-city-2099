extends SceneTree
## v2 facade checks: storefront kits placed + sign tint variety,
## MultiMesh relief (ledges / AC / pipes) and blade signs exist.
var frames: int = 0
var main: Node
var failed: bool = false

func _ok(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		failed = true

func _initialize() -> void:
	var ps: PackedScene = load("res://main.tscn")
	main = ps.instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 8:
		main.call("start_game")
		var city: Node = main.get("city")
		var kits: Node = city.get_node_or_null("FacadeKits")
		_ok(kits != null and kits.get_child_count() >= 80,
			"facade kits placed (%d)" % (kits.get_child_count() if kits != null else -1))
		# Sign tint variety: collect distinct SignPanel override colors.
		var cols: Dictionary = {}
		if kits != null:
			for k in kits.get_children():
				_collect_sign_colors(k, cols)
		_ok(cols.size() >= 3, "kit sign colors vary (%d distinct)" % cols.size())
		var relief: MultiMeshInstance3D = city.get_node_or_null("FacadeRelief")
		_ok(relief != null and relief.multimesh.instance_count >= 400,
			"facade relief instances (%d)" % (relief.multimesh.instance_count if relief != null else -1))
		var signs: MultiMeshInstance3D = city.get_node_or_null("BladeSigns")
		_ok(signs != null and signs.multimesh.instance_count >= 60,
			"blade signs placed (%d)" % (signs.multimesh.instance_count if signs != null else -1))
		print("V14 TEST DONE")
		quit(1 if failed else 0)
		return true
	return false

func _collect_sign_colors(n: Node, cols: Dictionary) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for i in range(mi.mesh.get_surface_count()):
				var om: Material = mi.get_surface_override_material(i)
				if om is StandardMaterial3D and om.resource_name == "SignPanel":
					cols[(om as StandardMaterial3D).albedo_color.to_html()] = true
	for c in n.get_children():
		_collect_sign_colors(c, cols)
