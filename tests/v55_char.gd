extends SceneTree
# Character check: instance the retargeted protagonist, report the
# skeleton's rest height range, play each clip and screenshot it.
var _frames := 0
var _stage := 0
var _model: Node3D
var _ap: AnimationPlayer
var _cam: Camera3D
var _clips := ["Idle", "Walk", "Run", "Roll"]
var _shot_at := [30, 80, 130, 180]

func _initialize() -> void:
	# Spawn through People, exactly as player.gd does: the CAST entry
	# loads the split ModelBlob parts (the live web route).
	_model = People.spawn("Cyber")
	if _model == null:
		print("CHAR_FAIL load null")
		quit(1)
		return
	root.add_child(_model)
	var skel := _find_skel(_model)
	if skel:
		var lo := 1e9
		var hi := -1e9
		for i in skel.get_bone_count():
			var y := skel.get_bone_global_rest(i).origin.y
			lo = min(lo, y); hi = max(hi, y)
		print("CHAR bones=", skel.get_bone_count(), " restY lo=", snappedf(lo, 0.001), " hi=", snappedf(hi, 0.001))
	_ap = _find_ap(_model)
	if _ap:
		print("CHAR clips=", _ap.get_animation_list())
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.12, 0.14, 0.16)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.75, 0.8)
	e.ambient_light_energy = 0.9
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	sun.light_energy = 1.2
	root.add_child(sun)
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 1.2, 3.4)
	root.add_child(_cam)
	_cam.look_at(Vector3(0, 0.9, 0), Vector3.UP)
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	floor_mesh.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.2, 0.22, 0.24)
	floor_mesh.material_override = fm
	root.add_child(floor_mesh)

func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skel(c)
		if r:
			return r
	return null

func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_ap(c)
		if r:
			return r
	return null

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var img0 := root.get_texture().get_image()
		img0.save_png("res://shots/v55_char_rest.png")
		print("CHAR shot rest")
		var skel0 := _find_skel(_model)
		if skel0:
			for bn in ["l leg_047", "r leg_051"]:
				var bi0 := skel0.find_bone(bn)
				if bi0 >= 0:
					print("CHAR rest ", bn, " pos=", skel0.get_bone_global_rest(bi0).origin)
	if _ap and _stage < _clips.size():
		var clip: String = _clips[_stage]
		if _frames == _shot_at[_stage] - 25:
			if _ap.has_animation(clip):
				_ap.play(clip)
				_ap.seek(0.35, true)
		if _frames == _shot_at[_stage]:
			var img := root.get_texture().get_image()
			img.save_png("res://shots/v55_char_" + clip.to_lower() + ".png")
			print("CHAR shot ", clip)
			_stage += 1
	if _frames == 60:
		var skel := _find_skel(_model)
		if skel:
			var gt: Transform3D = skel.global_transform
			print("CHAR skel global scale=", gt.basis.get_scale())
			for bn in ["hips_00", "head_05", "l foot_049", "l_foot_049", "l toes_050"]:
				var bi := skel.find_bone(bn)
				if bi >= 0:
					var wp: Vector3 = gt * skel.get_bone_global_pose(bi).origin
					print("CHAR pose ", bn, " world=", wp)
			var lo := Vector3(1e9, 1e9, 1e9)
			var hi := Vector3(-1e9, -1e9, -1e9)
			for i in skel.get_bone_count():
				var wp2: Vector3 = gt * skel.get_bone_global_pose(i).origin
				lo = lo.min(wp2); hi = hi.max(wp2)
			print("CHAR pose range lo=", lo, " hi=", hi)
	if _frames > 200:
		print("CHAR_DONE")
		quit(0)
	return false
