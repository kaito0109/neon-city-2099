extends SceneTree
func _initialize():
	run.call_deferred()

func run():
	var player = load("res://player.gd").new()
	root.add_child(player)
	player.set_physics_process(false)
	assert(player._parkour_clips)
	for stage in [[7.0, false, 0.0, false, "Takeoff"], [-3.0, false, 0.0, false, "Fall"], [6.8, false, 0.4, false, "AirBoost"], [0.0, true, 0.0, false, "Land"], [0.0, false, 0.0, true, "WallClimb"], [8.6, false, 0.0, false, "Mantle"]]:
		player.velocity.y = stage[0]
		player._flip_t = stage[2]
		player._mantle_time = 0.2 if stage[4] == "Mantle" else 0.0
		player._climbing = stage[3]
		player._landing_time = 0.1 if stage[1] else 0.0
		player._update_anim(0.016, Vector3.ZERO, stage[1])
		assert(player._anim.assigned_animation == "parkour/" + stage[4])
		player._anim.advance(0.12)
	print("PARKOUR PASS")
	quit()
