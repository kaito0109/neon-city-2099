extends SceneTree
## Phase 2.6 checks: blade signs, rooftop props, overhead cables.
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
		_ok(int(city.get("blade_sign_count")) >= 70, "blade signs (%d)" % int(city.get("blade_sign_count")))
		_ok(int(city.get("roof_prop_count")) >= 90, "roof props (%d)" % int(city.get("roof_prop_count")))
		_ok(int(city.get("cable_count")) >= 40, "cable segments (%d)" % int(city.get("cable_count")))
		_ok(city.get_node_or_null("Cables") != null, "cables multimesh node")
		_ok(city.get_node_or_null("RoofBeacons") != null, "roof beacons node")
		print("TEST DONE failed=", fails > 0)
		quit(0 if fails == 0 else 1)
	return false
