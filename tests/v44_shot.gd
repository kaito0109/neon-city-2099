extends SceneTree
## Phase 2.6 visual check: down Ave A toward a gantry sign bridge,
## then the market street at street level.
var frames: int = 0
var main: Node
var _stage: int = 0
var _cam: Camera3D

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	_cam = Camera3D.new()
	_cam.far = 3000.0
	root.add_child(_cam)

func _save(name: String) -> void:
	var img: Image = root.get_texture().get_image()
	img.save_png("res://shots/" + name)
	print("saved ", name, " draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		main.call("start_game")
	elif frames == 30:
		_cam.global_position = Vector3(74, 2.0, -66)
		_cam.look_at(Vector3(104, 6.5, -92), Vector3.UP)
		_cam.make_current()
		_stage = 1
	elif frames == 50 and _stage == 1:
		_save("v44_a_gantry.png")
		_cam.global_position = Vector3(-46, 1.8, 128)
		_cam.look_at(Vector3(30, 4.0, 140), Vector3.UP)
		_stage = 2
	elif frames == 70 and _stage == 2:
		_save("v44_b_market.png")
		return true
	return false
