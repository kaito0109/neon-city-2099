extends SceneTree
var frames: int = 0
var main: Node
var cam: Camera3D
var spots: Array = [
	[Vector3(120, 20.0, -84), Vector3(170, 8.0, -130), "v52_terrace.png"],
	[Vector3(150, 14.0, -96), Vector3(196, 16.0, -160), "v52_switch.png"],
]
var i: int = 0

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	cam = Camera3D.new()
	cam.far = 400.0
	root.add_child(cam)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 20:
		main.call("start_game")
		cam.make_current()
	if frames > 30 and i < spots.size():
		if frames % 12 == 0:
			cam.global_position = spots[i][0]
			cam.look_at(spots[i][1], Vector3.UP)
		if frames % 12 == 6:
			root.get_texture().get_image().save_png("res://shots/" + spots[i][2])
			print("saved ", spots[i][2])
			i += 1
	if i >= spots.size():
		print("SHOTS DONE")
		quit()
		return true
	return false
