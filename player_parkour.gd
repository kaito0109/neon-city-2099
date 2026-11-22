extends RefCounted
## In-place clips for the Cyber rig. Physics still owns vertical movement.

static func install(actor: Node3D, player: AnimationPlayer) -> bool:
	if player == null or not player.has_animation("Idle"):
		return false
	var rigs := actor.find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty():
		return false
	var rig := rigs[0] as Skeleton3D
	var names := ["l arm_028", "r arm_09", "l forearm_029", "r forearm_010",
		"l leg_047", "r leg_051", "l knee_048", "r knee_052"]
	for name in names:
		if rig.find_bone(name) < 0:
			return false
	var library := AnimationLibrary.new()
	# Angles around the rig's lateral axis. Positive rotates a hanging
	# limb back; negative brings it forward. Paired legs alternate in climb.
	_add(library, player, rig, names, "Takeoff", 0.22, [
		[15, 15, -12, -12, -24, -9, 25, 34],
		[-54, -42, -30, -26, -48, 20, 52, 32]], false)
	_add(library, player, rig, names, "Fall", 0.25, [
		[-28, -25, -20, -18, -21, -6, 27, 19],
		[-40, -36, -22, -22, -25, -14, 36, 31]], false)
	_add(library, player, rig, names, "AirBoost", 0.42, [
		[-45, -45, -35, -35, -55, -55, 64, 64],
		[-25, -25, -18, -18, -17, -17, 23, 23]], false)
	_add(library, player, rig, names, "Land", 0.19, [
		[-23, -23, -25, -25, -29, -29, 54, 54],
		[0, 0, 0, 0, 0, 0, 2, 2]], false)
	_add(library, player, rig, names, "WallClimb", 0.62, [
		[-117, -73, -16, -42, -12, -57, 29, 72],
		[-73, -117, -42, -16, -57, -12, 72, 29],
		[-117, -73, -16, -42, -12, -57, 29, 72]], true)
	_add(library, player, rig, names, "Mantle", 0.33, [
		[-110, -107, -22, -22, -46, -23, 62, 45],
		[-75, -76, -34, -34, -66, -49, 76, 58],
		[-34, -31, -20, -20, -22, -12, 29, 18]], false)
	player.add_animation_library("parkour", library)
	return true

static func _add(library: AnimationLibrary, player: AnimationPlayer, rig: Skeleton3D,
		names: Array, clip_name: String, duration: float, poses: Array, loop: bool) -> void:
	var clip := Animation.new()
	clip.length = duration
	clip.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var animation_root := player.get_node(player.root_node)
	for i in range(names.size()):
		var bone := rig.find_bone(names[i])
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, NodePath("%s:%s" % [animation_root.get_path_to(rig), names[i]]))
		var rest := rig.get_bone_rest(bone).basis.orthonormalized().get_rotation_quaternion()
		var axis := (rig.get_bone_global_rest(bone).basis.inverse() * Vector3.RIGHT).normalized()
		for frame in range(poses.size()):
			var time := duration * float(frame) / float(poses.size() - 1)
			clip.rotation_track_insert_key(track, time,
				rest * Quaternion(axis, deg_to_rad(float(poses[frame][i]))))
	library.add_animation(clip_name, clip)
