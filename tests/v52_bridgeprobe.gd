extends SceneTree
var frames: int = 0
var main: Node

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 30:
		main.call("start_game")
	if frames == 45:
		var city: Node = main.get("city")
		var out: String = "heights x=0: "
		var z: float = 148.0
		while z <= 204.0:
			out += "%.0f:%.2f " % [z, float(city.call("_terrain_height", 0.0, z))]
			z += 4.0
		print(out)
		# physics raycasts down the centerline
		var space := root.get_world_3d().direct_space_state
		var hits: String = "raycast: "
		z = 156.0
		while z <= 196.0:
			var q := PhysicsRayQueryParameters3D.create(Vector3(0, 6, z), Vector3(0, -6, z))
			var hit: Dictionary = space.intersect_ray(q)
			hits += "%.0f:%s " % [z, ("%.2f" % float((hit["position"] as Vector3).y)) if not hit.is_empty() else "MISS"]
			z += 8.0
		print(hits)
		print("PROBE DONE")
		quit()
		return true
	return false
