extends SceneTree
## v5.8 photo check: the player standing ON bench risers — feet
## must sit on the visible slope, not sink into it (his photo:
## NPCs waist-deep in a bank). Same collision serves NPCs.
var frames: int = 0
var main: Node
var cam: Camera3D
var spots: Array = [
	[Vector2(130.0, -73.3), "riser6"],
	[Vector2(164.0, -149.5), "riser18"],
]
var i: int = 0
var stage: int = 0

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	cam = Camera3D.new()
	cam.far = 900.0
	root.add_child(cam)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 20:
		main.call("start_game")
		cam.make_current()
	if frames > 30 and i < spots.size():
		var player: Node3D = main.get("player")
		var city: Node = main.get("city")
		var sp: Vector2 = spots[i][0]
		if stage == 0:
			var h: float = float(city.call("_terrain_height", sp.x, sp.y))
			player.global_position = Vector3(sp.x, h + 1.2, sp.y)
			stage = 1
		elif stage == 1 and frames % 50 == 0:
			var pp: Vector3 = player.global_position
			cam.global_position = pp + Vector3(3.4, 1.7, 3.4)
			cam.look_at(pp + Vector3(0, 0.7, 0), Vector3.UP)
			stage = 2
		elif stage == 2 and frames % 50 == 25:
			var p := "res://shots/v58_" + String(spots[i][1]) + ".png"
			root.get_texture().get_image().save_png(p)
			print("saved ", p, " player_y=", snappedf(player.global_position.y, 0.01))
			i += 1
			stage = 0
	if i >= spots.size():
		print("SHOTS DONE")
		quit()
		return true
	return false
