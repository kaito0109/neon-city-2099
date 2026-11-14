extends SceneTree
## Phase 2 checks: every plot building is a Blender model, the far
## LOD swap exists, and all three heroes are Blender models.
var frames: int = 0
var main: Node
var fails: int = 0

func _ok(cond: bool, label: String) -> void:
	if cond:
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label)

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 15:
		var city: Node = main.get("city")
		# Duplicate sibling names are auto-renamed by the engine, so
		# count via the world's own placement counters instead.
		var near: int = int(city.get("model_building_count"))
		var far: int = int(city.get("far_lod_count"))
		_ok(near >= 150, "model buildings placed (%d)" % near)
		_ok(far >= 40, "far LOD twins placed (%d)" % far)
		_ok(city.get_node_or_null("Megabuilding/hero_mega") != null, "hero_mega model")
		_ok(city.get_node_or_null("ArchBuilding/hero_arch") != null, "hero_arch model")
		_ok(city.get_node_or_null("CylinderTower/hero_cyl") != null, "hero_cyl model")
		print("TEST DONE failed=", fails > 0)
		quit(0 if fails == 0 else 1)
	return false
