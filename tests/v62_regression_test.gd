extends SceneTree
## Regression: short/wide roulette viewports and reachable hack terminals.
const UI = preload("res://casino/casino_ui.gd")
const WORLD = preload("res://world_v4.gd")
const RL = preload("res://casino/roulette_logic.gd")

class Wallet extends Node:
	var chips: int = 100000

var fails: int = 0

func _ok(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ", label)
	if not value:
		fails += 1

func _initialize() -> void:
	_run.call_deferred()

func _button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found := _button(child, text)
		if found != null:
			return found
	return null

func _settle() -> void:
	for i in range(8):
		await process_frame

func _run() -> void:
	var wallet := Wallet.new()
	root.add_child(wallet)
	var ui := UI.new()
	root.add_child(ui)
	ui.set("_main", wallet)
	var font := FontLoader.load_font("res://assets/fonts/Rajdhani-Bold.ttf", "res://assets/font_data/rajdhani_bold.tres")
	ui.set("_font", font if font != null else ThemeDB.fallback_font)
	ui.set("_seated", {"min_bet": 25})
	var center := CenterContainer.new()
	ui.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.set("_root", center)
	for viewport_size in [Vector2(1152, 648), Vector2(1408, 648), Vector2(1152, 500)]:
		root.size = Vector2i(viewport_size)
		root.content_scale_size = Vector2i(viewport_size)
		await _settle()
		for with_result in [false, true]:
			ui.set("_roul_result", "結果: 7 RED — WIN 3600" if with_result else "")
			var bets: Array = ui.get("_roul_bets")
			bets.clear()
			if with_result:
				for n in range(37):
					var bet := RL.straight(n)
					bet["amount"] = 25
					bets.append(bet)
			ui.call("_render_roulette")
			await _settle()
			var rect := Rect2(Vector2.ZERO, viewport_size)
			for text in ["SPIN", "離席"]:
				var button := _button(center, text)
				_ok(button != null and rect.encloses(button.get_global_rect()), "%s visible %s result=%s" % [text, viewport_size, with_result])
			var scroll := center.find_child("BetScroll", true, false) as ScrollContainer
			_ok(scroll != null and scroll.size.y > 100, "bet area remains usable")
			if with_result and scroll != null:
				scroll.scroll_vertical = 100000
				await _settle()
				_ok(scroll.scroll_vertical > 0, "long bets scroll")
	# Resize the open panel without rebuilding it.
	root.size = Vector2i(1408, 560)
	root.content_scale_size = Vector2i(1408, 560)
	await _settle()
	_ok(Rect2(Vector2.ZERO, center.size).encloses(_button(center, "離席").get_global_rect()), "open panel resizes")
	# Information has longer text than the roulette panel; its close
	# button must remain outside the scrolling body and accept a real click.
	for viewport_size in [Vector2i(1152, 648), Vector2i(1408, 648), Vector2i(1152, 500)]:
		root.size = viewport_size
		root.content_scale_size = viewport_size
		ui.call("_open_info")
		await _settle()
		var close := _button(center, "閉じる")
		_ok(close != null and Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(close.get_global_rect()), "info close visible %s" % viewport_size)
		var scroll := center.find_child("BetScroll", true, false) as ScrollContainer
		_ok(scroll != null and not scroll.is_ancestor_of(close), "info close is fixed outside scroll")
		if close != null:
			var point := close.get_global_rect().get_center()
			for pressed in [true, false]:
				var click := InputEventMouseButton.new()
				click.position = point
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = pressed
				root.push_input(click, true)
			await _settle()
			_ok(center.get_child_count() == 0 and center.mouse_filter == Control.MOUSE_FILTER_IGNORE, "click closes info and releases input")
	ui.queue_free()
	wallet.queue_free()
	await _settle()
	var hud := preload("res://hud.gd").new()
	root.add_child(hud)
	hud.build(ThemeDB.fallback_font)
	for amount in [0, 250, 123456789]:
		hud.set_stats(20, 430, 0, "15:26", amount)
		_ok(hud.money_label.text == "€$ 430   |   CHIP %d" % amount, "HUD chip balance %d" % amount)
	await _settle()
	_ok(not hud.money_label.get_global_rect().intersects(hud.mission_label.get_global_rect()), "chip display clear of mission text")
	hud.queue_free()
	await _settle()
	var world := WORLD.new()
	root.add_child(world)
	world.call("_make_materials")
	world.set("_layout", LayoutV4.DATA)
	world.call("_build_pois")
	var terms: Array = world.get("poi_terminals")
	_ok(terms.size() == 4, "four hack targets")
	for term in terms:
		var pos: Vector3 = term
		_ok(is_equal_approx(pos.y, world.call("_terrain_height", pos.x, pos.z)), "terminal follows terrain %s" % pos)
		var clear := true
		for plot in LayoutV4.DATA["plots"]:
			var local := Vector2(pos.x - float(plot["x"]), pos.z - float(plot["z"])).rotated(float(plot["rot"]))
			if absf(local.x) < float(plot["w"]) / 2.0 + 1.2 and absf(local.y) < float(plot["d"]) / 2.0 + 1.2:
				clear = false
		_ok(clear, "terminal clear of buildings %s" % pos)
		var visible_terminal := false
		for child in world.get_children():
			if child is Node3D and child.position.is_equal_approx(pos) and child.get_child_count() == 2:
				visible_terminal = true
		_ok(visible_terminal, "target has terminal geometry %s" % pos)
	world.queue_free()
	await _settle()
	print("V62_REGRESSION_DONE fails=", fails)
	quit(1 if fails else 0)
