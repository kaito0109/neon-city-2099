extends SceneTree
## v2.5 checks: PBR road tiles, street props, concrete sidewalk maps.
var frames: int = 0
var main: Node
var failed: bool = false

func _ok(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		failed = true

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 12:
		var city: Node = main.get("city")
		_ok(int(city.get("road_tile_count")) > 800, "road tiles placed (%d)" % int(city.get("road_tile_count")))
		_ok(city.get("_mat_asphalt_pbr") != null, "asphalt PBR material built")
		_ok(int(city.get("street_prop_count")) > 60, "street props placed (%d)" % int(city.get("street_prop_count")))
		var sp: Node = city.get_node_or_null("StreetProps")
		_ok(sp != null and sp.get_child_count() > 60, "StreetProps node populated")
		var sw: Material = city.get("_mat_sidewalk")
		_ok(sw != null and sw.get("normal_enabled") == true, "sidewalk concrete normal map on")
		print("V19 TEST DONE")
		quit(1 if failed else 0)
		return true
	return false
