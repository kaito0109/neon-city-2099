extends SceneTree
## Probe: why are deck cars frozen, and where do street cars stray?
var frames: int = 0
var main: Node
var deck0: Node3D
var street: Array = []
var loops: Array = []

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = b - a
	ab.y = 0.0
	var ap: Vector3 = p - a
	ap.y = 0.0
	var t: float = 0.0
	if ab.length() > 0.001:
		t = clampf(ap.dot(ab) / ab.length_squared(), 0.0, 1.0)
	var q: Vector3 = a + ab * t
	return Vector2(p.x - q.x, p.z - q.z).length()

func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 20:
		main.call("start_game")
		var city: Node = main.get("city")
		loops = city.get("traffic_loops")
		var dk: Array = get_nodes_in_group("deck_traffic")
		deck0 = dk[0]
		print("deck0 loop size: ", (deck0.get("_loop") as Array).size(),
				" cruise: ", deck0.get("_cruise_speed"),
				" speed: ", deck0.get("speed"), " mode: ", deck0.get("mode"))
		for c in get_nodes_in_group("cars"):
			if String(c.get("mode")) == "traffic":
				street.append(c)
	if frames > 20 and frames % 150 == 0:
		var worst: float = 0.0
		var worst_pos: Vector3 = Vector3.ZERO
		for c in street:
			var p: Vector3 = (c as Node3D).global_position
			var lat: float = 1e9
			for lp in loops:
				for i in range(lp.size()):
					lat = minf(lat, _seg_dist(p, lp[i], lp[(i + 1) % lp.size()]))
			if lat > worst:
				worst = lat
				worst_pos = p
		print("t=", frames / 60, " deck0 pos: ", deck0.global_position,
				" speed: ", snappedf(float(deck0.get("speed")), 0.1),
				" | worst street lateral: ", snappedf(worst, 0.01), " at ", worst_pos)
	if frames >= 920:
		print("PROBE DONE")
		quit()
	return false
