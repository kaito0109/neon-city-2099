extends SceneTree
## v5.6 PDCA round 2: verify the zebra from above, re-shoot the
## benches and the climb from unobstructed viewpoints.
var frames: int = 0
var main: Node
var cam: Camera3D
var spots: Array = [
	[Vector3(0, 16, 57), Vector3(0, 0, 43), "zebra_top"],
	[Vector3(110, 6.5, -28), Vector3(185, 12, -165), "benches2"],
	[Vector3(118, 8.5, -92), Vector3(185, 15, -175), "riser"],
	[Vector3(70, 5.5, -62), Vector3(130, 11, -110), "climb2"],
	[Vector3(-30, 3.0, 128), Vector3(-100, 1.0, 138), "market_x"],
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
			var p := "res://shots/v56_" + String(spots[i][2]) + ".png"
			root.get_texture().get_image().save_png(p)
			print("saved ", p)
			i += 1
	if i >= spots.size():
		print("SHOTS DONE")
		quit()
		return true
	return false
