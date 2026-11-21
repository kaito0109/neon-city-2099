extends SceneTree
## Wheel calibration: top-down shots of roulette wheel A with the
## ball placed by casino_ui's pocket-angle formula for pockets 0 and
## 32. The ball must sit in the green 0 pocket, then in the red 32
## pocket (adjacent in the real European order); that fixes the sign
## of CasinoUI.POCKET_STEP and the value of POCKET_BASE.
var frames: int = 0
var main: Node
var cam: Camera3D
var stage: int = 0
var stage_t: int = 0
var ball: MeshInstance3D
var center: Vector3
var cui: Node

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(900, 900))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	cam = Camera3D.new()
	cam.far = 500.0
	root.add_child(cam)
	var sm := SphereMesh.new()
	sm.radius = 0.03
	sm.height = 0.06
	ball = MeshInstance3D.new()
	ball.mesh = sm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1, 1, 1)
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ball.material_override = bm
	root.add_child(ball)

func _place_ball(idx: int) -> void:
	var base: float = cui.get("POCKET_BASE")
	var step: float = cui.get("POCKET_STEP")
	var ang: float = base + float(idx) * step
	ball.global_position = center + Vector3(cos(ang), 0, sin(ang)) * 0.295
	print("ball idx ", idx, " angle ", ang)

func _process(_delta: float) -> bool:
	frames += 1
	stage_t += 1
	if frames == 20 and stage == 0:
		main.call("start_game")
		cui = main.get("casino_ui")
		var cz: Dictionary = {}
		for s in main.get("city").get("shop_sites"):
			if String(s["kind"]) == "casino":
				cz = s["casino"]
		var wheels: Array = cz["roulette_wheels"]
		var w0: Dictionary = wheels[0]
		(w0["pivot"] as Node3D).rotation.y = 0.0
		center = w0["center"]
		cam.make_current()
		cam.global_position = center + Vector3(0, 1.7, 0.001)
		cam.look_at(center, Vector3.UP)
		stage = 1
		stage_t = 0
	elif stage == 1 and stage_t > 25:
		_place_ball(0)
		stage = 2
		stage_t = 0
	elif stage == 2 and stage_t > 8:
		root.get_texture().get_image().save_png("res://shots/casino_wheel_p0.png")
		print("saved p0")
		var order: Array = [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
		_place_ball(order.find(32))
		stage = 3
		stage_t = 0
	elif stage == 3 and stage_t > 8:
		root.get_texture().get_image().save_png("res://shots/casino_wheel_p32.png")
		print("saved p32 — WHEEL_PROBE_DONE")
		quit(0)
	return false
