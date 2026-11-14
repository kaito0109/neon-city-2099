extends SceneTree
## Scene composition census: where do the draw calls come from?
var frames: int = 0
var main: Node

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _count(node: Node, acc: Dictionary) -> void:
	var t: String = node.get_class()
	if node is MeshInstance3D:
		t = "MeshInstance3D"
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			acc["surfaces"] = int(acc.get("surfaces", 0)) + mi.mesh.get_surface_count()
	elif node is MultiMeshInstance3D:
		t = "MultiMeshInstance3D"
	elif node is Label3D:
		t = "Label3D"
	elif node is Sprite3D:
		t = "Sprite3D"
	elif node is CSGShape3D:
		t = "CSGShape3D"
	acc[t] = int(acc.get(t, 0)) + 1
	for ch in node.get_children():
		_count(ch, acc)

func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 15:
		var acc: Dictionary = {}
		_count(main, acc)
		var keys: Array = acc.keys()
		keys.sort()
		for k in keys:
			print("STAT ", k, " = ", acc[k])
		quit(0)
	return false
