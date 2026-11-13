extends SceneTree
## v3 checks (P1-P3): Blender style kits placed, kit materials bound,
## shop frontage + blade signs, steam vents, wet-street streaks,
## yellow kiosk fingerprint, dusk environment readback.
var frames: int = 0
var main: Node
var failed: bool = false
var _yellow_found: int = 0

func _ok(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		failed = true

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 14:
		var city: Node = main.get("city")
		_ok(city.get("_mat_kit_shade") != null, "kit atlas shade material bound")
		_ok(city.get("_mat_kit_glow") != null, "kit atlas glow material bound")
		_ok(int(city.get("kit_building_count")) >= 40,
			"kit buildings placed (%d)" % int(city.get("kit_building_count")))
		_ok(int(city.get("shop_module_count")) >= 100,
			"frontage modules placed (%d)" % int(city.get("shop_module_count")))
		_ok(int(city.get("steam_vent_count")) >= 60,
			"steam vents placed (%d)" % int(city.get("steam_vent_count")))
		_ok(int(city.get("streak_count")) >= 50,
			"wet-street streaks placed (%d)" % int(city.get("streak_count")))
		_ok(city.get_node_or_null("WetStreaks") != null, "WetStreaks node exists")
		_ok(city.get_node_or_null("Steam") != null, "Steam node exists")
		# Kiosk screens use the yellow fingerprint material.
		_yellow_found = 0
		_count_kiosk_yellow(city, city.get("_mat_yellow_glow"))
		_ok(_yellow_found >= 1, "kiosk yellow screens found (%d)" % _yellow_found)
		# Dusk environment: warm fog + lowered warm sun.
		var we: WorldEnvironment = null
		for ch in main.get_children():
			if ch is WorldEnvironment:
				we = ch
		_ok(we != null and we.environment != null, "environment present")
		if we != null and we.environment != null:
			var fc: Color = we.environment.fog_light_color
			_ok(absf(fc.r - 0.215) < 0.01 and absf(fc.g - 0.16) < 0.01,
				"dusk fog colour (%.3f, %.3f, %.3f)" % [fc.r, fc.g, fc.b])
			_ok(absf(we.environment.fog_density - 0.0068) < 0.0002,
				"fog density (%.4f)" % we.environment.fog_density)
		print("V23 TEST DONE")
		quit(1 if failed else 0)
		return true
	return false

func _count_kiosk_yellow(n: Node, target: Material) -> void:
	# _box() applies materials as material_override; the only users of
	# _mat_yellow_glow are the JOB kiosk screens.
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.material_override == target:
			_yellow_found += 1
	for c in n.get_children():
		_count_kiosk_yellow(c, target)
