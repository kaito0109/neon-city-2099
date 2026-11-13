extends SceneTree
## v2.4.1 regression: the phone takeoff sequence — toggle FLY with NO
## climb input held (the grounded car must not read as "landed" and
## cancel flight), then climb / hover / descend / land.
var frames: int = 0
var phase: int = 0
var main: Node
var player: Node
var car: Node
var failed: bool = false
var _phase_t: int = 0
var _hover_y: float = 0.0

func _ok(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		failed = true

func _initialize() -> void:
	var ps: PackedScene = load("res://main.tscn")
	main = ps.instantiate()
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
				# Phone sequence: tap FLY, no other input at all.
				main.call("toggle_flight")
				phase = 1
				_phase_t = 0
		1:
			if _phase_t == 40:
				_ok(bool(car.get("flying")), "flight persists with no input (not self-cancelled)")
				_ok((car as Node3D).global_position.y > 1.6, "takeoff assist lifted the car (y %.1f)" % (car as Node3D).global_position.y)
				main.set("touch_drive", Vector2(0, 1))  # GAS: climb
				phase = 2
				_phase_t = 0
		2:
			if _phase_t == 90:
				_hover_y = (car as Node3D).global_position.y
				_ok(_hover_y > 8.0, "climbed on GAS (y %.1f)" % _hover_y)
				main.set("touch_drive", Vector2.ZERO)  # release: hover
				phase = 3
				_phase_t = 0
		3:
			if _phase_t == 50:
				var y: float = (car as Node3D).global_position.y
				_ok(bool(car.get("flying")) and absf(y - _hover_y) < 1.5, "hover holds altitude (y %.1f)" % y)
				main.set("touch_drive", Vector2(0, -1))  # BRK: descend
				phase = 4
				_phase_t = 0
		4:
			if not bool(car.get("flying")):
				_ok(true, "descended and landed, flight off")
				main.set("touch_drive", Vector2.ZERO)
				print("V18 TEST DONE")
				quit(1 if failed else 0)
				return true
			if _phase_t > 400:
				_ok(false, "descended and landed (timeout)")
				print("V18 TEST DONE")
				quit(1 if failed else 0)
				return true
	return false
