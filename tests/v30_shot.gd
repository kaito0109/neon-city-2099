extends SceneTree
var frames: int = 0
var _main: Node
var _player: Node
func _initialize() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)
func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_main.call("start_game")
		_player = _main.get("player")
	if frames == 30:
		_player.global_position = Vector3(10.5, 0.4, 168)
		_player.set("yaw", 0.585)
		_player.set("pitch", 0.06)
		_player.set("input_enabled", false)
		var img: Image = root.get_texture().get_image()
		img.save_png("res://shots/v30_avenue.png")
		print("saved v30")
		quit(0)
		return true
	return false
