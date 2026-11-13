extends SceneTree
## v2.6 checks: photo-facade buildings + car camera free-look state.
var frames: int = 0
var main: Node
var failed: bool = false

func _ok(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		failed = true

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 12:
		var city: Node = main.get("city")
		_ok((city.get("_photo_mats") as Array).size() == 3, "photo facade materials loaded (%d)" % (city.get("_photo_mats") as Array).size())
		_ok(int(city.get("photo_building_count")) >= 15, "photo buildings placed (%d)" % int(city.get("photo_building_count")))
		var car: Node = null
		for c in main.get("_cars"):
			car = c
			break
		car.call("add_car_look", Vector2(120, 40))
		_ok(absf(float(car.get("look_yaw"))) > 0.3, "car look yaw offset applies (%.2f)" % float(car.get("look_yaw")))
		_ok(float(car.get("look_pitch")) < -0.1, "car look pitch offset applies (%.2f)" % float(car.get("look_pitch")))
		print("V22 TEST DONE")
		quit(1 if failed else 0)
		return true
	return false
