extends SceneTree
var frames: int = 0
var main: Node

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _scan(n: Node, target: Vector3) -> void:
	if n is Node3D:
		var p: Vector3 = (n as Node3D).global_position
		if Vector2(p.x - target.x, p.z - target.z).length() < 7.0 and absf(p.y - target.y) < 6.0:
			print("near: ", n.get_path(), " pos=", p, " type=", n.get_class())
	for c in n.get_children():
		_scan(c, target)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 30:
		main.call("start_game")
	if frames == 50:
		_scan(main, Vector3(0, 0, 170))
		print("SCAN DONE")
		quit()
		return true
	return false
