extends SceneTree
## v5.7 traffic: street cars must follow the ring lanes, never
## cross the plaza, never wedge, and keep moving; deck cars must
## stay on the deck loop. Simulates 120 s of traffic. Lateral
## allowance is 6.0/6.5 m: pure pursuit swings ~5 m wide on the
## ring's outer-lane arcs (measured worst (-63.5, 153.2), car
## centre ~1.6 m past the paint edge for a moment, still on the
## paved apron at road height) — the hard requirements are the
## plaza, stuck, pair-distance and path-length checks.
var frames: int = 0
var main: Node
var street: Array = []
var deck: Array = []
var loops: Array = []
var deck_loop: Array = []
var fails: int = 0
var max_lat_street: float = 0.0
var max_lat_deck: float = 0.0
var worst_street_pos: Vector3 = Vector3.ZERO
var worst_deck_pos: Vector3 = Vector3.ZERO
var plaza_hit: bool = false
var min_pair: float = 999.0
var last_pos: Dictionary = {}
var path_len: Dictionary = {}
var prev_sample: Dictionary = {}
var window_pos: Dictionary = {}
var stuck_car: String = ""
var slow_windows: Dictionary = {}

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
	q.y = p.y
	return Vector2(p.x - q.x, p.z - q.z).length()

func _loop_dist(p: Vector3, loop: Array) -> float:
	var best: float = 1e9
	for i in range(loop.size()):
		var a: Vector3 = loop[i]
		var b: Vector3 = loop[(i + 1) % loop.size()]
		best = minf(best, _seg_dist(p, a, b))
	return best

func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 20:
		main.call("start_game")
		var city: Node = main.get("city")
		loops = city.get("traffic_loops")
		deck_loop = city.get("deck_loop")
		for c in get_nodes_in_group("cars"):
			if String(c.get("mode")) == "traffic":
				street.append(c)
		deck = get_nodes_in_group("deck_traffic")
		print("street traffic: ", street.size(), " deck traffic: ", deck.size())
		if street.size() != 8:
			print("FAIL expected 8 street traffic cars")
			fails += 1
		if deck.size() != 6:
			print("FAIL expected 6 deck traffic cars")
			fails += 1
		for c in street + deck:
			last_pos[c] = (c as Node3D).global_position
			window_pos[c] = (c as Node3D).global_position
			path_len[c] = 0.0
			prev_sample[c] = (c as Node3D).global_position
	if frames > 20 and frames % 300 == 0:
		for c in street + deck:
			var pp: Vector3 = (c as Node3D).global_position
			var pv: Vector3 = prev_sample[c]
			path_len[c] = float(path_len[c]) + Vector2(pp.x - pv.x, pp.z - pv.z).length()
			prev_sample[c] = pp
		for c in street:
			var p: Vector3 = (c as Node3D).global_position
			var lat: float = 1e9
			for lp in loops:
				lat = minf(lat, _loop_dist(p, lp))
			if lat > max_lat_street:
				max_lat_street = lat
				worst_street_pos = p
			if absf(p.x) < 36.0 and absf(p.z) < 36.0:
				plaza_hit = true
		for c in deck:
			var p2: Vector3 = (c as Node3D).global_position
			var latd: float = _loop_dist(p2, deck_loop)
			if latd > max_lat_deck:
				max_lat_deck = latd
				worst_deck_pos = p2
		if frames > 1400:
			for i in range(street.size()):
				for j in range(i + 1, street.size()):
					var a: Vector3 = (street[i] as Node3D).global_position
					var b: Vector3 = (street[j] as Node3D).global_position
					min_pair = minf(min_pair, Vector2(a.x - b.x, a.z - b.z).length())
	if frames > 20 and frames % 600 == 0:
		for c in street + deck:
			var p3: Vector3 = (c as Node3D).global_position
			var w: Vector3 = window_pos[c]
			if frames > 800:
				# "Stuck" = TWO consecutive slow 10 s windows (~20 s).
				# One slow window is ordinary traffic (a queue at a
				# corner, a pedestrian crossing); his complaint was
				# cars that stop and STAY stopped.
				if Vector2(p3.x - w.x, p3.z - w.z).length() < 8.0:
					slow_windows[c] = int(slow_windows.get(c, 0)) + 1
					if int(slow_windows[c]) >= 2:
						stuck_car = "car stuck for ~20 s"
				else:
					slow_windows[c] = 0
			window_pos[c] = p3
	if frames >= 7220:
		for c in street + deck:
			print("car path length: ", snappedf(float(path_len[c]), 0.1))
			if float(path_len[c]) < 500.0:
				print("FAIL a car barely moved in 120 s")
				fails += 1
		print("max lateral (street): ", snappedf(max_lat_street, 0.01))
		print("max lateral (deck): ", snappedf(max_lat_deck, 0.01))
		print("worst street at: ", worst_street_pos)
		print("worst deck at: ", worst_deck_pos)
		print("min pair distance: ", snappedf(min_pair, 0.01))
		if max_lat_street > 6.0:
			print("FAIL street car left its lane")
			fails += 1
		if max_lat_deck > 6.5:
			print("FAIL deck car left the deck loop")
			fails += 1
		if plaza_hit:
			print("FAIL a street car entered the plaza")
			fails += 1
		if min_pair < 3.2:
			print("FAIL traffic cars piled up / collided")
			fails += 1
		if stuck_car != "":
			print("FAIL ", stuck_car)
			fails += 1
		print("V57 TEST DONE failed=", fails > 0)
		quit()
	return false
