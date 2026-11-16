extends SceneTree
var frames: int = 0
var main: Node
var cam: Camera3D
var stage: int = 0
var stage_t: int = 0

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	cam = Camera3D.new()
	cam.far = 400.0
	root.add_child(cam)

func _process(_delta: float) -> bool:
	frames += 1
	stage_t += 1
	if frames == 20 and stage == 0:
		main.call("start_game")
		cam.make_current()
		stage = 1
		stage_t = 0
	elif stage == 1 and stage_t > 30:
		cam.global_position = Vector3(-60, 26, 179.01)
		cam.look_at(Vector3(-60, 3.0, 179), Vector3(0, 0, -1))
		stage = 2
		stage_t = 0
	elif stage == 2 and stage_t > 8:
		root.get_texture().get_image().save_png("res://shots/v54_topdown.png")
		print("saved")
		quit()
		return true
	return false
