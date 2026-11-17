extends SceneTree
## v5.7 photo PDCA: the spots from his device photos — switchback
## plates, plaza paint, climb edge lines, under-deck lines, ring.
var frames: int = 0
var main: Node
var cam: Camera3D
var spots: Array = [
	[Vector3(88, 26, -58), Vector3(150, 8, -140), "switch"],
	[Vector3(0, 3.2, 26), Vector3(0, 1.2, -60), "plaza"],
	[Vector3(96, 7.5, -70), Vector3(140, 10, -120), "climb"],
	[Vector3(-60, 3.0, -30), Vector3(-95, 2.0, -75), "deck_under"],
	[Vector3(105, 9, 88), Vector3(105, 0, -40), "ring_e"],
	[Vector3(-30, 2.2, 44), Vector3(-89, 4, 83), "arch"],
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
			var p := "res://shots/v57_" + String(spots[i][2]) + ".png"
			root.get_texture().get_image().save_png(p)
			print("saved ", p)
			i += 1
	if i >= spots.size():
		print("SHOTS DONE")
		quit()
		return true
	return false
