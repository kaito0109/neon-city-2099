extends CanvasLayer
## HUD for NEON CITY 2099: stats, minimap + big map, mission/prompt/toast,
## touch controls (stick, ACT/JUMP/DASH, drive pedals), panels, rotate notice.

const JoystickScene := preload("res://joystick.gd")
const MinimapScene := preload("res://minimap.gd")

var main: Node
var player: Node

var hp_bar: ProgressBar
var hp_label: Label
var money_label: Label
var wanted_label: Label
var clock_label: Label
var mission_label: Label
var center_label: Label
var prompt_label: Label
var toast_label: Label
var minimap: Control
var bigmap: Control
var big_map_open: bool = false

var joystick: Control
var touch_root: Control
var touch_buttons: Dictionary = {}
var touch_mode: bool = false
var _gas: bool = false
var _brk: bool = false

var panel: Panel
var panel_title: Label
var panel_text: Label
var panel_button: Button
var rotate_notice: ColorRect
var rotate_label: Label

var look_pointer_id: int = -2
var look_dragging: bool = false
var _look_last_pos: Vector2 = Vector2.ZERO
var _look_accum: Vector2 = Vector2.ZERO
var _center_t: float = 0.0
var _toast_t: float = 0.0

func _mk_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func build(font: Font) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	if font != null:
		var theme := Theme.new()
		theme.default_font = font
		theme.default_font_size = 18
		root.theme = theme
	add_child(root)
	# Stats.
	hp_label = _mk_label("HP", 16, Color(0.6, 1, 0.8))
	hp_label.position = Vector2(16, 10)
	root.add_child(hp_label)
	hp_bar = ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.position = Vector2(52, 10)
	hp_bar.size = Vector2(170, 18)
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hp_bar)
	money_label = _mk_label("€$ 0", 20, Color(1.0, 0.85, 0.3))
	money_label.position = Vector2(16, 34)
	root.add_child(money_label)
	wanted_label = _mk_label("", 22, Color(1.0, 0.3, 0.3))
	wanted_label.position = Vector2(16, 62)
	root.add_child(wanted_label)
	clock_label = _mk_label("21:00", 18, Color(0.65, 0.85, 1))
	clock_label.position = Vector2(238, 10)
	root.add_child(clock_label)
	mission_label = _mk_label("", 18, Color(0.55, 0.95, 1))
	mission_label.position = Vector2(16, 92)
	mission_label.size = Vector2(560, 54)
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(mission_label)
	# Minimap.
	minimap = MinimapScene.new()
	minimap.size = Vector2(176, 176)
	root.add_child(minimap)
	bigmap = MinimapScene.new()
	bigmap.size = Vector2(520, 520)
	bigmap.visible = false
	root.add_child(bigmap)
	# Center / prompt / toast.
	center_label = _mk_label("", 30, Color(1, 0.9, 0.4))
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(center_label)
	toast_label = _mk_label("", 20, Color(0.5, 1, 0.6))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(toast_label)
	prompt_label = _mk_label("", 20, Color(1, 1, 1))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt_label)
	# Touch UI.
	touch_root = Control.new()
	touch_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_root.visible = false
	root.add_child(touch_root)
	joystick = JoystickScene.new()
	touch_root.add_child(joystick)
	_mk_touch_button("ACT", "ACT")
	_mk_touch_button("JUMP", "JUMP")
	_mk_touch_button("DASH", "DASH")
	_mk_touch_button("GAS", "GAS")
	_mk_touch_button("BRK", "BRK")
	_mk_touch_button("MAP", "MAP")
	touch_buttons["ACT"].pressed.connect(func() -> void: main.call("interact"))
	touch_buttons["JUMP"].button_down.connect(func() -> void: player.call("queue_jump"))
	touch_buttons["DASH"].button_down.connect(func() -> void: player.set("touch_dashing", true))
	touch_buttons["DASH"].button_up.connect(func() -> void: player.set("touch_dashing", false))
	touch_buttons["GAS"].button_down.connect(func() -> void: _gas = true)
	touch_buttons["GAS"].button_up.connect(func() -> void: _gas = false)
	touch_buttons["BRK"].button_down.connect(func() -> void: _brk = true)
	touch_buttons["BRK"].button_up.connect(func() -> void: _brk = false)
	touch_buttons["MAP"].pressed.connect(func() -> void: _toggle_big_map())
	# Rotate notice.
	rotate_notice = ColorRect.new()
	rotate_notice.color = Color(0, 0, 0, 0.62)
	rotate_notice.set_anchors_preset(Control.PRESET_FULL_RECT)
	rotate_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotate_notice.visible = false
	root.add_child(rotate_notice)
	rotate_label = _mk_label("デバイスを横向きにしてください", 26, Color(1, 1, 1))
	rotate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(rotate_label)
	_build_panel(root)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _mk_touch_button(id: String, text: String) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(74, 74)
	b.size = Vector2(74, 74)
	b.modulate = Color(1, 1, 1, 0.85)
	touch_root.add_child(b)
	touch_buttons[id] = b

