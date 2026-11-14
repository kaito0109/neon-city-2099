extends SceneTree
## v4.3 PDCA shots: (1) plaza ground view — plinth ring, painted
## markings, benches, softer lamp pools; (2) gameplay driving view
## — headlight cone after the device-photo fix; (3) aerial view —
## air traffic lanes over the fogged city.
var frames: int = 0
var main: Node
var stage: int = 0
var cam: Camera3D

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	cam = Camera3D.new()
	cam.far = 900.0
	root.add_child(cam)

func _snap(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 30 and stage == 0:
		stage = 1
		main.call("start_game")
	elif frames == 70 and stage == 1:
		stage = 2
		cam.make_current()
		cam.global_position = Vector3(3, 2.4, 36)
		cam.look_at(Vector3(-2, 7, -60), Vector3.UP)
	elif frames == 110 and stage == 2:
		stage = 3
		_snap("res://shots/v48_plaza.png")
		# Get into the nearest parked car for the driving view.
		var player: Node = main.get("player")
		var car: Node = null
		var best: float = 1e9
		for c in main.get("_cars"):
			if String(c.get("mode")) == "parked":
				var d: float = ((c as Node3D).global_position - Vector3(5, 0, 100)).length()
				if d < best:
					best = d
					car = c
		player.global_position = (car as Node3D).global_position + Vector3(2.0, 0.5, 0.0)
		player.set("velocity", Vector3.ZERO)
	elif frames == 120 and stage == 3:
		stage = 4
		main.call("interact")
	elif frames == 190 and stage == 4:
		stage = 5
		_snap("res://shots/v48_drive.png")
		cam.make_current()
		cam.global_position = Vector3(120, 72, 155)
		cam.look_at(Vector3(-10, 8, -20), Vector3.UP)
	elif frames == 260 and stage == 5:
		_snap("res://shots/v48_air.png")
		print("SHOTS DONE")
		quit()
		return true
	return false
