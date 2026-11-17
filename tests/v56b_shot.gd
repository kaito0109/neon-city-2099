extends SceneTree
## v5.6 zebra verification: viewpoints with a crossing dead-center.
var frames: int = 0
var main: Node
var cam: Camera3D
var spots: Array = [
	[Vector3(0, 4.5, 59), Vector3(0, 0.2, 42), "zebra_c"],
	[Vector3(-100, 3.5, 152), Vector3(-100, 0.2, 136), "zebra_mkt"],
]
var i: int = 0

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	cam = Camera3D.new()
	cam.far = 900.0
	root.add_child(cam)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 20:
		main.call("start_game")
		cam.make_current()
	if frames > 40 and i < spots.size():
		if frames % 14 == 0:
			cam.global_position = spots[i][0]
			cam.look_at(spots[i][1], Vector3.UP)
		if frames % 14 == 7:
			var p := "res://shots/v56b_" + String(spots[i][2]) + ".png"
			root.get_texture().get_image().save_png(p)
			print("saved ", p)
			i += 1
	if i >= spots.size():
		print("SHOTS DONE")
		quit()
		return true
	return false
