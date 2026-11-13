extends SceneTree
## v2.6 regression: reverse thrust sign. The flight branch computed
## throttle * -17 for BRK, i.e. full FORWARD thrust (the ground
## branch was fine — its REV_SPEED constant is signed). BRK must
## drive speed negative on the ground and in flight.
var frames: int = 0
var phase: int = 0
var main: Node
var player: Node
var car: Node
var failed: bool = false
var _phase_t: int = 0

func _ok(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		failed = true

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_delta: float) -> bool:
	frames += 1
	_phase_t += 1
	match phase:
		0:
			if frames == 10:
				main.call("start_game")
				player = main.get("player")
				for c in main.get("_cars"):
					if String(c.get("mode")) == "parked":
						car = c
						break
				player.global_position = (car as Node3D).global_position + Vector3(2.0, 0.5, 0.0)
				player.set("velocity", Vector3.ZERO)
			elif frames == 16:
				main.call("interact")
				main.set("touch_drive", Vector2(0, -1))  # BRK on ground
				phase = 1
				_phase_t = 0
		1:
			if _phase_t == 70:
				_ok(float(car.get("speed")) < -3.0, "ground reverse (speed %.1f)" % float(car.get("speed")))
				main.set("touch_drive", Vector2.ZERO)
				main.call("toggle_flight")
				phase = 2
				_phase_t = 0
		2:
			if _phase_t == 50:
				_ok(bool(car.get("flying")), "flight on for reverse check")
				main.set("touch_drive", Vector2(0, -1))  # BRK in flight
				phase = 3
				_phase_t = 0
		3:
			if _phase_t == 80:
				_ok(float(car.get("speed")) < -6.0, "flight reverse (speed %.1f)" % float(car.get("speed")))
				main.set("touch_drive", Vector2.ZERO)
				print("V21 TEST DONE")
				quit(1 if failed else 0)
				return true
	return false
