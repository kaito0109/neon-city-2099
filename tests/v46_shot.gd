extends SceneTree
## v4.2 UI check: title panel, then in-game HUD with the touch
## controls forced on, then the big map.
var frames: int = 0
var main: Node
var stage: int = 0

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _snap(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 40 and stage == 0:
		stage = 1
		_snap("res://shots/v46_title.png")
		main.call("start_game")
	elif frames == 90 and stage == 1:
		stage = 2
		var hud: Node = main.get("hud")
		hud.set("touch_mode", true)
	elif frames == 130 and stage == 2:
		stage = 3
		_snap("res://shots/v46_hud.png")
		main.get("hud").call("_toggle_big_map")
	elif frames == 170 and stage == 3:
		_snap("res://shots/v46_bigmap.png")
		print("SHOTS DONE")
		quit()
		return true
	return false
