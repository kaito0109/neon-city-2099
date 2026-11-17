extends SceneTree
## Probe 2: follow one street car and one deck car; log speed,
## collisions and stuck timer to find where traffic bleeds speed.
var frames: int = 0
var main: Node
var car_a: Node3D
var car_d: Node3D
var last_a: Vector3 = Vector3.ZERO

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 20:
		main.call("start_game")
		for c in get_nodes_in_group("cars"):
			if String(c.get("mode")) == "traffic":
				car_a = c
				break
		car_d = get_nodes_in_group("deck_traffic")[0]
		last_a = car_a.global_position
	if frames > 20 and frames % 120 == 0:
		var va: Vector3 = car_a.global_position - last_a
		va.y = 0.0
		last_a = car_a.global_position
		print("t=", frames / 60,
				" | street pos=", car_a.global_position,
				" spd=", snappedf(float(car_a.get("speed")), 0.1),
				" cruise=", snappedf(float(car_a.get("_cruise_speed")), 0.1),
				" wp=", car_a.get("_wp"),
				" stuck=", snappedf(float(car_a.get("_stuck_t")), 0.1),
				" moved2s=", snappedf(va.length(), 0.1),
				" | deck pos=", car_d.global_position,
				" dspd=", snappedf(float(car_d.get("speed")), 0.1),
				" dwp=", car_d.get("_wp"),
				" dstuck=", snappedf(float(car_d.get("_stuck_t")), 0.1))
	if frames >= 2420:
		print("PROBE2 DONE")
		quit()
	return false
