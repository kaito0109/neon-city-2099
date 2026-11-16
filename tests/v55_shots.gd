extends SceneTree
## v5.5 AAA-pass comparison shots: fixed viewpoints, reused for
## before/after PDCA. Suffix comes from OS arg after "--" (default "a").
var frames: int = 0
var main: Node
var cam: Camera3D
var suffix: String = "a"
var spots: Array = [
	[Vector3(2, 2.2, 54), Vector3(-2, 8, -60), "street"],
	[Vector3(0, 3.0, 10), Vector3(-6, 26, -120), "plaza_up"],
	[Vector3(-14, 3.2, 128), Vector3(30, 6, 176), "market"],
	[Vector3(120, 20.0, -84), Vector3(170, 8.0, -130), "terrace"],
	[Vector3(150, 90, 190), Vector3(-20, 0, -40), "aerial"],
]
var i: int = 0

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		suffix = args[0]
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
			var p := "res://shots/v55_" + suffix + "_" + String(spots[i][2]) + ".png"
			root.get_texture().get_image().save_png(p)
			print("saved ", p)
			i += 1
	if i >= spots.size():
		print("SHOTS DONE")
		quit()
		return true
	return false
