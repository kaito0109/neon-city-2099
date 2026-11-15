extends SceneTree
## Dump the player's clip track coverage: which bones does each clip animate?
func _initialize() -> void:
	var inst: Node3D = ModelLoader.load_model("res://assets/people_q/opt/Punk.glb", "res://assets/people_data/Punk.tres")
	if inst == null:
		print("LOAD FAIL")
		quit()
		return
	root.add_child(inst)
	var ap: AnimationPlayer = null
	for n in inst.find_children("*", "AnimationPlayer", true, false):
		ap = n
	if ap == null:
		print("NO AP")
		quit()
		return
	for c in ap.get_animation_list():
		var a: Animation = ap.get_animation(c)
		var legs: Array = []
		for t in range(a.get_track_count()):
			var p: String = str(a.track_get_path(t))
			if p.contains("Leg") or p.contains("Foot") or p.contains("Toe"):
				legs.append(p)
		print(c, " len=", snappedf(a.length, 0.01), " loop=", a.loop_mode, " tracks=", a.get_track_count(), " leg_tracks=", legs.size())
		for l in legs:
			print("   ", l)
	quit()
