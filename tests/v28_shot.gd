extends SceneTree
## v3 close-ups: stand at the road crossing nearest each tower kit
## (crossings are guaranteed open ground) and aim at the tower.
var frames: int = 0
var _main: Node
var _player: Node
var _targets: Array = []  # {pos, h, name}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://shots")
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)

func _find_named(n: Node, target: String) -> Node3D:
	if n.name == target and n is Node3D:
		return n as Node3D
	for c in n.get_children():
		var r: Node3D = _find_named(c, target)
		if r != null:
			return r
	return null

func _save(name: String) -> void:
	var img: Image = root.get_texture().get_image()
	img.save_png("res://shots/" + name)
	print("saved ", name)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_main.call("start_game")
		_player = _main.get("player")
		var city: Node = _main.get("city")
		var heights: Dictionary = {"tower_ent": 22.0, "tower_kit": 17.0, "tower_mil": 32.0}
		for style in heights.keys():
			var hit: Node3D = _find_named(city, style)
			if hit != null:
				_targets.append({"pos": hit.global_position,
					"h": float(heights[style]), "name": style})
	if frames in [30, 70, 110] and not _targets.is_empty():
		var idx: int = (frames / 40) as int
		if idx < _targets.size():
			var t: Dictionary = _targets[idx]
			var kp: Vector3 = t["pos"]
			var cross := Vector3(round(kp.x / 60.0) * 60.0, 0.4, round(kp.z / 60.0) * 60.0)
			var to_kit := Vector3(kp.x - cross.x, 0, kp.z - cross.z)
			var dist: float = to_kit.length()
			var fwd: Vector3 = to_kit / maxf(dist, 0.001)
			_player.global_position = cross - fwd * 3.0
			_player.set("yaw", atan2(-fwd.x, -fwd.z))
			_player.set("pitch", atan2(float(t["h"]) * 0.42 - 1.6, dist))
			_player.set("input_enabled", false)
			_save("v28_" + String(t["name"]) + ".png")
	if frames == 130:
		quit(0)
		return true
	return false
