extends SceneTree
## v5.9 probe: print the v5.9 build counters from the live world.
var frames: int = 0
var main: Node

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 20:
		main.call("start_game")
	if frames == 40:
		var city: Node = main.get("city")
		print("V59 greebles=", city.get("greeble_count_v59"),
			" skyline59=", city.get("skyline59_count"),
			" puddles=", city.get("puddle_count_v59"),
			" blotches=", city.get("blotch_count_v59"))
		quit()
	return false
