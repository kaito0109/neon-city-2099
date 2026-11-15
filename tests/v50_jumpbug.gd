extends SceneTree
## Repro for his 2026-11-15 report: legs collapse after jumping.
## Three scenarios, each screenshotted after settling:
##  1) plain jump  2) double jump (flip)  3) high fall -> roll
var frames: int = 0
var main: Node
var player: Node3D
var cam: Camera3D
var stage: int = 0
var stage_t: int = 0
var was_floor: bool = true

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	cam = Camera3D.new()
	cam.far = 300.0
	root.add_child(cam)

func _snap(name: String) -> void:
	root.get_texture().get_image().save_png("res://shots/" + name)
	print("saved ", name)

func _frame_cam() -> void:
	cam.make_current()
	var p: Vector3 = player.global_position
	cam.global_position = p + Vector3(2.6, 1.5, 3.4)
	cam.look_at(p + Vector3(0, 0.9, 0), Vector3.UP)

func _process(_delta: float) -> bool:
	frames += 1
	stage_t += 1
	if frames == 20 and stage == 0:
		main.call("start_game")
		player = main.get("player")
		player.global_position = Vector3(0, 0.7, 48)
		stage = 1
		stage_t = 0
	elif stage == 1 and stage_t == 20:
		player.set("velocity", Vector3(0, 7.0, 0))
		stage = 2
		stage_t = 0
	elif stage == 2:
		_frame_cam()
		if player.is_on_floor() and stage_t > 30:
			stage = 3
			stage_t = 0
	elif stage == 3 and stage_t == 25:
		_snap("v50_1_plain_jump.png")
		player.set("velocity", Vector3(0, 7.0, 0))
		stage = 4
		stage_t = 0
	elif stage == 4 and stage_t == 22:
		# Mid-air: queue the double jump (flip).
		player.set("_jump_queued", true)
		stage = 5
		stage_t = 0
	elif stage == 5:
		_frame_cam()
		if player.is_on_floor() and stage_t > 30:
			stage = 6
			stage_t = 0
	elif stage == 6 and stage_t == 25:
		_snap("v50_2_double_jump.png")
		player.global_position = Vector3(0, 26.0, 48)
		player.set("velocity", Vector3.ZERO)
		stage = 7
		stage_t = 0
	elif stage == 7:
		_frame_cam()
		if player.is_on_floor() and stage_t > 30:
			stage = 8
			stage_t = 0
	elif stage == 8 and stage_t == 70:
		_snap("v50_3_high_fall.png")
		print("REPRO DONE")
		quit()
		return true
	return false
