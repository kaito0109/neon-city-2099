extends SceneTree
## v2.6 phone-path test (Xvfb, touch emulation OFF — run with a
## temporary override.cfg): the flight flow in phone order through
## the real input layers available headless — the joystick and look
## drags are real touch events (script _input path), while the
## button hops call the same handlers the buttons call (GUI picking
## of injected events does not work under a script main loop; the
## buttons themselves are proven on the real device):
##   enter car | FLY on | stick DOWN -> descend | BRK -> reverse
##   right-side drag -> car camera orbits
var frames: int = 0
var main: Node
var hud: Node
var player: Node
var car: Node
var failed: bool = false
var phase: int = 0
var _phase_t: int = 0
var _y0: float = 0.0
var _pos0: Vector3 = Vector3.ZERO
var _stick_c: Vector2 = Vector2.ZERO

func _ok(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		failed = true

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _touch(index: int, pressed: bool, pos: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.pressed = pressed
	ev.position = pos
	Input.parse_input_event(ev)

func _drag(index: int, pos: Vector2, rel: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	ev.relative = rel
	Input.parse_input_event(ev)

func _btn(id: String) -> Vector2:
	var b: Button = (hud.get("touch_buttons") as Dictionary)[id]
	return b.get_global_rect().get_center()

func _tap(id: String, index: int) -> void:
	var c: Vector2 = _btn(id)
	_touch(index, true, c)
	_touch(index, false, c)

func _process(_delta: float) -> bool:
	frames += 1
	_phase_t += 1
	match phase:
		0:
			if frames == 10:
				main.call("start_game")
				hud = main.get("hud")
				# A real phone reports a touchscreen, so the touch UI
				# is visible before the first tap; Xvfb does not.
				hud.set("touch_mode", true)
				player = main.get("player")
				for c in main.get("_cars"):
					if String(c.get("mode")) == "parked":
						car = c
						break
				player.global_position = (car as Node3D).global_position + Vector3(2.0, 0.5, 0.0)
				player.set("velocity", Vector3.ZERO)
			elif frames == 18:
				main.call("interact")  # the ACT button's handler
				phase = 1
				_phase_t = 0
		1:
			if _phase_t == 8:
				_ok(player.get("in_car") != null, "entered car (ACT handler)")
				main.call("toggle_flight")  # the FLY button's handler
				phase = 2
				_phase_t = 0
		2:
			if _phase_t == 50:
				_ok(bool(car.get("flying")), "flight engaged via FLY tap")
				_y0 = (car as Node3D).global_position.y
				_ok(_y0 > 1.5, "took off (y %.1f)" % _y0)
				# Push the stick DOWN with touch 0 and hold it there.
				var joy: Control = hud.get("joystick")
				_stick_c = joy.get_global_rect().get_center()
				_touch(0, true, _stick_c)
				_drag(0, _stick_c + Vector2(0, 62), Vector2(0, 62))
				phase = 3
				_phase_t = 0
		3:
			if _phase_t == 70:
				var y1: float = (car as Node3D).global_position.y
				_ok(_y0 > 3.0 and (y1 < _y0 - 1.5 or not bool(car.get("flying"))), "stick DOWN descended the car (y %.1f -> %.1f)" % [_y0, y1])
				_touch(0, false, _stick_c + Vector2(0, 62))
				# Re-climb a little for the reverse check if we landed.
				if not bool(car.get("flying")):
					main.call("toggle_flight")
				phase = 4
				_phase_t = 0
		4:
			if _phase_t == 45:
				_pos0 = (car as Node3D).global_position
				hud.set("_brk", true)  # the state the BRK button sets
				phase = 5
				_phase_t = 0
		5:
			if _phase_t == 100:
				var sp: float = float(car.get("speed"))
				_ok(sp < -3.0, "BRK gives reverse thrust in flight (speed %.1f)" % sp)
				hud.set("_brk", false)
				# Look drag on the right side must orbit the car camera.
				_touch(1, true, Vector2(760, 240))
				phase = 6
				_phase_t = 0
		6:
			if _phase_t >= 4 and _phase_t <= 44 and _phase_t % 4 == 0:
				_drag(1, Vector2(760 + float(_phase_t) * 3.0, 240), Vector2(12, 0))
			if _phase_t == 50:
				_ok(absf(float(car.get("look_yaw"))) > 0.25, "look drag orbits the car camera (yaw %.2f)" % float(car.get("look_yaw")))
				_touch(1, false, Vector2(880, 240))
				print("V20 TOUCH TEST DONE")
				quit(1 if failed else 0)
				return true
	return false
