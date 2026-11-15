extends SceneTree
## Repro v2: run forward -> jump -> double jump (flip) -> land -> keep
## running -> stop. Close camera; dump foot/shin bone poses + AP state
## at several points after the landing.
var frames: int = 0
var main: Node
var player: Node3D
var cam: Camera3D
var stage: int = 0
var stage_t: int = 0
var skel: Skeleton3D
var ap: AnimationPlayer
var landed_at: int = -1

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

func _dump(tag: String) -> void:
	if skel == null:
		var mdl: Node = player.get("_model")
		skel = mdl.find_child("Skeleton3D", true, false)
		ap = player.get("_anim")
	var msg: String = tag + " clip=" + str(ap.current_animation) + " pos=" + str(snappedf(ap.current_animation_position, 0.02)) + " spd=" + str(ap.speed_scale) + " playing=" + str(ap.is_playing())
	for b in ["Foot.L", "Foot.R", "LowerLeg.L", "LowerLeg.R"]:
		var i: int = skel.find_bone(b)
		var q: Quaternion = skel.get_bone_pose_rotation(i)
		var r: Quaternion = skel.get_bone_rest(i).basis.get_rotation_quaternion()
		msg += " | " + b + " ang=" + str(snappedf(r.angle_to(q), 0.01))
	print(msg)

func _frame_cam() -> void:
	cam.make_current()
	var p: Vector3 = player.global_position
	cam.global_position = p + Vector3(1.7, 1.1, 2.3)
	cam.look_at(p + Vector3(0, 0.8, 0), Vector3.UP)

func _process(_delta: float) -> bool:
	frames += 1
	stage_t += 1
	if frames == 20 and stage == 0:
		main.call("start_game")
		player = main.get("player")
		player.global_position = Vector3(0, 0.7, 60)
		player.set("_model_yaw", PI)  # face -Z (into the city)
		stage = 1
		stage_t = 0
	elif stage >= 1:
		_frame_cam()
		# Hold "forward" (away from camera, -Z) via the player's input vector.
		if stage <= 5:
			player.set("touch_move", Vector2(0, 1))
		else:
			player.set("touch_move", Vector2.ZERO)
		match stage:
			1:
				if stage_t == 25:
					player.set("_jump_queued", true)
					stage = 2
					stage_t = 0
			2:
				if stage_t == 20:
					player.set("_jump_queued", true)  # double jump -> flip
					stage = 3
					stage_t = 0
			3:
				if player.is_on_floor() and stage_t > 25:
					landed_at = frames
					_dump("LAND+0")
					_snap("v50b_land0.png")
					stage = 4
					stage_t = 0
			4:
				if stage_t == 8:
					_dump("LAND+8")
					_snap("v50b_land8.png")
				if stage_t == 22:
					_dump("LAND+22")
					_snap("v50b_land22.png")
					stage = 5
					stage_t = 0
			5:
				if stage_t == 30:
					_dump("STOP+0")
					_snap("v50b_stop.png")
					stage = 6
					stage_t = 0
			6:
				if stage_t == 40:
					_dump("STOP+40")
					_snap("v50b_stop40.png")
					print("REPRO2 DONE")
					quit()
					return true
	return false
