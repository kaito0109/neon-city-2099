extends SceneTree
## Frame sequence of a high fall -> roll landing, close camera.
var frames: int = 0
var main: Node
var player: Node3D
var cam: Camera3D
var stage: int = 0
var shot_n: int = 0
var since_land: int = -1

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	cam = Camera3D.new()
	cam.far = 300.0
	root.add_child(cam)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 20 and stage == 0:
		main.call("start_game")
		player = main.get("player")
		player.global_position = Vector3(0, 26.0, 48)
		player.set("velocity", Vector3.ZERO)
		stage = 1
		return false
	if stage != 1 or player == null:
		return false
	cam.make_current()
	var p: Vector3 = player.global_position
	cam.global_position = p + Vector3(1.6, 1.0, 2.2)
	cam.look_at(p + Vector3(0, 0.8, 0), Vector3.UP)
	if player.is_on_floor() and since_land < 0:
		since_land = 0
	if since_land >= 0:
		since_land += 1
		if since_land % 3 == 0 and shot_n < 14:
			root.get_texture().get_image().save_png("res://shots/v50r_%02d.png" % shot_n)
			print("shot ", shot_n, " since_land=", since_land, " roll_t=", player.get("_roll_t"), " clip=", player.get("_cur_clip"))
			shot_n += 1
		if since_land > 60:
			print("SEQ DONE")
			quit()
			return true
	return false
