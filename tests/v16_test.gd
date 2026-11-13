extends SceneTree
## v2.3 atmosphere checks: denser fog, hero billboards placed,
## searchlights built, reflection pools under storefront kits.
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
		_ok(int(city.get("billboard_count")) >= 6, "hero billboards placed (%d)" % int(city.get("billboard_count")))
		_ok((city.get("_searchlights") as Array).size() == 2, "2 searchlights")
		# Fog density readback from the live WorldEnvironment.
		var fog_ok: bool = false
		for ch in main.get_children():
			if ch is WorldEnvironment:
				fog_ok = is_equal_approx((ch as WorldEnvironment).environment.fog_density, 0.0072)
		_ok(fog_ok, "fog density is the v2.3 value (0.0072)")
		# First facade kit carries a reflection pool (QuadMesh child).
		var kits: Node = city.get_node_or_null("FacadeKits")
		var pool_found: bool = false
		if kits != null and kits.get_child_count() > 0:
			pool_found = _has_pool(kits.get_child(0))
		_ok(pool_found, "facade kit has a reflection pool")
		print("V16 TEST DONE")
		quit(1 if failed else 0)
		return true
	return false

func _has_pool(n: Node) -> bool:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh is QuadMesh:
		var m: Material = (n as MeshInstance3D).material_override
		if m is StandardMaterial3D and (m as StandardMaterial3D).blend_mode == BaseMaterial3D.BLEND_MODE_ADD:
			return true
	for c in n.get_children():
		if _has_pool(c):
			return true
	return false
