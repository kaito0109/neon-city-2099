extends SceneTree
## v5.3 numbers: tilt-jerk on the terrace climb + bridge, and the
## off-road bog check (straight up a bare bank vs the switchback road).
var frames: int = 0
var main: Node
var car: Node3D
var stage: int = 0
var stage_t: int = 0
var prev_tilt: float = 0.0
var worst: float = 0.0
var max_speed: float = 0.0

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _tilt() -> float:
	var up: Vector3 = car.global_transform.basis.y.normalized()
	return rad_to_deg(acos(clampf(up.dot(Vector3.UP), -1.0, 1.0)))

func _sample() -> void:
	var t: float = _tilt()
	worst = maxf(worst, absf(t - prev_tilt) * 60.0)
	prev_tilt = t
	max_speed = maxf(max_speed, absf(float(car.get("speed"))))

func _leg(car_pos: Vector3, heading: float) -> void:
	car.global_position = car_pos
	car.set("heading", heading)
	car.rotation.y = heading
	car.set("speed", 0.0)
	prev_tilt = _tilt()
	worst = 0.0
	max_speed = 0.0
	main.set("touch_drive", Vector2(0, 1.0))

func _process(_delta: float) -> bool:
	frames += 1
	stage_t += 1
	if frames == 20 and stage == 0:
		main.call("start_game")
		stage = 1
		stage_t = 0
	elif stage == 1 and stage_t > 30:
		car = (main.get("_cars") as Array)[3]
		car.call("set_driven", true)
		_leg(Vector3(58, 2.5, -60), -0.89)  # terrace climb (road)
		stage = 2
		stage_t = 0
	elif stage == 2:
		if stage_t > 30:
			_sample()
		if stage_t >= 360:
			main.set("touch_drive", Vector2.ZERO)
			print("ROAD leg: worst tilt rate %.1f deg/s, max speed %.1f, end %s" % [worst, max_speed, car.global_position])
			_leg(Vector3(120, 3.5, -64), -0.95)  # straight up the bare bank
			stage = 3
			stage_t = 0
	elif stage == 3:
		if stage_t > 30:
			_sample()
		if stage_t >= 300:
			main.set("touch_drive", Vector2.ZERO)
			print("BANK leg: worst tilt rate %.1f deg/s, max speed %.1f, end %s" % [worst, max_speed, car.global_position])
			_leg(Vector3(0, 2.5, 148), PI)  # canal bridge
			stage = 4
			stage_t = 0
	elif stage == 4:
		if stage_t > 30:
			_sample()
		if stage_t >= 240:
			main.set("touch_drive", Vector2.ZERO)
			print("BRIDGE leg: worst tilt rate %.1f deg/s, max speed %.1f, end %s" % [worst, max_speed, car.global_position])
			for c in main.get("_cars"):
				var cp: Vector3 = (c as Node3D).global_position
				if Vector2(cp.x, cp.z - 170.0).length() < 25.0:
					print("  nearby car: mode=", c.get("mode"), " pos=", cp)
			print("NUMBERS DONE")
			quit()
			return true
	return false
