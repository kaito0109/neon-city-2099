extends SceneTree
var frames: int = 0
var main: Node
var player: Node3D
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

func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("res://shots/" + name)
	print("saved ", name)

func _process(_delta: float) -> bool:
	frames += 1
	stage_t += 1
	if frames == 20 and stage == 0:
		main.call("start_game")
		player = main.get("player")
		cam.make_current()
		stage = 1
		stage_t = 0
	elif stage == 1 and stage_t > 30:
		# street front of the pharmacy (plaza east)
		cam.global_position = Vector3(24, 2.2, 2)
		cam.look_at(Vector3(36, 2.2, 2), Vector3.UP)
		stage = 2
		stage_t = 0
	elif stage == 2 and stage_t > 8:
		_shot("v54_shopfront.png")
		# enter the pharmacy via the real flow
		var sites: Array = main.get("city").get("shop_sites")
		player.global_position = sites[0]["door_pos"]
		main.call("interact")
		stage = 3
		stage_t = 0
	elif stage == 3 and stage_t > 8:
		# camera inside, behind the entry looking to the counter
		cam.global_position = Vector3(31.5, -37.9, 6.5)
		cam.look_at(Vector3(36.5, -39.3, -3.5), Vector3.UP)
		stage = 4
		stage_t = 0
	elif stage == 4 and stage_t > 8:
		_shot("v54_pharmacy.png")
		main.call("interact")  # may exit if near exit; teleport out manually instead
		main.set("in_shop", -1)
		player.global_position = Vector3(-52, 1.5, 150)
		cam.global_position = Vector3(-38, 4.5, 152)
		cam.look_at(Vector3(-60, 2.5, 179), Vector3.UP)
		stage = 5
		stage_t = 0
	elif stage == 5 and stage_t > 8:
		_shot("v54_bridge.png")
		print("SHOTS DONE")
		quit()
		return true
	return false
