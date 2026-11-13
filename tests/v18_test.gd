extends SceneTree
## v2.5 flight controls, phone order:
##  1. toggle FLY with NO input: flight persists, takeoff assist lifts
##  2. stick up (touch_vertical) climbs; release hovers in place
##  3. GAS is thrust: the car translates forward while airborne
##  4. stick down descends and lands on the expressway deck (solid now)
var frames: int = 0
var phase: int = 0
var main: Node
var player: Node
var car: Node
var failed: bool = false
var _phase_t: int = 0
var _hover_y: float = 0.0
var _hover_pos: Vector3 = Vector3.ZERO

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
				main.set("touch_vertical", 1.0)  # stick up: climb
				phase = 2
				_phase_t = 0
		2:
			if _phase_t == 90:
				_hover_y = (car as Node3D).global_position.y
				_hover_pos = (car as Node3D).global_position
				_ok(_hover_y > 8.0, "climbed on stick-up (y %.1f)" % _hover_y)
				main.set("touch_vertical", 0.0)
				main.set("touch_drive", Vector2(0, 1))  # GAS: thrust
				phase = 3
				_phase_t = 0
		3:
			if _phase_t == 70:
				var p: Vector3 = (car as Node3D).global_position
				var moved: float = Vector2(p.x - _hover_pos.x, p.z - _hover_pos.z).length()
				_ok(moved > 8.0, "GAS thrust moves the car in flight (moved %.1f m)" % moved)
				_ok(bool(car.get("flying")), "still flying after thrust")
				main.set("touch_drive", Vector2.ZERO)
				# Move over the expressway deck and descend onto it.
				(car as Node3D).global_position = Vector3(0.0, 16.0, 40.0)
				car.set("velocity", Vector3.ZERO)
				car.set("speed", 0.0)
				main.set("touch_vertical", -1.0)  # stick down: descend
				phase = 4
				_phase_t = 0
		4:
			if not bool(car.get("flying")):
				var y: float = (car as Node3D).global_position.y
				_ok(y > 9.0 and y < 12.0, "landed ON the expressway deck (y %.1f)" % y)
				main.set("touch_vertical", 0.0)
				print("V18 TEST DONE")
				quit(1 if failed else 0)
				return true
			if _phase_t > 400:
				_ok(false, "landed on the deck (timeout, y %.1f)" % (car as Node3D).global_position.y)
				print("V18 TEST DONE")
				quit(1 if failed else 0)
				return true
	return false
