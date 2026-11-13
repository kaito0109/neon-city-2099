extends SceneTree
var frames: int = 0
var _main: Node
var _player: Node

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://shots")
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_main.call("start_game")
		_player = _main.get("player")
	if frames == 12:
		# Find a photo-facade segment and stand across the street.
		var city: Node = _main.get("city")
		var mats: Array = city.get("_photo_mats")
		var found: bool = false
		for ch in city.get_children():
			var mi := ch as MeshInstance3D
			if mi != null and mats.has(mi.material_override):
				var bp: Vector3 = mi.global_position
				# Outward = away from the building centre horizontally
				# toward the avenue is unknowable; use the segment's
				# thinnest axis: stand off along +X of the block grid.
				_player.global_position = Vector3(bp.x + 26.0, 0.4, bp.z)
				_player.set("yaw", PI * 0.5)
				_player.set("pitch", -0.02)
				_player.set("input_enabled", false)
				found = true
				break
		if not found:
			quit(1)
			return true
	if frames == 45:
		var img: Image = root.get_texture().get_image()
		img.save_png("res://shots/v26_a_photo.png")
		print("saved v26")
		quit(0)
		return true
	return false
