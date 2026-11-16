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
		stage = 2
		stage_t = 0
	elif stage == 2:
		if stage_t % 20 == 0:
			print("t=%d y=%.3f vy=%.2f floor=%s slides=%d layer=%d mask=%d" % [
				stage_t, car.global_position.y, (car.get("velocity") as Vector3).y,
				car.is_on_floor(), car.get_slide_collision_count(),
				car.get_collision_layer(), car.get_collision_mask()])
		if stage_t >= 240:
			print("STAND DONE y=", car.global_position.y)
			quit()
			return true
	return false