func _build_panel(root: Control) -> void:
	panel = Panel.new()
	panel.size = Vector2(560, 392)
	root.add_child(panel)
	panel_title = _mk_label("NEON CITY 2099", 34, Color(1.0, 0.3, 0.75))
	panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(panel_title)
	panel_text = _mk_label("", 16, Color(0.9, 0.95, 1))
	panel_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(panel_text)
	panel_button = Button.new()
	panel_button.text = "スタート"
	panel_button.size = Vector2(200, 52)
	panel_button.pressed.connect(func() -> void: main.call("on_panel_button"))
	panel.add_child(panel_button)

func _layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	minimap.position = Vector2(vp.x - 192, 14)
	bigmap.position = Vector2((vp.x - 520) * 0.5, (vp.y - 520) * 0.5)
	center_label.position = Vector2(40, vp.y * 0.3)
	center_label.size = Vector2(vp.x - 80, 44)
	toast_label.position = Vector2(40, vp.y * 0.3 + 48)
	toast_label.size = Vector2(vp.x - 80, 32)
	prompt_label.position = Vector2(40, vp.y - 120)
	prompt_label.size = Vector2(vp.x - 80, 32)
	rotate_label.position = Vector2(20, vp.y * 0.5 - 24)
	rotate_label.size = Vector2(vp.x - 40, 48)
	joystick.position = Vector2(26, vp.y - 206)
	touch_buttons["ACT"].position = Vector2(vp.x - 108, vp.y - 196)
	touch_buttons["JUMP"].position = Vector2(vp.x - 196, vp.y - 108)
	touch_buttons["DASH"].position = Vector2(vp.x - 108, vp.y - 288)
	touch_buttons["MAP"].position = Vector2(vp.x - 196, vp.y - 380)
	touch_buttons["GAS"].position = Vector2(vp.x - 108, vp.y - 196)
	touch_buttons["BRK"].position = Vector2(vp.x - 196, vp.y - 196)
	panel.position = Vector2((vp.x - 560) * 0.5, (vp.y - 392) * 0.5)
	panel_title.position = Vector2(20, 18)
	panel_title.size = Vector2(520, 44)
	panel_text.position = Vector2(30, 74)
	panel_text.size = Vector2(500, 232)
	panel_button.position = Vector2(180, 318)

func _toggle_big_map() -> void:
	big_map_open = not big_map_open
	bigmap.visible = big_map_open

func show_panel(title: String, text: String, button: String) -> void:
	panel.visible = true
	panel_title.text = title
	panel_text.text = text
	panel_button.text = button

func hide_panel() -> void:
	panel.visible = false

func set_stats(hp: float, money: int, wanted: int, clock_str: String) -> void:
	hp_bar.value = hp
	money_label.text = "€$ %d" % money
	wanted_label.text = "★".repeat(wanted) if wanted > 0 else ""
	clock_label.text = clock_str

