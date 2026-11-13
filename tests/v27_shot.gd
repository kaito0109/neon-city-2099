extends SceneTree
## v3 visual check (player-camera, the proven shot pattern):
## A avenue at dusk, B kitsch tower, C frontage, D rooftop overview.
var frames: int = 0
var _main: Node
var _player: Node
var _kit_pos: Vector3 = Vector3.INF
var _kit_dir: Vector3 = Vector3.FORWARD
var _front_pos: Vector3 = Vector3.INF
var _front_dir: Vector3 = Vector3.FORWARD
var _roof_pos: Vector3 = Vector3.INF

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://shots")
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)

func _yaw_for(fwd: Vector3) -> float:
	return atan2(-fwd.x, -fwd.z)

func _save(name: String) -> void:
	var img: Image = root.get_texture().get_image()
	img.save_png("res://shots/" + name)
	print("saved ", name)

func _aim(pos: Vector3, fwd: Vector3, pitch: float) -> void:
	_player.global_position = pos
	_player.set("yaw", _yaw_for(fwd))
	_player.set("pitch", pitch)
	_player.set("input_enabled", false)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		_main.call("start_game")
		_player = _main.get("player")
		var city: Node = _main.get("city")
		for ch in city.get_children():
			if ch.name.begins_with("tower_kit") and _kit_pos == Vector3.INF:
				_kit_pos = (ch as Node3D).global_position
				var bc := Vector2(floor((_kit_pos.x + 330.0) / 60.0) * 60.0 - 300.0,
					floor((_kit_pos.z + 330.0) / 60.0) * 60.0 - 300.0)
				var rel := Vector2(_kit_pos.x, _kit_pos.z) - bc
				if absf(rel.x) > absf(rel.y):
					_kit_dir = Vector3(signf(rel.x), 0, 0)
				else:
					_kit_dir = Vector3(0, 0, signf(rel.y))
		var kits: Node = city.get_node_or_null("FacadeKits")
		if kits != null:
			for ch in kits.get_children():
				if ch.name == "Frontage":
					_front_pos = (ch as Node3D).global_position
					var r: float = (ch as Node3D).rotation.y
					_front_dir = Vector3(sin(r), 0, cos(r))
					break
		var best_h: float = 0.0
		for b in city.get("_buildings"):
			if float(b["height"]) > best_h:
				best_h = float(b["height"])
				_roof_pos = (b["center"] as Vector3) + Vector3(3.0, best_h + 0.75, 3.0)
	if frames == 30:
		_aim(Vector3(10.5, 0.4, 168), Vector3(-0.55, 0, -0.83).normalized(), 0.06)
		_save("v27_a_avenue.png")
	if frames == 60:
		if _kit_pos != Vector3.INF:
			_aim(_kit_pos + _kit_dir * 17.5 + Vector3(0, 0.1, 0), -_kit_dir, 0.30)
			_save("v27_b_kitsch.png")
	if frames == 90:
		if _front_pos != Vector3.INF:
			var perp := Vector3(_front_dir.z, 0, -_front_dir.x)
			_aim(_front_pos + _front_dir * 11.0 + perp * 3.5 + Vector3(0, 0.1, 0), -_front_dir, 0.03)
			_save("v27_c_frontage.png")
	if frames == 120:
		if _roof_pos != Vector3.INF:
			var fwd := Vector3(-_roof_pos.x, 0, -_roof_pos.z).normalized()
			_aim(_roof_pos, fwd, -0.20)
			_save("v27_d_overview.png")
		quit(0)
		return true
	return false
