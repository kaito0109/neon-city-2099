extends SceneTree
var frames: int = 0
var _main: Node
var _player: Node

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://shots")
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)

func _snap(path: String) -> void:
	var img: Image = root.get_texture().get_image()
	img.save_png(path)
	print("saved ", path, " ", img.get_size())

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_main.call("start_game")
		_player = _main.get("player")
	if frames == 10:
		# Street level on the avenue, looking north: asphalt close-up.
		_player.global_position = Vector3(4.5, 0.35, 26.0)
		_player.set("yaw", PI)
		_player.set("pitch", -0.06)
		_player.set("input_enabled", false)
	if frames == 45:
		_snap("res://shots/v25_a_road.png")
	if frames == 50:
		# Above the deck looking down its length.
		_player.global_position = Vector3(2.0, 14.0, 60.0)
		_player.set("yaw", PI)
		_player.set("pitch", -0.25)
	if frames == 80:
		_snap("res://shots/v25_b_deck.png")
		quit(0)
		return true
	return false
