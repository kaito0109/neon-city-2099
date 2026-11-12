extends SceneTree
## v1.2 extra shots: traffic light close-up + hero tower C skyline view.
var frames: int = 0
var main: Node
var player: CharacterBody3D

func _initialize() -> void:
	root.size = Vector2i(1152, 648)
	var ps: PackedScene = load("res://main.tscn")
	main = ps.instantiate()
	root.add_child(main)

func _snap(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

func _find_named(node: Node, nm: String) -> Node3D:
	if node.name.begins_with(nm) and node is Node3D:
		return node as Node3D
	for c in node.get_children():
		var r: Node3D = _find_named(c, nm)
		if r != null:
			return r
	return null

func _look(target: Vector3, pitch: float) -> void:
	var to: Vector3 = target - player.global_position
	player.set("yaw", atan2(-to.x, -to.z))
	player.set("pitch", pitch)
	player.call("_apply_camera")

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 20:
		player = main.get("player")
		main.call("start_game")
		var city: Node = main.get("city")
		var tl: Node3D = _find_named(city, "TrafficLight")
		if tl != null:
			var bz: Vector3 = tl.global_transform.basis.z
			bz.y = 0.0
			bz = bz.normalized()
			# Intersection centre is ~13m from the pole along the arm (bz).
			# View from the road on the lamp-facing axis, like a driver.
			var centre: Vector3 = tl.global_position + bz * 13.0
			var f: Vector3 = -bz
			var axis := Vector3(signf(f.x), 0, 0) if absf(f.x) >= absf(f.z) else Vector3(0, 0, signf(f.z))
			player.global_position = centre + axis * 19.0 + Vector3(0, 0.3, 0)
			_look(tl.global_position + bz * 2.7 + Vector3(0, 3.7, 0), 0.20)
	if frames == 40:
		_snap("res://shots/v12_f_traffic.png")
		# Hero tower C (halo cylinder) sits at angle 4.15 rad, r=465.
		player.set("input_enabled", false)
		player.global_position = Vector3(-40, 14, -318)
		_look(Vector3(-257, 60, -388), 0.05)
	if frames == 60:
		_snap("res://shots/v12_g_hero.png")
		return true
	return false
