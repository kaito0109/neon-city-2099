extends SceneTree
var frames: int = 0
var main: Node
var player: Node3D
var stage: int = 0
var stage_t: int = 0

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	frames += 1
	stage_t += 1
	if frames == 20 and stage == 0:
		main.call("start_game")
		player = main.get("player")
		stage = 1
		stage_t = 0
	elif stage == 1 and stage_t > 30:
		player.global_position = Vector3(-60, 3.8, 184)
		player.set("yaw", PI)
		player.set("_yaw_t", PI)
		player.set("touch_move", Vector2(0, -1))
		stage = 2
		stage_t = 0
	elif stage == 2:
		if stage_t % 90 == 0:
			var cols: String = ""
			for ci in range(player.get_slide_collision_count()):
				var c: KinematicCollision3D = player.get_slide_collision(ci)
				cols += " [n=%s col=%s]" % [c.get_normal(), c.get_collider()]
			print("t=%d pos=%s floor=%s%s" % [stage_t, player.global_position, player.is_on_floor(), cols])
		if player.global_position.z > 200.0 or stage_t > 900:
			player.set("touch_move", Vector2.ZERO)
			print("PROBE DONE z=%.1f" % player.global_position.z)
			quit()
			return true
	return false
