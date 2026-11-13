extends SceneTree
## v2.4 flight + parkour checks:
##  1. car takes off in flight mode and climbs on throttle
##  2. mid-air exit: player falls, takes fall damage, lands; car falls too
##  3. double jump fires in mid-air
##  4. wall climb: grab a facade, climb, wall-jump off
##  5. mantle: climbing a short tower ends standing on its roof
var frames: int = 0
var phase: int = 0
var main: Node
var player: Node
var car: Node
var failed: bool = false
var _phase_t: int = 0
var _start_y: float = 0.0
var _target_b: Dictionary = {}

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
				# Find a parked car and step in.
				for c in main.get("_cars"):
					if String(c.get("mode")) == "parked":
						car = c
						break
				player.global_position = (car as Node3D).global_position + Vector3(2.0, 0.5, 0.0)
				player.set("velocity", Vector3.ZERO)
			elif frames == 16:
				main.call("interact")
				_ok(player.get("in_car") == car, "entered parked car")
				main.call("toggle_flight")
				_ok(bool(car.get("flying")), "flight mode on")
				main.set("touch_drive", Vector2(0, 1))  # GAS: climb
				_start_y = (car as Node3D).global_position.y
				phase = 1
				_phase_t = 0
		1:
			if _phase_t == 150:  # ~2.5 s of climb
				var y: float = (car as Node3D).global_position.y
				main.set("touch_drive", Vector2.ZERO)
				_ok(y > _start_y + 6.0, "car climbed in flight (y %.1f -> %.1f)" % [_start_y, y])
				# Move to a known spot (roof at y~17 below) for a
				# deterministic bail-out fall.
				(car as Node3D).global_position = Vector3(20.0, 30.0, 150.0)
				car.set("velocity", Vector3.ZERO)
				car.set("speed", 0.0)
			elif _phase_t == 158:
				# Bail out mid-air.
				main.call("interact")
				_ok(player.get("in_car") == null, "exited mid-air")
				phase = 2
				_phase_t = 0
		2:
			if (player as CharacterBody3D).is_on_floor() and _phase_t > 10:
				_ok(true, "player fell and landed")
				phase = 25
				_phase_t = 0
			elif _phase_t > 600:
				_ok(false, "player fell and landed (timeout)")
				phase = 3
				_phase_t = 0
		25:
			# Landing damage is applied on the player's next tick.
			if _phase_t == 12:
				_ok(float(player.get("hp")) < 100.0, "fall damage applied (hp %.1f)" % float(player.get("hp")))
				phase = 3
				_phase_t = 0
			elif _phase_t > 600:
				_ok(false, "player fell and landed (timeout)")
				phase = 3
				_phase_t = 0
		3:
			if _phase_t == 240:  # give the abandoned car time to drop
				_ok((car as CharacterBody3D).is_on_floor(), "abandoned car fell and landed (y %.1f)" % (car as Node3D).global_position.y)
				# Double jump setup: centre of a road crossing (fixed
				# grid, no building faces within ray range), facing +X.
				player.global_position = Vector3(0.0, 0.4, 180.0)
				player.set("velocity", Vector3.ZERO)
				player.set("hp", 100.0)
				player.set("yaw", -PI / 2.0)
				player.set("_model_yaw", PI / 2.0)
			elif _phase_t == 270:
				player.call("queue_jump")  # 240 teleport + 30 frames: surely grounded (was 250: still falling 0.4 m, queue was eaten as the air jump)
			elif _phase_t == 282:
				_ok(not (player as CharacterBody3D).is_on_floor(), "airborne after first jump")
				player.call("queue_jump")
			elif _phase_t == 286:
				_ok(int(player.get("_air_jumps")) == 1 and float((player as CharacterBody3D).velocity.y) > 4.0,
					"double jump fired (vy %.1f)" % (player as CharacterBody3D).velocity.y)
				phase = 4
				_phase_t = 0
		4:
			if _phase_t == 30:
				# Pick a mid-size tower and stand south of its south face.
				var city: Node = main.get("city")
				var best: Dictionary = {}
				for b in city.get("_buildings"):
					var h: float = b["height"]
					var fp: Vector2 = b["fp"]
					if h >= 12.0 and h <= 26.0 and fp.x >= 24.0:
						best = b
						break
				_target_b = best
				_ok(not best.is_empty(), "climb target building found")
				var c: Vector3 = best["center"]
				var fp2: Vector2 = best["fp"]
				player.global_position = Vector3(c.x, 0.35, c.z + fp2.y * 0.5 + 0.75)
				player.set("velocity", Vector3.ZERO)
				player.set("yaw", 0.0)  # face -Z, toward the wall
				player.set("touch_move", Vector2(0, -1))  # hold forward
			elif _phase_t == 36:
				player.call("queue_jump")
			elif _phase_t == 200:
				_ok(bool(player.get("_climbing")), "wall climb engaged")
				_ok(player.global_position.y > 2.5, "climbed up the wall (y %.1f)" % player.global_position.y)
				player.call("queue_jump")  # wall jump
			elif _phase_t == 204:
				_ok(not bool(player.get("_climbing")) and float((player as CharacterBody3D).velocity.y) > 4.0,
					"wall jump fired (vy %.1f)" % (player as CharacterBody3D).velocity.y)
				player.set("touch_move", Vector2.ZERO)
				phase = 5
				_phase_t = 0
		5:
			if _phase_t == 40:
				# Mantle run: same wall, climb to the top this time.
				var c2: Vector3 = _target_b["center"]
				var fp3: Vector2 = _target_b["fp"]
				player.global_position = Vector3(c2.x, 0.35, c2.z + fp3.y * 0.5 + 0.75)
				player.set("velocity", Vector3.ZERO)
				player.set("yaw", 0.0)
				player.set("touch_move", Vector2(0, -1))
			elif _phase_t == 46:
				player.call("queue_jump")
			elif _phase_t > 46 and _phase_t % 60 == 0:
				# Keep holding forward; done when standing on the roof.
				var h: float = _target_b["height"]
				if (player as CharacterBody3D).is_on_floor() and player.global_position.y > h - 1.5:
					_ok(true, "mantled onto the roof (y %.1f / h %.1f)" % [player.global_position.y, h])
					player.set("touch_move", Vector2.ZERO)
					print("V17 TEST DONE")
					quit(1 if failed else 0)
					return true
				if _phase_t > 1400:
					_ok(false, "mantled onto the roof (timeout, y %.1f / h %.1f)" % [player.global_position.y, h])
					print("V17 TEST DONE")
					quit(1 if failed else 0)
					return true
	return false
