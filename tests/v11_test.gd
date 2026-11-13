extends SceneTree
## NEON CITY v1.1 visual pass: regression + new-visual checks.
var frames: int = 0
var main: Node
var city: Node3D
var player: CharacterBody3D
var car: Node3D
var start_pos: Vector3
var car_start: Vector3
var failed: bool = false

func _ok(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		failed = true

func _initialize() -> void:
	var ps: PackedScene = load("res://main.tscn")
	main = ps.instantiate()
	root.add_child(main)

func _mm_count(mesh_test: String) -> int:
	for c in city.get_children():
		if c is MultiMeshInstance3D:
			var mmi := c as MultiMeshInstance3D
			var mesh: Mesh = mmi.multimesh.mesh
			if mesh_test == "crosswalk" and mesh is BoxMesh and is_equal_approx((mesh as BoxMesh).size.z, 3.4):
				return mmi.multimesh.instance_count
			if mesh_test == "puddle" and mesh is CylinderMesh and is_equal_approx((mesh as CylinderMesh).height, 0.02):
				return mmi.multimesh.instance_count
			if mesh_test == "stars" and mmi.multimesh.instance_count == 240:
				return 240
	return -1

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		city = main.get("city")
		player = main.get("player")
		_ok(city.get("poi_kiosks").size() == 5, "kiosks == 5")
		_ok(city.get("sidewalk_blocks").size() == 100, "sidewalk blocks == 100")
		_ok(main.get("_cars").size() == 13, "cars == 13")
		_ok(_mm_count("crosswalk") == 2420, "crosswalk stripes == 2420 (got %d)" % _mm_count("crosswalk"))
		_ok(_mm_count("puddle") == 200, "puddles == 200 (got %d)" % _mm_count("puddle"))
		_ok(_mm_count("stars") == 240, "stars == 240")
		var far: int = 0
		for c in city.get_children():
			if c is MeshInstance3D:
				var p: Vector3 = (c as MeshInstance3D).position
				if Vector2(p.x, p.z).length() > 400.0:
					far += 1
		_ok(far >= 30, "skyline towers beyond 400m: %d" % far)
		_ok(city.get("_mat_beacon") != null, "beacon material present")
		var we: WorldEnvironment = null
		for c in main.get_children():
			if c is WorldEnvironment:
				we = c
		_ok(we != null and we.environment.fog_enabled, "fog enabled")
		_ok(we != null and we.environment.adjustment_enabled, "color adjustment enabled")
		main.call("start_game")
		_ok(main.get("started") and player.get("input_enabled"), "game starts")
		start_pos = player.global_position
		player.set("touch_move", Vector2(0, 1))
	if frames == 65:
		var moved: float = Vector2(player.global_position.x - start_pos.x,
			player.global_position.z - start_pos.z).length()
		_ok(moved > 1.5, "player walks (%.2f m)" % moved)
		car = main.get("_cars")[0]
		car.call("set_driven", true)
		_ok(car.get("_cone").visible, "headlight cone on when driven")
		car_start = car.global_position
		main.set("touch_drive", Vector2(0, 1))
	if frames == 125:
		_ok(absf(car.get("speed")) > 3.0, "car accelerates (speed %.1f)" % car.get("speed"))
		print("V11 TEST DONE")
		quit(1 if failed else 0)
		return true
	return false
