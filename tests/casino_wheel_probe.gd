extends SceneTree
## Top-down calibration shots of adjacent green 0 and red 32 pockets.
const WHEEL := preload("res://casino/roulette_wheel.gd")
var frames: int = 0
var main: Node
var cam: Camera3D
var stage: int = 0
var stage_t: int = 0
var ball: MeshInstance3D
var center: Vector3
var pivot: Node3D

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(900, 900))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	cam = Camera3D.new()
	cam.far = 500.0
	root.add_child(cam)
	var sm := SphereMesh.new()
	sm.radius = WHEEL.BALL_RADIUS
	sm.height = WHEEL.BALL_RADIUS * 2.0
	ball = MeshInstance3D.new()
	ball.mesh = sm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1, 1, 1)
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ball.material_override = bm
	root.add_child(ball)

func _place_ball(idx: int) -> void:
	var ang := idx * WHEEL.STEP
	ball.global_position = pivot.to_global(Vector3(cos(ang) * WHEEL.POCKET_RADIUS,
		WHEEL.POCKET_HEIGHT + WHEEL.BALL_RADIUS, sin(ang) * WHEEL.POCKET_RADIUS))

func _process(_delta: float) -> bool:
	frames += 1
	stage_t += 1
	if frames == 20 and stage == 0:
		main.call("start_game")
		var cz: Dictionary = {}
		for s in main.get("city").get("shop_sites"):
			if String(s["kind"]) == "casino":
				cz = s["casino"]
		var wheels: Array = cz["roulette_wheels"]
		var w0: Dictionary = wheels[0]
		pivot = w0["pivot"]
		pivot.rotation.y = 0.0
		WHEEL.add_numbers(pivot)
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
		_place_ball(1)
		stage = 3
		stage_t = 0
	elif stage == 3 and stage_t > 8:
		root.get_texture().get_image().save_png("res://shots/casino_wheel_p32.png")
		print("saved p32 — WHEEL_PROBE_DONE")
		quit(0)
	return false

