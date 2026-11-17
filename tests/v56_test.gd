extends SceneTree
## v5.6 regression: the GDScript bench-terrace height function must
## mirror the Blender one EXACTLY (they are maintained as a synced
## pair — the visual mesh and the collision/cars both derive from
## it). Samples were dumped by build_terrain_v4.py (V56_DUMP=1).
## Plus hand-computed property checks: lip / riser / toe / corridor.
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
	if frames == 10:
		var city: Node = main.get("city")
		_ok(bool(city.get("terrain_ok")), "terrain built")
		# Cross-check against the Blender-dumped samples.
		var f := FileAccess.open("/tmp/v56_samples.json", FileAccess.READ)
		_ok(f != null, "samples file present")
		if f != null:
			var samples: Array = JSON.parse_string(f.get_as_text())
			var bad: int = 0
			var worst: float = 0.0
			for s in samples:
				var h: float = city.call("_height_smooth_gd",
						float(s[0]), float(s[1]))
				var d: float = absf(h - float(s[2]))
				worst = maxf(worst, d)
				if d > 0.02:
					bad += 1
			_ok(bad == 0, "height fn matches Blender (%d samples, worst %.4f)"
					% [samples.size(), worst])
		# Hand-computed properties (see build_terrain_v4.py).
		var h1: float = city.call("_height_smooth_gd", 141.2, -185.0)
		_ok(absf(h1 - 18.0) < 0.05, "18m lip holds full height (%.2f)" % h1)
		var h2: float = city.call("_height_smooth_gd", 140.5, -185.0)
		_ok(absf(h2 - 17.01) < 0.15, "18m riser mid-slope (%.2f)" % h2)
		var h3: float = city.call("_height_smooth_gd", 137.0, -185.0)
		_ok(absf(h3 - 12.0) < 0.05, "riser lands on the 12m plateau (%.2f)" % h3)
		var h4: float = city.call("_height_smooth_gd", 200.0, -73.25)
		_ok(absf(h4 - 3.0) < 0.1, "6m riser mid-slope far from roads (%.2f)" % h4)
		var h5: float = city.call("_height_smooth_gd", 200.0, -71.5)
		_ok(absf(h5) < 0.05, "6m toe reaches flat ground (%.2f)" % h5)
		var h6: float = city.call("_height_smooth_gd", 128.0, -108.0)
		_ok(absf(h6 - 9.41) < 0.1, "ave_a_ne corridor keeps the ramp (%.2f)" % h6)
		var h7: float = city.call("_height_smooth_gd", 150.0, -116.0)
		_ok(absf(h7 - 12.0) < 0.05, "kiosk sits on the 12m top (%.2f)" % h7)
		print("TEST DONE failed=", fails > 0)
		quit(0 if fails == 0 else 1)
	return false
