extends SceneTree
## v4 checks: Blender terrain loaded with collision, layout plots
## built, POI contract for main, traffic tours, NPC blocks, player
## spawn landing, and a driven car climbing the terrace ramps on the
## raycast ground-follow (the v4 replacement for flat-city pinning).
var frames: int = 0
var main: Node
var failed: bool = false
var _car: Node3D
var _traffic: Node3D
var _traffic_p0: Vector3
var _phase: int = 0

func _ok(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		failed = true

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _ground_at(x: float, z: float) -> float:
	var space: PhysicsDirectSpaceState3D = (main as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 80, z), Vector3(x, -20, z))
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return -9999.0
	return float((hit["position"] as Vector3).y)

func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 14:
		var city: Node = main.get("city")
		_ok(bool(city.get("terrain_ok")), "terrain GLB loaded")
		_ok(city.get_node_or_null("TerrainBody") != null, "terrain collision body exists")
		_ok(int(city.get("plot_count")) >= 150, "layout plots built (%d)" % int(city.get("plot_count")))
		_ok(int(city.get("kit_building_count")) >= 50, "kit buildings placed (%d)" % int(city.get("kit_building_count")))
		_ok((city.get("poi_kiosks") as Array).size() == 5, "kiosks == 5")
		_ok((city.get("poi_terminals") as Array).size() == 4, "terminals == 4")
		_ok((city.get("poi_pickups") as Array).size() == 4, "pickups == 4")
		_ok((city.get("sidewalk_blocks") as Array).size() == 7, "walk blocks == 7")
		_ok((city.get("traffic_loops") as Array).size() == 2, "traffic loops == 2")
		_ok((city.get("deck_loop") as Array).size() >= 10, "deck loop points (%d)" % (city.get("deck_loop") as Array).size())
		_ok((city.get("race_points") as Array).size() == 10, "race points == 10")
		_ok((city.get("road_lines") as Array).size() >= 80, "road lines for map (%d)" % (city.get("road_lines") as Array).size())
		_ok((main.get("_npcs") as Array).size() == 120, "npcs spawned (%d)" % (main.get("_npcs") as Array).size())
		# Terrain height probes (collision readback).
		_ok(absf(_ground_at(10, 20) - 0.06) < 0.4, "plaza ground %.2f" % _ground_at(10, 20))
		_ok(absf(_ground_at(196, -205) - 18.0) < 0.6, "hilltop ground %.2f" % _ground_at(196, -205))
		_ok(absf(_ground_at(0, -66) - 10.05) < 0.5, "skyway deck %.2f" % _ground_at(0, -66))
		_ok(absf(_ground_at(-60, 179) + 2.7) < 0.6, "canal floor %.2f" % _ground_at(-60, 179))
		_ok(absf(_ground_at(0, 177) - 0.16) < 0.5, "canal bridge %.2f" % _ground_at(0, 177))
		# A traffic car to watch.
		for c in main.get("_cars"):
			if String(c.get("mode")) == "traffic":
				_traffic = c
				break
		_traffic_p0 = _traffic.global_position
	if frames == 90:
		var p: Node3D = main.get("player")
		_ok(p.global_position.y > -0.5 and p.global_position.y < 1.6,
			"player landed at spawn y=%.2f" % p.global_position.y)
		_ok(_traffic.global_position.distance_to(_traffic_p0) > 4.0,
			"traffic car touring (moved %.1f m)" % _traffic.global_position.distance_to(_traffic_p0))
		# Start the climb: a parked car -> driven, on the flat part of
		# Ave A NE, dropped from above the road so it settles cleanly
		# (teleporting into the bank slope wedges the body — v24 debug).
		_car = (main.get("_cars") as Array)[3]
		_car.global_position = Vector3(58, 2.5, -60)
		_car.set("heading", -0.89)
		_car.rotation.y = -0.89
		_car.call("set_driven", true)
		main.set("touch_drive", Vector2(0, 1.0))
		_phase = 1
	if _phase == 1 and frames == 90 + 480:
		main.set("touch_drive", Vector2.ZERO)
		var cp: Vector3 = _car.global_position
		_ok(cp.y > 8.0, "car climbed terrace ramps (y=%.2f at %.0f, %.0f)" % [cp.y, cp.x, cp.z])
		_ok(cp.y < 30.0, "car did not fly off (y=%.2f)" % cp.y)
		_ok(cp.x > 115.0, "car advanced along avenue (x=%.0f)" % cp.x)
		print("TEST DONE failed=", failed)
		quit(1 if failed else 0)
	return false
