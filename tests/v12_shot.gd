extends SceneTree
## v1.2 screenshots: street, car close-up, vending close-up, skyline heroes, driving.
var frames: int = 0
var main: Node
var player: CharacterBody3D
var car: Node3D

func _initialize() -> void:
	root.size = Vector2i(1152, 648)
	var ps: PackedScene = load("res://main.tscn")
	main = ps.instantiate()
	root.add_child(main)

func _snap(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

func _face(target: Vector3) -> void:
	var to: Vector3 = target - player.global_position
	player.set("yaw", atan2(-to.x, -to.z))
	player.set("pitch", -0.06)
	player.call("_apply_camera")

func _find_named(node: Node, nm: String) -> Node3D:
	if node.name == nm and node is Node3D:
		return node as Node3D
	for c in node.get_children():
		var r: Node3D = _find_named(c, nm)
		if r != null:
			return r
	return null

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 20:
		player = main.get("player")
		main.call("start_game")
		player.set("yaw", 0.0)
		player.set("pitch", -0.08)
	if frames == 40:
		_snap("res://shots/v12_a_street.png")
		# Car close-up: first parked car, view its rear three-quarter.
		car = main.get("_cars")[0]
		var cp: Vector3 = car.global_position
		player.global_position = cp + Vector3(3.4, 0.4, 5.4)
		_face(cp + Vector3(0, 0.8, 0))
	if frames == 60:
		_snap("res://shots/v12_b_car.png")
		# Vending machine close-up.
		var city: Node = main.get("city")
		var vend: Node3D = _find_named(city, "Vending")
		if vend != null:
			var dir: Vector3 = vend.global_transform.basis.z
			dir.y = 0.0
			dir = dir.normalized()
			player.global_position = vend.global_position + dir * 3.2 + Vector3(0, 0.3, 0)
			_face(vend.global_position + Vector3(0, 1.1, 0))
	if frames == 80:
		_snap("res://shots/v12_c_vending.png")
		# Skyline with hero towers: float at the SE corner looking to centre.
		player.set("input_enabled", false)
		player.global_position = Vector3(268, 30, 268)
		var to: Vector3 = Vector3(0, 55, 0) - player.global_position
		player.set("yaw", atan2(-to.x, -to.z))
		player.set("pitch", 0.10)
		player.call("_apply_camera")
	if frames == 100:
		_snap("res://shots/v12_d_skyline.png")
		player.set("input_enabled", true)
		car.call("set_driven", true)
		main.set("touch_drive", Vector2(0, 1))
	if frames == 150:
		_snap("res://shots/v12_e_drive.png")
		return true
	return false
