extends SceneTree
## Car/road diagnosis for his 2026-11-16 report (roads feel incomplete,
## car behaviour feels off). Drives the terrace climb + a canal bridge,
## logging body-tilt jerk; also photographs the under-deck ground and
## other road seams.
var frames: int = 0
var main: Node
var car: Node3D
var cam: Camera3D
var stage: int = 0
var stage_t: int = 0
var prev_tilt: float = 0.0
var worst: Array = []  # [rate, pos, leg]
var shot_spots: Array = [
	[Vector3(-6, 2.2, -48), Vector3(10, 0.5, -72), "v51_underdeck.png"],
	[Vector3(14, 7.0, 148), Vector3(0, 0.0, 180), "v51_bridge.png"],
	[Vector3(120, 20.0, -84), Vector3(170, 8.0, -130), "v51_terrace.png"],
	[Vector3(30, 4.0, -30), Vector3(60, 1.0, -60), "v51_avenue.png"],
]
var shot_i: int = 0

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	cam = Camera3D.new()
	cam.far = 400.0
	root.add_child(cam)

func _print_worst(leg: String) -> void:
	print("WORST TILT RATES after ", leg, " (deg/s):")
	for w in worst:
		print("  ", snappedf(w[0], 0.1), " at ", w[1], " leg=", w[2])
	worst.clear()

func _tilt() -> float:
	var up: Vector3 = car.global_transform.basis.y.normalized()
	return rad_to_deg(acos(clampf(up.dot(Vector3.UP), -1.0, 1.0)))

func _sample(leg: String) -> void:
	var t: float = _tilt()
	var rate: float = absf(t - prev_tilt) * 60.0  # deg per second-ish
	prev_tilt = t
	if rate > 25.0:
		worst.append([rate, car.global_position, leg])
		worst.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		if worst.size() > 6:
			worst.pop_back()

func _process(_delta: float) -> bool:
	frames += 1
	stage_t += 1
	if frames == 20 and stage == 0:
		main.call("start_game")
		cam.make_current()
		stage = 1
		stage_t = 0
	elif stage == 1:
		if stage_t % 12 == 0 and shot_i < shot_spots.size():
			var s: Array = shot_spots[shot_i]
			cam.global_position = s[0]
			cam.look_at(s[1], Vector3.UP)
			shot_i += 1
		elif stage_t % 12 == 6 and shot_i >= 1 and shot_i <= shot_spots.size():
			var s2: Array = shot_spots[shot_i - 1]
			root.get_texture().get_image().save_png("res://shots/" + s2[2])
			print("saved ", s2[2])
		if shot_i >= shot_spots.size() and stage_t > 60:
			car = (main.get("_cars") as Array)[3]
			car.global_position = Vector3(58, 2.5, -60)
			car.set("heading", -0.89)
			car.rotation.y = -0.89
			car.call("set_driven", true)
			main.set("touch_drive", Vector2(0, 1.0))
			prev_tilt = _tilt()
			stage = 2
			stage_t = 0
	elif stage == 2:
		_sample("terrace")
		cam.global_position = car.global_position + Vector3(6.5, 3.5, 6.5)
		cam.look_at(car.global_position + Vector3(0, 0.8, 0), Vector3.UP)
		if stage_t == 200:
			root.get_texture().get_image().save_png("res://shots/v51_climb.png")
			print("saved climb shot at ", car.global_position)
		if stage_t >= 400:
			main.set("touch_drive", Vector2.ZERO)
			print("terrace end pos=", car.global_position)
			_print_worst("terrace")
			car.global_position = Vector3(0, 2.5, 148)
			car.set("heading", PI)
			car.rotation.y = PI
			prev_tilt = _tilt()
			stage = 3
			stage_t = 0
			main.set("touch_drive", Vector2(0, 1.0))
	elif stage == 3:
		_sample("bridge")
		cam.global_position = car.global_position + Vector3(6.5, 3.5, -6.5)
		cam.look_at(car.global_position + Vector3(0, 0.8, 0), Vector3.UP)
		if stage_t == 150:
			root.get_texture().get_image().save_png("res://shots/v51_crossing.png")
			print("saved crossing shot at ", car.global_position)
		if stage_t >= 300:
			main.set("touch_drive", Vector2.ZERO)
			print("bridge end pos=", car.global_position)
			_print_worst("bridge")
			print("DRIVE DIAG DONE")
			quit()
			return true
	return false
