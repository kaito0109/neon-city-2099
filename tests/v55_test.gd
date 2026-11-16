extends SceneTree
## v5.5 regression: Sketchfab heroes/props placed, car fleet uses
## the new models, air traffic still 9 AVs. Run headless; when the
## assets/skf/*.glb files are moved aside this also verifies the
## ModelBlob route (the live web build has no .glb files).
var frames: int = 0
var main: Node
var fails: Array[String] = []

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS ", label)
	else:
		fails.append(label)
		print("FAIL ", label)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		main.call("start_game")
	if frames == 30:
		var city: Node = main.get("city")
		_check(int(city.get("skf_hero_count")) == 8, "skf heroes+props == 8")
		_check(int(city.get("plot_count")) < 164, "claimed plots suppressed")
		var cars: Array = main.get("_cars")
		var variants := {}
		var modelled := 0
		for c in cars:
			variants[int(c.get("model_variant"))] = true
			if (c as Node).find_child("HoverCarModel", true, false) != null:
				modelled += 1
		_check(variants.size() >= 2, "car variants alternate")
		_check(modelled == cars.size(), "every car got a model body")
		var air: Array = city.get("_air")
		_check(air.size() == 9, "air traffic == 9")
		print("RESULT fails=", fails.size())
		quit()
		return true
	return false
