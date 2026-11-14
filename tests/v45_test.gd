extends SceneTree
## v4.1 regression: no collision holes anywhere in the playable
## disc, deck intact, standing NPCs separate, casts spawn with
## rigs, light pools tamed, fall-out rescue works.
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
	if frames == 25:
		var space: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state
		var misses: int = 0
		var x: float = -236.0
		while x <= 236.0:
			var z: float = -236.0
			while z <= 236.0:
				var q := PhysicsRayQueryParameters3D.create(
					Vector3(x, 80, z), Vector3(x, -12, z))
				if space.intersect_ray(q).is_empty():
					misses += 1
				z += 2.5
			x += 2.5
		_ok(misses == 0, "no collision holes (misses=%d)" % misses)
		var city: Node = main.get("city")
		var gaps: int = 0
		for p in city.get("deck_loop"):
			var q2 := PhysicsRayQueryParameters3D.create(
				Vector3(p.x, 30, p.z), Vector3(p.x, -5, p.z))
			var h2: Dictionary = space.intersect_ray(q2)
			if h2.is_empty() or float((h2["position"] as Vector3).y) < 5.0:
				gaps += 1
		_ok(gaps == 0, "deck has no gaps (%d)" % gaps)
		var pool: StandardMaterial3D = city.get("_mat_pool")
		_ok(pool.albedo_color.a <= 0.2, "mega pool alpha tamed (%.2f)" % pool.albedo_color.a)
		var bad: Array = []
		for cname in People.PEDESTRIANS:
			var body: Node3D = People.spawn(cname)
			if body == null or People.find_ap(body) == null:
				bad.append(cname)
		_ok(bad.is_empty(), "all casts spawn with rigs (%s)" % str(bad))
		main.call("start_game")
	elif frames == 400:
		var npcs: Array = main.get("_npcs")
		var standing: Array = []
		for n in npcs:
			if bool(n.get("_standing")):
				standing.append(n)
		var mind: float = 1e9
		for i in range(standing.size()):
			for j in range(i + 1, standing.size()):
				var d: float = (standing[i] as Node3D).global_position.distance_to(
					(standing[j] as Node3D).global_position)
				mind = minf(mind, d)
		_ok(mind > 0.45, "standing NPCs separated (min %.2f m)" % mind)
		var player: Node3D = main.get("player")
		player.global_position = Vector3(0, -20, 0)
	elif frames == 430:
		var player: Node3D = main.get("player")
		_ok(player.global_position.y > 0.0, "fall-out rescue (y=%.2f)" % player.global_position.y)
		print("TEST DONE failed=", fails > 0)
		quit(0 if fails == 0 else 1)
	return false