func set_mission(text: String) -> void:
	mission_label.text = text

func set_prompt(text: String) -> void:
	prompt_label.text = text

func show_center_message(text: String) -> void:
	center_label.text = text
	_center_t = 2.6

func toast(text: String) -> void:
	toast_label.text = text
	_toast_t = 3.2

func _process(delta: float) -> void:
	if player == null:
		return
	# Apply batched touch-look once per frame (see _input): this keeps
	# the camera steady even when drag events arrive in bursts.
	if _look_accum != Vector2.ZERO:
		if player.get("in_car") == null:
			player.call("add_look_input", _look_accum)
		_look_accum = Vector2.ZERO
	if _center_t > 0.0:
		_center_t -= delta
		if _center_t <= 0.0:
			center_label.text = ""
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast_label.text = ""
	var vsize: Vector2 = get_viewport().get_visible_rect().size
	var portrait: bool = vsize.y > vsize.x
	rotate_notice.visible = portrait
	rotate_label.visible = portrait
	# Touch visibility: real touch devices, or after the first touch.
	touch_root.visible = touch_mode or DisplayServer.is_touchscreen_available()
	if touch_root.visible:
		player.set("touch_move", joystick.get("value"))
		var driving: bool = player.get("in_car") != null
		touch_buttons["GAS"].visible = driving
		touch_buttons["BRK"].visible = driving
		touch_buttons["JUMP"].visible = not driving
		touch_buttons["DASH"].visible = not driving
		# ACT shares its spot with GAS; while driving, move ACT to the
		# (hidden) DASH slot so the exit button stays tappable.
		touch_buttons["ACT"].position = Vector2(vsize.x - 108, vsize.y - 288) if driving \
			else Vector2(vsize.x - 108, vsize.y - 196)
		var td := Vector2(joystick.get("value").x, 0.0)
		if _gas:
			td.y = 1.0
		elif _brk:
			td.y = -1.0
		main.set("touch_drive", td)
	minimap.set("main", main)
	bigmap.set("main", main)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_M:
			_toggle_big_map()
	if event is InputEventScreenTouch:
		touch_mode = true
		var st := event as InputEventScreenTouch
		if st.pressed and look_pointer_id == -2 and _is_look_area(st.position):
			look_pointer_id = st.index
			_look_last_pos = st.position
			_look_accum = Vector2.ZERO
		elif not st.pressed and st.index == look_pointer_id:
			look_pointer_id = -2
			_look_accum = Vector2.ZERO
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == look_pointer_id:
			# Compute the delta from absolute positions ourselves:
			# InputEventScreenDrag.relative gets noisy/spiky when two
			# fingers drag at once (and can jump on the first event),
			# which made the view wobble while running with the stick.
			var delta: Vector2 = sd.position - _look_last_pos
			_look_last_pos = sd.position
			if delta.length() > 64.0:
				delta = delta.normalized() * 64.0
			_look_accum += delta
	elif not DisplayServer.is_touchscreen_available() and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and look_pointer_id == -2 and _is_look_area(mb.position):
				look_pointer_id = -1
				look_dragging = true
			elif not mb.pressed and look_pointer_id == -1:
				look_pointer_id = -2
				look_dragging = false
	elif not DisplayServer.is_touchscreen_available() and event is InputEventMouseMotion and look_pointer_id == -1 and look_dragging:
		var mm := event as InputEventMouseMotion
		if player != null and player.get("in_car") == null:
			player.call("add_look_input", mm.relative)

func _is_look_area(pos: Vector2) -> bool:
	if panel.visible:
		return false
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if pos.x < vp.x * 0.42:
		return false
	if touch_root.visible:
		for id: String in touch_buttons.keys():
			var b: Button = touch_buttons[id] as Button
			if b.visible and b.get_global_rect().has_point(pos):
				return false
		if joystick.get_global_rect().has_point(pos):
			return false
	return true
