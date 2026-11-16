extends SceneTree
## v5.5 glow probe: does the Compatibility renderer honour
## Environment glow on this pipeline? Street shot with glow forced
## on, compared against the v55_c_street (glow off) frame.
var frames: int = 0
var main: Node
var cam: Camera3D

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1152, 648))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	cam = Camera3D.new()
	cam.far = 900.0
	root.add_child(cam)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 20:
		main.call("start_game")
		cam.make_current()
		for ch in main.get_children():
			if ch is WorldEnvironment:
				var env := (ch as WorldEnvironment).environment
				env.glow_enabled = true
				env.glow_intensity = 0.9
				env.glow_strength = 1.1
				env.glow_bloom = 0.12
				print("glow forced on")
	if frames == 40:
		cam.global_position = Vector3(2, 2.2, 54)
		cam.look_at(Vector3(-2, 8, -60), Vector3.UP)
	if frames == 47:
		root.get_texture().get_image().save_png("res://shots/v55_glow_street.png")
		print("GLOW SHOT DONE")
		quit()
		return true
	return false
