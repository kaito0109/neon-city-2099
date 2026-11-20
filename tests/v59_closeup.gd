extends SceneTree
## v5.9 visual PDCA: fixed camera spots for before/after compare —
## spawn/plaza, street-level facades, terrace, high overview and an
## outward skyline check. Tag comes from OS args after "--"
## (e.g. -- v59a) so rounds don't overwrite each other.
var frames: int = 0
var main: Node
var cam: Camera3D
var tag: String = "v59a"
var spots: Array = [
	[Vector3(-45, 5, 27), Vector3(-45, 11, 9), "facade_w"],
	[Vector3(141, 6, 59), Vector3(141, 12, 40), "facade_e2"],
]
var i: int = 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		tag = String(args[0])
	DisplayServer.window_set_size(Vector2i(1152, 648))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	cam = Camera3D.new()
	cam.far = 1600.0
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
			var p := "res://shots/" + tag + "_" + String(spots[i][2]) + ".png"
			root.get_texture().get_image().save_png(p)
			print("saved ", p, " drawcalls=",
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			i += 1
	if i >= spots.size():
		print("SHOTS DONE ", tag)
		quit()
		return true
	return false
