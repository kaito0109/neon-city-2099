extends SceneTree
var frames: int = 0
var main: Node
var player: Node
var stage: int = 0

func _initialize() -> void:
	var ps: PackedScene = load("res://main.tscn")
	main = ps.instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 8:
		main.call("start_game")
		player = main.get("player")
		player.set("input_enabled", false)
	elif frames == 40 and stage == 0:
		root.get_texture().get_image().save_png("res://shots/v13_a_street.png")
		print("saved v13_a_street")
		stage = 1
	elif stage == 1:
		# Punk close-up: swing the player camera around to the front.
		player.set("yaw", PI)
		player.call("_apply_camera")
		stage = 2
	elif frames == 55 and stage == 2:
		root.get_texture().get_image().save_png("res://shots/v13_b_punk.png")
		print("saved v13_b_punk")
		# Downtown: teleport near the centre for a crowd shot.
		player.set("yaw", 0.0)
		player.call("_apply_camera")
		(player as Node3D).global_position = Vector3(2, 0.6, 58)
		stage = 3
	elif frames == 170 and stage == 3:
		root.get_texture().get_image().save_png("res://shots/v13_c_downtown.png")
		print("saved v13_c_downtown")
		quit(0)
		return true
	return false
