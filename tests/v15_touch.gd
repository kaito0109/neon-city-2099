extends SceneTree
## Xvfb multitouch test: hold the stick with touch 0 while dragging
## the look with touch 1. The camera yaw must change smoothly (no
## single-frame spikes) and the stick must keep its value throughout.
var frames: int = 0
var main: Node
var hud: Node
var player: Node
var failed: bool = false
var started: bool = false
var stick_center: Vector2
var yaw_prev: float = 0.0
var max_step: float = 0.0
var yaw_start: float = 0.0
var drag_i: int = 0

func _ok(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		failed = true

func _initialize() -> void:
	var ps: PackedScene = load("res://main.tscn")
	main = ps.instantiate()
	root.add_child(main)

func _touch(index: int, pressed: bool, pos: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.pressed = pressed
	ev.position = pos
	Input.parse_input_event(ev)

func _drag(index: int, pos: Vector2, rel: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	ev.relative = rel
	Input.parse_input_event(ev)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 10 and not started:
		main.call("start_game")
		hud = main.get("hud")
		player = main.get("player")
		player.set("input_enabled", false)
		var joy: Control = hud.get("joystick")
		stick_center = joy.get_global_rect().get_center()
		_touch(0, true, stick_center)
		started = true
	elif started and frames == 13:
		_drag(0, stick_center + Vector2(45, 0), Vector2(45, 0))
	elif started and frames == 16:
		yaw_start = player.get("yaw")
		yaw_prev = yaw_start
		_touch(1, true, Vector2(700, 250))
	elif started and frames >= 18 and frames <= 66 and (frames % 2 == 0):
		drag_i += 1
		_drag(1, Vector2(700 + drag_i * 8, 250), Vector2(8, 0))
		# Also keep wiggling the stick finger slightly (both hands busy).
		_drag(0, stick_center + Vector2(45, sin(float(drag_i)) * 3.0), Vector2(0, 0))
	if started and frames >= 17:
		var y: float = player.get("yaw")
		max_step = maxf(max_step, absf(y - yaw_prev))
		yaw_prev = y
	if started and frames == 72:
		var joy2: Control = hud.get("joystick")
		var val: Vector2 = joy2.get("value")
		_ok(val.x > 0.3, "stick still held by touch 0 (value.x=%.2f)" % val.x)
		_ok(int(hud.get("look_pointer_id")) == 1, "look still owned by touch 1")
		var turned: float = yaw_start - player.get("yaw")
		_ok(turned > 0.5 and turned < 1.1, "yaw turned smoothly by look drag (%.3f rad)" % turned)
		_ok(max_step < 0.09, "no single-frame yaw spike (max %.4f rad)" % max_step)
		print("V15 TOUCH TEST DONE")
		quit(1 if failed else 0)
		return true
	return false
