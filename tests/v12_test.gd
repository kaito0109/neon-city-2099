extends SceneTree
## v1.2 regression: Blender models load & integrate (car model + tint,
## street props, hero towers), drive camera stays behind at PI, and
## entering/exiting the car still works through interact().
var frames: int = 0
var main: Node
var player: CharacterBody3D
var car: Node3D
var phase: int = 0
var settle: int = 0
var failed: bool = false

func _ok(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		failed = true

func _initialize() -> void:
	var ps: PackedScene = load("res://main.tscn")
	main = ps.instantiate()
	root.add_child(main)

func _find_model(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for c in node.get_children():
		var r: MeshInstance3D = _find_model(c)
		if r != null:
			return r
	return null

func _count_named(node: Node, nm: String) -> int:
	var n: int = 0
	if node.name == nm:
		n += 1
	for c in node.get_children():
		n += _count_named(c, nm)
	return n

func _count_props(city_node: Node, prefix: String) -> int:
	# Instances are direct children of BlenderProps; duplicate names get
	# numeric suffixes, so count by prefix at that level only.
	var root: Node = city_node.get_node_or_null("BlenderProps")
	if root == null:
		return -1
	var n: int = 0
	for c in root.get_children():
		if c.name.begins_with(prefix):
			n += 1
	return n

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 8:
		main.call("start_game")
		player = main.get("player")
		car = main.get("_cars")[0]
		var city: Node = main.get("city")
		# --- Blender model presence ---
		_ok(_count_named(car, "HoverCarModel") == 1, "car has Blender HoverCarModel")
		var mi: MeshInstance3D = _find_model(car)
		_ok(mi != null and mi.mesh != null and mi.mesh.get_surface_count() >= 6,
			"car mesh surfaces >= 6 (got %d)" % (mi.mesh.get_surface_count() if mi != null and mi.mesh != null else -1))
		var tinted: bool = false
		var names: String = ""
		if mi != null:
			for i in range(mi.mesh.get_surface_count()):
				var base: Material = mi.mesh.surface_get_material(i)
				if base != null:
					names += base.resource_name + "|"
				if mi.get_surface_override_material(i) != null:
					tinted = true
		print("car surface materials: ", names)
		_ok(tinted, "BodyPaint surface tinted with car color")
		# Orientation guard: the model's nose (LightFront) must be at -Z
		# and the rear bar at +Z in car space (a PI flip here once made
		# the car drive nose-backwards while every camera test passed).
		var fz: float = 0.0
		var rz: float = 0.0
		if mi != null:
			for i in range(mi.mesh.get_surface_count()):
				var m2: Material = mi.mesh.surface_get_material(i)
				if m2 == null:
					continue
				if m2.resource_name != "LightFront" and m2.resource_name != "LightRear":
					continue
				var arr: Array = mi.mesh.surface_get_arrays(i)
				var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var c := Vector3.ZERO
				for v in verts:
					c += mi.global_transform * v
				c /= verts.size()
				if m2.resource_name == "LightFront":
					fz = c.z - car.global_position.z
				else:
					rz = c.z - car.global_position.z
		_ok(fz < -1.5 and rz > 1.5, "car nose faces -Z (front z=%.2f rear z=%.2f)" % [fz, rz])
		_ok(_count_props(city, "Vending") >= 10, "vending machines placed (%d)" % _count_props(city, "Vending"))
		_ok(_count_props(city, "HoloTotem") >= 8, "holo totems placed (%d)" % _count_props(city, "HoloTotem"))
		_ok(_count_props(city, "TrafficLight") == 12, "traffic lights placed (%d)" % _count_props(city, "TrafficLight"))
		var heroes: Node = city.get_node_or_null("HeroTowers")
		_ok(heroes != null and heroes.get_child_count() == 4, "hero towers placed (%d)" % (heroes.get_child_count() if heroes != null else -1))
		# --- Drive camera regression at heading PI ---
		car.call("set_driven", true)
		car.set("heading", PI)
		car.set("speed", 0.0)
		phase = 1
	elif phase == 1:
		settle += 1
		if settle == 8:
			var h: float = car.get("heading")
			var fwd := Vector3(-sin(h), 0, -cos(h))
			var cam: Camera3D = car.get("_camera")
			var off: Vector3 = cam.global_position - car.global_position
			off.y = 0.0
			var view: Vector3 = -cam.global_transform.basis.z
			view.y = 0.0
			_ok(off.dot(fwd) < -2.0 and view.normalized().dot(fwd) > 0.6,
				"camera behind at heading PI (behind=%.2f align=%.2f)" % [off.dot(fwd), view.normalized().dot(fwd)])
			car.call("set_driven", false)
			phase = 2
	elif phase == 2:
		player.global_position = car.global_position + Vector3(1.5, 0.5, 0)
		main.call("_enter_car", car)
		_ok(player.get("in_car") != null, "entered car")
		main.call("interact")
		_ok(player.get("in_car") == null, "interact() exits the car")
		print("V12 TEST DONE")
		quit(1 if failed else 0)
		return true
	return false
