extends Control
## Virtual joystick with true multitouch: tracks one touch index (or the
## mouse) so the camera can be dragged with another finger at the same time.

var value: Vector2 = Vector2.ZERO
var knob_offset: Vector2 = Vector2.ZERO
var dragging: bool = false
var radius: float = 85.0
var _pointer_id: int = -2  # -2 = none, -1 = mouse, >=0 = touch index

func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	size = custom_minimum_size
	mouse_filter = MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	# On touch devices the OS touch path is authoritative; emulated mouse
	# events (needed so GUI Buttons receive taps) must not drive the stick.
	var allow_mouse: bool = not DisplayServer.is_touchscreen_available()
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed and _pointer_id == -2 and get_global_rect().has_point(st.position):
			_pointer_id = st.index
			dragging = true
			_update_knob(st.position)
		elif not st.pressed and st.index == _pointer_id:
			_release()
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if sd.index == _pointer_id:
			_update_knob(sd.position)
	elif allow_mouse and event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _pointer_id == -2 and get_global_rect().has_point(mb.position):
				_pointer_id = -1
				dragging = true
				_update_knob(mb.position)
			elif not mb.pressed and _pointer_id == -1:
				_release()
	elif allow_mouse and event is InputEventMouseMotion:
		if _pointer_id == -1 and dragging:
			_update_knob((event as InputEventMouseMotion).position)

func _release() -> void:
	_pointer_id = -2
	dragging = false
	value = Vector2.ZERO
	knob_offset = Vector2.ZERO
	queue_redraw()

func _update_knob(global_pos: Vector2) -> void:
	var local_pos: Vector2 = get_global_transform().affine_inverse() * global_pos
	var center: Vector2 = size * 0.5
	var delta: Vector2 = local_pos - center
	if delta.length() > radius:
		delta = delta.normalized() * radius
	knob_offset = delta
	# Feel: 0.12 deadzone, then a 1.35 power curve so small pushes
	# walk and full pushes run (raw knob travel stays 1:1 visual).
	var raw: Vector2 = delta / radius
	var mag: float = raw.length()
	if mag < 0.12:
		value = Vector2.ZERO
	else:
		var curved: float = pow(clampf((mag - 0.12) / 0.88, 0.0, 1.0), 1.35)
		value = raw.normalized() * curved
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	draw_circle(center, radius, Color(0.004, 0.012, 0.022, 0.55))
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.0, 0.94, 1.0, 0.65), 2.5)
	draw_arc(center, radius * 0.78, 0.0, TAU, 48, Color(0.0, 0.94, 1.0, 0.16), 1.5)
	# Diagonal tick marks (CP HUD flavour).
	for a in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		var d := Vector2(cos(a), sin(a))
		draw_line(center + d * (radius - 9.0), center + d * (radius - 2.0), Color(1.0, 0.0, 0.235, 0.8), 2.5)
	var kc: Vector2 = center + knob_offset
	draw_circle(kc, radius * 0.42, Color(0.01, 0.04, 0.06, 0.75))
	draw_arc(kc, radius * 0.42, 0.0, TAU, 40, Color(0.0, 0.94, 1.0, 0.9), 2.5)
	draw_circle(kc, 4.0, Color(0.0, 0.94, 1.0, 0.9))
