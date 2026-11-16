extends SceneTree
## Soak test: scripted free play (run / jump / double jump / wall runs /
## stops) with a watchdog for the broken-legs state his iPhone shows:
## grounded + slow + no roll/flip/climb, yet a leg bone sits at a
## locomotion-extreme angle. On trigger, dump the transition history.
var frames: int = 0
var main: Node
var player: Node3D
var skel: Skeleton3D
var ap: AnimationPlayer
var phase: int = 0
var phase_t: int = 0
var bad_streak: int = 0
var last_clip: String = ""
var log_buf: Array = []
var done: bool = false

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _ang(bone: String) -> float:
	var i: int = skel.find_bone(bone)
	if i < 0:
		return 0.0
	var q: Quaternion = skel.get_bone_pose_rotation(i)
	var r: Quaternion = skel.get_bone_rest(i).basis.get_rotation_quaternion()
	return r.angle_to(q)

func _log_state() -> void:
	var s: String = "f=%d clip=%s roll=%.2f flip=%.2f climb=%s floor=%s vy=%.1f peak=%.1f hspd=%.1f" % [
		frames, player.get("_cur_clip"), player.get("_roll_t"), player.get("_flip_t"),
		str(player.get("_climbing")), str(player.is_on_floor()),
		player.velocity.y, player.get("_fall_peak"),
		Vector2(player.velocity.x, player.velocity.z).length()]
	if log_buf.is_empty() or log_buf[log_buf.size() - 1] != s:
		log_buf.append(s)
		if log_buf.size() > 200:
			log_buf.pop_front()

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 20:
		main.call("start_game")
		player = main.get("player")
		player.global_position = Vector3(0, 0.7, 48)
		var mdl: Node = player.get("_model")
		skel = mdl.find_child("Skeleton3D", true, false)
		ap = player.get("_anim")
		return false
	if player == null or done:
		return false
	phase_t += 1
	_log_state()
	# --- watchdog ---
	var hspd: float = Vector2(player.velocity.x, player.velocity.z).length()
	var worst: float = maxf(maxf(_ang("LowerLeg.L"), _ang("LowerLeg.R")), maxf(_ang("UpperLeg.L"), _ang("UpperLeg.R")))
	var grounded_bad: bool = player.is_on_floor() and not player.get("_climbing") \
		and player.get("_roll_t") <= 0.0 and player.get("_flip_t") <= 0.0 \
		and hspd < 0.6 and worst > 1.0
	if grounded_bad:
		bad_streak += 1
		if bad_streak == 25:
			print("ANOMALY at frame ", frames, " worst_leg_ang=", snappedf(worst, 0.01),
				" clip=", player.get("_cur_clip"), " ap=", ap.current_animation,
				" ap_pos=", snappedf(ap.current_animation_position, 0.02), " ap_playing=", ap.is_playing())
			for l in log_buf:
				print("  ", l)
			done = true
			quit()
			return true
	else:
		bad_streak = 0
	# --- drive phases (each ~7 s of render frames at Xvfb pace) ---
	var cyc: int = (frames / 420) % 6
	var in_cyc: int = frames % 420
	match cyc:
		0:  # run
			player.set("touch_move", Vector2(0, 1))
		1:  # run + jump every ~1.5 s
			player.set("touch_move", Vector2(0, 1))
			if in_cyc % 90 == 30:
				player.set("_jump_queued", true)
		2:  # run + double jump
			player.set("touch_move", Vector2(0, 1))
			if in_cyc % 140 == 30 or in_cyc % 140 == 55:
				player.set("_jump_queued", true)
		3:  # run the other way + jumps at walls
			player.set("touch_move", Vector2(0, -1))
			if in_cyc % 110 == 40:
				player.set("_jump_queued", true)
		4:  # walk slow
			player.set("touch_move", Vector2(0, 0.45))
		5:  # stand
			player.set("touch_move", Vector2.ZERO)
	if frames > 420 * 6 * 3:
		print("SOAK CLEAN (no anomaly in ", frames, " frames)")
		quit()
		return true
	return false
