extends SceneTree
var frames: int = 0
var main: Node
var car: Node3D
var stage: int = 0
var stage_t: int = 0

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

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
		car.global_position = Vector3(0, 2.5, 96)
		car.set("heading", PI)
		car.rotation.y = PI
		car.set("speed", 0.0)
		main.set("touch_drive", Vector2(0, 1.0))
		stage = 2
		stage_t = 0
	elif stage == 2:
		if stage_t % 30 == 0:
			var cols: String = ""
			for ci in range(car.get_slide_collision_count()):
				var c: KinematicCollision3D = car.get_slide_collision(ci)
				cols += " [n=%s]" % c.get_normal()
			print("t=%d pos=%s spd=%.1f floor=%s base_y=%.2f gy=%.2f%s" % [stage_t, car.global_position, float(car.get("speed")), car.is_on_floor(), float(car.get("_base_y")), float(car.call("_ground_y_below")), cols])
		if stage_t >= 200:
			main.set("touch_drive", Vector2.ZERO)
			print("BRIDGE DRIVE DONE end=", car.global_position)
			quit()
			return true
	return false
