extends SceneTree
## v2.4 visual check: (1) flying hover car in the air, (2) player wall-climbing.
var frames: int = 0
var main: Node
var player: Node
var car: Node
var stage: int = 0
var _target_b: Dictionary = {}

func _initialize() -> void:
	var ps: PackedScene = load("res://main.tscn")
	main = ps.instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 8:
		main.call("start_game")
		player = main.get("player")
		player.set("input_enabled", false)
		for c in main.get("_cars"):
			if String(c.get("mode")) == "parked":
				car = c
				break
		player.global_position = (car as Node3D).global_position + Vector3(2.0, 0.5, 0.0)
	elif frames == 14:
		main.call("interact")
		main.call("toggle_flight")
		main.set("touch_drive", Vector2(0, 1))  # climb
	elif frames == 170:
		main.set("touch_drive", Vector2.ZERO)
		root.get_texture().get_image().save_png("res://shots/v17_a_fly.png")
		print("saved v17_a_fly (car y %.1f flying=%s)" % [(car as Node3D).global_position.y, str(bool(car.get("flying")))])
		main.call("interact")
		player.set("hp", 100.0)
		var city: Node = main.get("city")
		for b in city.get("_buildings"):
			var h: float = b["height"]
			var fp: Vector2 = b["fp"]
			if h >= 12.0 and h <= 26.0 and fp.x >= 24.0:
				_target_b = b
				break
		var c: Vector3 = _target_b["center"]
		var fp2: Vector2 = _target_b["fp"]
		player.global_position = Vector3(c.x, 0.35, c.z + fp2.y * 0.5 + 0.75)
		player.set("velocity", Vector3.ZERO)
		player.set("yaw", 0.0)
		player.call("make_camera_current")
		player.set("touch_move", Vector2(0, -1))
		stage = 1
	elif stage == 1 and frames == 178:
		player.call("queue_jump")
	elif stage == 1 and frames == 320:
		root.get_texture().get_image().save_png("res://shots/v17_b_climb.png")
		print("saved v17_b_climb (player y %.1f climbing=%s)" % [player.global_position.y, str(bool(player.get("_climbing")))])
		player.set("touch_move", Vector2.ZERO)
		quit(0)
		return true
	return false
