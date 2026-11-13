extends SceneTree
## v2.4 roof-finish check: (a) standing on a roof, (b) flying over roofs.
var frames: int = 0
var main: Node
var player: Node
var stage: int = 0

func _initialize() -> void:
	var ps: PackedScene = load("res://main.tscn")
	main = ps.instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 8:
		main.call("start_game")
		player = main.get("player")
		var city: Node = main.get("city")
		var best: Dictionary = {}
		for b in city.get("_buildings"):
			var h: float = b["height"]
			var fp: Vector2 = b["fp"]
			if h >= 20.0 and h <= 30.0 and fp.x >= 26.0:
				best = b
				break
		var c: Vector3 = best["center"]
		player.global_position = Vector3(c.x + 4.0, float(best["height"]) + 0.6, c.z + 4.0)
		player.set("velocity", Vector3.ZERO)
		player.set("yaw", 2.4)
		player.set("pitch", -0.32)
		player.call("_apply_camera")
	elif frames == 45 and stage == 0:
		root.get_texture().get_image().save_png("res://shots/v24_a_roof.png")
		print("saved v24_a_roof y=%.2f" % player.global_position.y)
		stage = 1
		# Flight over the rooftops.
		var car: Node = null
		for c in main.get("_cars"):
			if String(c.get("mode")) == "parked":
				car = c
				break
		player.global_position = (car as Node3D).global_position + Vector3(2.0, 0.5, 0.0)
		player.set("pitch", -0.18)
	elif frames == 52 and stage == 1:
		main.call("interact")
		main.call("toggle_flight")
		var car2: Node = player.get("in_car")
		(car2 as Node3D).global_position = Vector3(6.0, 34.0, 205.0)
		car2.set("heading", 0.0)
		car2.set("velocity", Vector3.ZERO)
		main.set("touch_drive", Vector2(0, 0.25))
		stage = 2
	elif frames == 150 and stage == 2:
		root.get_texture().get_image().save_png("res://shots/v24_b_air.png")
		print("saved v24_b_air")
		quit(0)
		return true
	return false
