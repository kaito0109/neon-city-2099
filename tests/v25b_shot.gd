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
	print("saved ", path)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_main.call("start_game")
		_player = _main.get("player")
	if frames == 10:
		# Stand close in front of the first bench we can find.
		var city: Node = _main.get("city")
		var sp: Node = city.get_node_or_null("StreetProps")
		var done: bool = false
		for ch in sp.get_children():
			var n3: Node3D = ch as Node3D
			if n3 != null and n3.scale.x > 2.0:
				# Stand off toward the road (away from the block
				# centre) and look back at the bench.
				var bp: Vector3 = n3.global_position
				var bc: Vector3 = Vector3.ZERO
				var best: float = 1e9
				for b in city.get("sidewalk_blocks"):
					var cc: Vector3 = b["center"]
					var d: float = Vector2(cc.x - bp.x, cc.z - bp.z).length()
					if d < best:
						best = d
						bc = cc
				var dir: Vector3 = Vector3(bp.x - bc.x, 0, bp.z - bc.z).normalized()
				_player.global_position = bp + dir * 3.4 + Vector3(0, 0.15, 0)
				_player.set("yaw", atan2(-dir.x, -dir.z))
				_player.set("pitch", -0.1)
				_player.set("input_enabled", false)
				done = true
				break
		if not done:
			quit(1)
			return true
	if frames == 45:
		_snap("res://shots/v25_c_bench.png")
		quit(0)
		return true
	return false
