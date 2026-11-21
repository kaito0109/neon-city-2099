extends CanvasLayer
## CASINO NEON PEARL — panels, seating and game controllers.
## All rules live in the pure logic classes (casino/*_logic.gd);
## this file is presentation + flow only. Economy: main.money is
## cash, main.chips is the chip balance; NEON CIRCLE points derive
## from main.casino_stats.total_bet (100 bet = 1 pt).

const BJL := preload("res://casino/blackjack_logic.gd")
const ROL := preload("res://casino/roulette_logic.gd")
const PKL := preload("res://casino/poker_logic.gd")

const GOLD := Color(0.85, 0.65, 0.25)
const PINK := Color(1.0, 0.45, 0.75)

var _main: Node = null
var _player: Node3D = null
var _font: Font = null
var _site: Dictionary = {}
var _cz: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _card_atlas: Texture2D = null

var _root: CenterContainer = null
var _banner: Label = null
var _banner_t: float = 0.0

# seating
var _seated: Dictionary = {}
var _seat_back: Vector3 = Vector3.ZERO

# patrol / ambience state
var _patrol_state: Array = []   # {node, points, seg, pos}
var _vip_warned_cd: float = 0.0

# cage
var _cage_amount: int = 1000
var _cage_vip: bool = false

# blackjack
var _bj_shoe: RefCounted = null
var _bj: RefCounted = null
var _bj_bet: int = 0
var _bj_reveal: Array = []      # pending dealer-card reveal steps
var _bj_reveal_t: float = 0.0
var _bj_settled: bool = true

# roulette
var _roul_bets: Array = []
var _roul_last: Array = []
var _roul_denom: int = 100
var _roul_mode: String = "straight"
var _roul_first: int = -1
var _spin: Dictionary = {}
var _ball: MeshInstance3D = null
var _dolly: MeshInstance3D = null
# Wheel calibration (verified by tests/casino_wheel_probe.gd shots):
# pocket index i sits at local angle POCKET_BASE + i * POCKET_STEP,
# angle measured atan2(z, x) in the wheel pivot's local space.
var POCKET_BASE: float = 0.0 # calibrated 2026-11-21 (wheel probe shots:
var POCKET_STEP: float = -TAU / 37.0 # ball rests in green 0 at idx 0, red 32 at idx 1)
const BALL_R_OUT: float = 0.40
const BALL_R_IN: float = 0.295

# poker
var _pk: RefCounted = null
var _pk_wait: float = 0.0
var _pk_phase: String = ""      # "" | "play" | "showdown" | "rebuy"
var _pk_show_t: float = 0.0

# slot
var _slot_reels: Array = []

func setup(m: Node, font: Font) -> void:
	_main = m
	_font = font
	_player = m.get("player")
	_rng.randomize()
	var city: Node = m.get("city")
	if city != null:
		for s in city.get("shop_sites"):
			if String(s.get("kind", "")) == "casino":
				_site = s
				_cz = s["casino"]
				break
	_card_atlas = TextureLoader.load_tex(
		"res://assets/textures/card_atlas.jpg", "res://assets/texture_data/card_atlas.tres")
	_root = CenterContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_override("font", _font)
	_banner.add_theme_font_size_override("font_size", 40)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_banner.position = Vector2(-400, 90)
	_banner.size = Vector2(800, 60)
	_banner.visible = false
	add_child(_banner)
	# roulette ball + dolly live in the 3D world
	var sm := SphereMesh.new()
	sm.radius = 0.021
	sm.height = 0.042
	_ball = MeshInstance3D.new()
	_ball.mesh = sm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.95, 0.95, 0.98)
	bm.metallic = 0.6
	bm.roughness = 0.25
	_ball.material_override = bm
	_ball.visible = false
	_main.add_child(_ball)
	for pd in _cz.get("patrols", []):
		_patrol_state.append({"node": pd["node"], "points": pd["points"],
			"speed": float(pd["speed"]), "seg": 0})
		People.play(People.find_ap(pd["node"]), "Walk")

# --- economy helpers ---------------------------------------------------

func _chips() -> int:
	return int(_main.get("chips"))

func _money() -> int:
	return int(_main.get("money"))

func _points() -> int:
	return int(_main.get("casino_stats")["total_bet"]) / 100

func _rank() -> String:
	var p: int = _points()
	if p >= 10000:
		return "GOLD"
	if p >= 1000:
		return "SILVER"
	return "MEMBER"

func _is_gold() -> bool:
	return _points() >= 10000

func _track_bet(amount: int) -> void:
	var st: Dictionary = _main.get("casino_stats")
	st["total_bet"] = int(st["total_bet"]) + amount

func _track_return(amount: int) -> void:
	var st: Dictionary = _main.get("casino_stats")
	st["total_returned"] = int(st["total_returned"]) + amount

func _toast(msg: String) -> void:
	_main.get("hud").call("toast", msg)

func _show_banner(msg: String, secs: float = 3.0) -> void:
	_banner.text = msg
	_banner.visible = true
	_banner_t = secs

# --- generic panel scaffolding -----------------------------------------

func _close_panel() -> void:
	if _root != null:
		for c in _root.get_children():
			c.queue_free()
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

var _sb_cache: Dictionary = {}

func _panel_style(w: int, h: int) -> StyleBoxTexture:
	var key: String = "panel|%d|%d" % [w, h]
	if not _sb_cache.has(key):
		_sb_cache[key] = CpUi.style(Vector2i(w, h), CpUi.INK_SOLID, GOLD, 16.0, 3.0)
	return _sb_cache[key]

func _fit_scroll_panel(pc: PanelContainer, min_size: Vector2) -> void:
	pc.custom_minimum_size = Vector2(min_size.x, minf(min_size.y, maxf(1.0, get_viewport().get_visible_rect().size.y - 32.0)))

func _open_panel(title: String, min_size: Vector2, scrollable: bool = false) -> VBoxContainer:
	_close_panel()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var pc := PanelContainer.new()
	pc.custom_minimum_size = min_size
	pc.add_theme_stylebox_override("panel", _panel_style(int(min_size.x), int(min_size.y)))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	if scrollable:
		var outer := VBoxContainer.new()
		pc.add_child(outer)
		var scroll := ScrollContainer.new()
		scroll.name = "BetScroll"
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		outer.add_child(scroll)
		scroll.add_child(vb)
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.set_meta("actions_parent", outer)
		_fit_scroll_panel(pc, min_size)
		var fit := func() -> void: _fit_scroll_panel(pc, min_size)
		get_viewport().size_changed.connect(fit)
		pc.tree_exiting.connect(func() -> void:
			if get_viewport().size_changed.is_connected(fit):
				get_viewport().size_changed.disconnect(fit))
	else:
		pc.add_child(vb)
	var head := HBoxContainer.new()
	var tl := _mk_label(title, 30, GOLD)
	head.add_child(tl)
	var spacer := Control.new()
	head.add_child(spacer)
	var bal := _mk_label("チップ %d" % _chips(), 22, CpUi.ICY)
	bal.name = "BalLabel"
	head.add_child(bal)
	vb.add_child(head)
	_root.add_child(pc)
	return vb

func _refresh_bal(vb: Node) -> void:
	var bal: Label = vb.get_parent().find_child("BalLabel", true, false) as Label
	if bal != null:
		bal.text = "チップ %d" % _chips()

func _mk_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# a wrapping CJK label reports a ~1-char minimum width, so inside an
	# HBox it collapses into a vertical strip; expanding fixes the row
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _mk_button(text: String, rim: Color, min_w: float = 120.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 56)
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", CpUi.ICY)
	b.add_theme_color_override("font_pressed_color", Color(0.02, 0.03, 0.04))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.5, 0.55))
	var w: int = maxi(120, int(min_w))
	var key: String = "btn|%d|%s" % [w, str(rim)]
	if not _sb_cache.has(key):
		_sb_cache[key] = {
			"normal": CpUi.style(Vector2i(w, 56), CpUi.INK, rim, 10.0, 2.5),
			"hover": CpUi.style(Vector2i(w, 56), Color(0.05, 0.08, 0.1, 0.95), rim, 10.0, 3.0),
			"pressed": CpUi.style(Vector2i(w, 56), rim, rim, 10.0, 2.5),
			"disabled": CpUi.style(Vector2i(w, 56), Color(0.02, 0.03, 0.04, 0.6), Color(0.3, 0.32, 0.35, 0.7), 10.0, 2.0),
		}
	var st: Dictionary = _sb_cache[key]
	b.add_theme_stylebox_override("normal", st["normal"])
	b.add_theme_stylebox_override("hover", st["hover"])
	b.add_theme_stylebox_override("pressed", st["pressed"])
	b.add_theme_stylebox_override("disabled", st["disabled"])
	return b

func _card_rect(card: int, back: bool, w: float = 62.0) -> TextureRect:
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(w, w * 1.4)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	if _card_atlas != null:
		var at := AtlasTexture.new()
		at.atlas = _card_atlas
		var sz: Vector2 = _card_atlas.get_size()
		var cw: float = sz.x / 13.0
		var ch: float = sz.y / 5.0
		if back:
			at.region = Rect2(0, 4.0 * ch, cw, ch)
		else:
			at.region = Rect2(float(card % 13) * cw, float(card / 13) * ch, cw, ch)
		tr.texture = at
	return tr

# --- interaction (called from main._shop_interact / _update_prompts) ---

func _near(pos: Vector3, d: float) -> bool:
	return _player.global_position.distance_to(pos) < d

func handle_interact() -> void:
	if _main == null or _site.is_empty() or not _seated.is_empty():
		return
	if _near(_site["exit_pos"], 2.4):
		_close_panel()
		_main.call("_exit_shop")
		return
	for cp in _cz["cage_pos"]:
		if _near(cp, 2.6):
			_open_cage(false)
			return
	if _near(_cz["vip_cage_pos"], 2.6):
		_open_cage(true)
		return
	if _near(_cz["info_pos"], 2.6):
		_open_info()
		return
	if _near(_cz["circle_pos"], 2.6):
		_open_circle()
		return
	for b in _site["buys"]:
		if _near(b["pos"], 2.2):
			_main.call("_buy", b)
			return
	for t in _cz["tables"]:
		if _near(t["seat_pos"], 2.0):
			_seat(t)
			return
	if _near(_cz["slot_pos"], 2.4):
		_open_slot()
		return

func hint_text() -> String:
	if not _seated.is_empty():
		return ""
	if _near(_site["exit_pos"], 2.4):
		return "F / ACT: カジノを出る"
	for cp in _cz["cage_pos"]:
		if _near(cp, 2.6):
			return "F / ACT: キャッシャー（チップ購入・換金）"
	if _near(_cz["vip_cage_pos"], 2.6):
		return "F / ACT: VIPキャッシャー"
	if _near(_cz["info_pos"], 2.6):
		return "F / ACT: インフォメーション"
	if _near(_cz["circle_pos"], 2.6):
		return "F / ACT: NEON CIRCLE窓口"
	for b in _site["buys"]:
		if _near(b["pos"], 2.2):
			return "F / ACT: %sを買う €$%d" % [String(b["label"]), int(b["price"])]
	for t in _cz["tables"]:
		if _near(t["seat_pos"], 2.0):
			if bool(t["vip"]) and not _is_gold():
				return "%s（VIP: GOLDランクで解放）" % String(t["name"])
			return "F / ACT: %sに着席（ミニマム %d）" % [String(t["name"]), int(t["min_bet"])]
	if _near(_cz["slot_pos"], 2.4):
		return "F / ACT: スロットで遊ぶ（1回 25）"
	return ""

# --- seating -------------------------------------------------------------

func _seat(t: Dictionary) -> void:
	if bool(t["vip"]) and not _is_gold():
		_toast("VIP卓は NEON CIRCLE GOLDランク（累計ベット €$1,000,000）で解放される")
		return
	if String(t["kind"]) == "poker" and _chips() < 2500:
		_toast("ポーカーのバイインは 2,500 チップ — キャッシャーで購入しよう")
		return
	_seated = t
	_seat_back = (t["seat_pos"] as Vector3) + Vector3(0, 0, 1.1)
	_player.global_position = (t["seat_pos"] as Vector3) + Vector3(0, 0.05, 0)
	if _player is CharacterBody3D:
		(_player as CharacterBody3D).velocity = Vector3.ZERO
	_player.set("input_enabled", false)
	var yaw: float = float(t["seat_yaw"])
	_player.set("yaw", yaw)
	_player.set("_yaw_t", yaw)
	var pitch: float = -0.34 if String(t["kind"]) != "roulette" else -0.42
	_player.set("pitch", pitch)
	_player.set("_pitch_t", pitch)
	_player.set("_model_yaw", yaw + PI)
	var model: Node = _player.get("_model")
	if model is Node3D:
		(model as Node3D).rotation.y = yaw + PI
	match String(t["kind"]):
		"bj":
			_player.call("set_camera_dist", 2.3)
			_open_bj()
		"roulette":
			_player.call("set_camera_dist", 3.1)
			_open_roulette()
		"poker":
			_player.call("set_camera_dist", 2.9)
			_open_poker()

func _unseat() -> void:
	_close_panel()
	_bj = null
	_pk = null
	_pk_phase = ""
	_spin.clear()
	if _ball != null:
		_ball.visible = false
	_seated = {}
	_player.global_position = _seat_back
	if _player is CharacterBody3D:
		(_player as CharacterBody3D).velocity = Vector3.ZERO
	_player.set("input_enabled", true)
	_player.call("set_camera_dist", float(_site.get("cam_dist", 3.4)))

func force_leave() -> void:
	if not _seated.is_empty():
		# death while seated: the stack goes back to the chip balance
		if _pk != null:
			_main.set("chips", _chips() + _pk_player_stack())
		_seated = {}
		_pk = null
		_pk_phase = ""
	_close_panel()
	_spin.clear()
	if _ball != null:
		_ball.visible = false

func _pk_player_stack() -> int:
	if _pk == null:
		return 0
	var pls: Array = _pk.get("players")
	if pls.is_empty():
		return 0
	return int(pls[0]["stack"])

# --- per-frame: patrols, chandeliers, VIP gate, animations --------------

func tick(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t <= 0.0:
			_banner.visible = false
	_vip_warned_cd = maxf(0.0, _vip_warned_cd - delta)
	# chandeliers slowly turn
	for ch in _cz.get("chandeliers", []):
		(ch as Node3D).rotation.y += delta * 0.12
	# patrols walk their loops (only while the player is inside)
	for ps in _patrol_state:
		var node: Node3D = ps["node"]
		var pts: Array = ps["points"]
		if pts.size() < 2:
			continue
		var target: Vector3 = pts[(int(ps["seg"]) + 1) % pts.size()]
		var pos: Vector3 = node.global_position
		var to: Vector3 = target - pos
		to.y = 0.0
		var dist: float = to.length()
		if dist < 0.4:
			ps["seg"] = (int(ps["seg"]) + 1) % pts.size()
			continue
		var step: Vector3 = to / dist * minf(float(ps["speed"]) * delta, dist)
		node.global_position = pos + step
		node.rotation.y = lerp_angle(node.rotation.y, atan2(to.x, to.z), clampf(delta * 6.0, 0.0, 1.0))
	# VIP gate: the salon is GOLD-only; gently push non-members out
	if _seated.is_empty() and not _is_gold():
		var c: Vector3 = _cz["center"]
		var lp := Vector2(_player.global_position.x - c.x, _player.global_position.z - c.z)
		if (_cz["vip_rect"] as Rect2).has_point(lp):
			_player.global_position = _cz["vip_door_out"]
			if _vip_warned_cd <= 0.0:
				_vip_warned_cd = 4.0
				_toast("VIPサロンは GOLDランク専用 — ボディガードに止められた")
	# blackjack dealer reveal pacing
	if not _bj_reveal.is_empty():
		_bj_reveal_t -= delta
		if _bj_reveal_t <= 0.0:
			_bj_reveal_t = 0.45
			_bj_reveal.pop_front()
			_bj_reveal_count = _bj_reveal.size()
			_render_bj()
			if _bj_reveal.is_empty():
				_settle_bj()
	# roulette spin animation
	if not _spin.is_empty():
		_tick_spin(delta)
	# poker CPU pacing
	if _pk != null and _pk_phase == "play":
		_pk_wait -= delta
		if _pk_wait <= 0.0:
			_pk_wait = 0.85
			_poker_step()
	if _pk != null and _pk_phase == "showdown":
		_pk_show_t -= delta
		if _pk_show_t <= 0.0:
			_poker_next_hand_or_rebuy()

# --- cage / info / circle / slot panels ----------------------------------

func _open_cage(vip: bool) -> void:
	_cage_vip = vip
	var vb := _open_panel("キャッシャー CASHIER" + (" (VIP)" if vip else ""), Vector2(560, 470))
	var info := _mk_label("レート: €$1 = 1 CHIP\n所持金 €$%d ／ チップ %d" % [_money(), _chips()], 22, CpUi.ICY)
	info.name = "CageInfo"
	vb.add_child(info)
	vb.add_child(_mk_label("金額を選んでください", 20, CpUi.CYAN))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for amt in [100, 500, 1000, 2500, 10000]:
		var b := _mk_button(str(amt), CpUi.CYAN, 96)
		b.pressed.connect(func() -> void:
			_cage_amount = amt
			_refresh_cage(vb))
		row.add_child(b)
	vb.add_child(row)
	var amt_label := _mk_label("", 26, GOLD)
	amt_label.name = "CageAmount"
	vb.add_child(amt_label)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	var buy := _mk_button("チップを買う", CpUi.YELLOW, 170)
	buy.pressed.connect(func() -> void:
		if _money() < _cage_amount:
			_toast("€$が足りない（チップ %d には €$%d 必要）" % [_cage_amount, _cage_amount])
			return
		_main.set("money", _money() - _cage_amount)
		_main.set("chips", _chips() + _cage_amount)
		_toast("チップ %d を購入した" % _cage_amount)
		_refresh_cage(vb)
		_refresh_bal(vb))
	row2.add_child(buy)
	var sell := _mk_button("換金する", CpUi.CYAN, 170)
	sell.pressed.connect(func() -> void:
		if _chips() < _cage_amount:
			_toast("チップが足りない（所持 %d）" % _chips())
			return
		_main.set("chips", _chips() - _cage_amount)
		_main.set("money", _money() + _cage_amount)
		_toast("チップ %d を €$%d に換金した" % [_cage_amount, _cage_amount])
		_refresh_cage(vb)
		_refresh_bal(vb))
	row2.add_child(sell)
	var sell_all := _mk_button("全額換金", CpUi.CYAN, 140)
	sell_all.pressed.connect(func() -> void:
		if _chips() <= 0:
			_toast("換金できるチップがない")
			return
		_main.set("money", _money() + _chips())
		_main.set("chips", 0)
		_toast("チップを全額換金した")
		_refresh_cage(vb)
		_refresh_bal(vb))
	row2.add_child(sell_all)
	vb.add_child(row2)
	if _chips() <= 0 and _money() < 100:
		vb.add_child(_mk_label("手持ちが尽きた… 街のJOBキオスクで仕事をすれば €$を稼げる。", 20, PINK))
	var close := _mk_button("閉じる", CpUi.CYAN_DIM, 140)
	close.pressed.connect(_close_panel)
	vb.add_child(close)
	_refresh_cage(vb)

func _refresh_cage(vb: VBoxContainer) -> void:
	var info: Label = vb.find_child("CageInfo", true, false) as Label
	if info != null:
		info.text = "レート: €$1 = 1 CHIP\n所持金 €$%d ／ チップ %d" % [_money(), _chips()]
	var amt: Label = vb.find_child("CageAmount", true, false) as Label
	if amt != null:
		amt.text = "選択中: %d チップ" % _cage_amount

func _open_info() -> void:
	var vb := _open_panel("インフォメーション", Vector2(640, 520))
	var txt := """ようこそ CASINO NEON PEARL へ。

■ チップ: 入口脇のキャッシャー（CASHIER）で €$ をチップに交換します（€$1 = 1チップ）。換金も同じ窓口で。
■ ブラックジャック: 中央ピットの卓。6デッキ、BJ配当 3:2、スプリット/ダブル/インシュランス対応。
■ ルーレット: ピット中央の2卓。ヨーロピアン（シングルゼロ）で全ベット種が使えます。
■ ポーカー: 奥のガラス室。テキサスホールデム、バイイン 2,500、ブラインド 25/50。
■ VIPサロン: 北東の区画は NEON CIRCLE GOLD ランク（累計ベット €$1,000,000）で解放。高額卓と専用キャッシャーがあります。
■ NEON CIRCLE: 総ベット €$100 ごとに 1pt。SILVER（1,000pt）/ GOLD（10,000pt）。
お金に困ったら街のJOBキオスクへ。カジノは借金を取り扱いません。"""
	vb.add_child(_mk_label(txt, 20, CpUi.ICY))
	var close := _mk_button("閉じる", CpUi.CYAN_DIM, 140)
	close.pressed.connect(_close_panel)
	vb.add_child(close)

func _open_circle() -> void:
	var vb := _open_panel("NEON CIRCLE", Vector2(520, 400))
	var p: int = _points()
	var next_txt: String = "最高ランクです"
	if p < 1000:
		next_txt = "SILVER まで あと %d pt" % (1000 - p)
	elif p < 10000:
		next_txt = "GOLD（VIP解放）まで あと %d pt" % (10000 - p)
	vb.add_child(_mk_label("ランク: %s\nポイント: %d pt（累計ベット €$%d）\n%s" % [
		_rank(), p, int(_main.get("casino_stats")["total_bet"]), next_txt], 24, CpUi.ICY))
	vb.add_child(_mk_label("GOLD で VIPサロン（高額卓・専用キャッシャー）が解放されます。ポイントに現金価値はありません。", 19, CpUi.CYAN))
	var close := _mk_button("閉じる", CpUi.CYAN_DIM, 140)
	close.pressed.connect(_close_panel)
	vb.add_child(close)

func _open_slot() -> void:
	var vb := _open_panel("NEON SLOTS", Vector2(480, 430))
	vb.add_child(_mk_label("1回 25 チップ — 777 で 2,500！", 20, CpUi.CYAN))
	var reels := HBoxContainer.new()
	reels.alignment = BoxContainer.ALIGNMENT_CENTER
	reels.add_theme_constant_override("separation", 16)
	_slot_reels.clear()
	for i in range(3):
		var rl := _mk_label("7", 64, GOLD)
		rl.custom_minimum_size = Vector2(84, 96)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		reels.add_child(rl)
		_slot_reels.append(rl)
	vb.add_child(reels)
	var res := _mk_label("", 24, CpUi.ICY)
	res.name = "SlotResult"
	vb.add_child(res)
	var spin := _mk_button("SPIN", CpUi.YELLOW, 160)
	spin.pressed.connect(func() -> void:
		if _chips() < 25:
			_toast("チップが足りない — キャッシャーで購入しよう")
			return
		_main.set("chips", _chips() - 25)
		_track_bet(25)
		var syms: Array = ["7", "BAR", "★", "◆", "●", "▲"]
		var weights: Array = [1, 3, 4, 5, 6, 7]
		var got: Array = []
		for i in range(3):
			var tot: int = 0
			for w in weights:
				tot += int(w)
			var r: int = _rng.randi() % tot
			var acc: int = 0
			var pick: int = 0
			for j in range(weights.size()):
				acc += int(weights[j])
				if r < acc:
					pick = j
					break
			got.append(syms[pick])
			(_slot_reels[i] as Label).text = String(got[i])
		var pay: int = 0
		if got[0] == got[1] and got[1] == got[2]:
			pay = {"7": 2500, "BAR": 500, "★": 300, "◆": 150, "●": 100, "▲": 80}[String(got[0])]
		elif (got.count("7") == 2):
			pay = 50
		if pay > 0:
			_main.set("chips", _chips() + pay)
			_track_return(pay)
			(res as Label).text = "当たり！ +%d チップ" % pay
		else:
			(res as Label).text = "はずれ…"
		_refresh_bal(vb))
	vb.add_child(spin)
	vb.add_child(_mk_label("配当: 777=2500 / BAR=500 / ★=300 / ◆=150 / ●=100 / ▲=80 / 7が2つ=50", 17, CpUi.CYAN))
	var close := _mk_button("閉じる", CpUi.CYAN_DIM, 140)
	close.pressed.connect(_close_panel)
	vb.add_child(close)

# --- blackjack -------------------------------------------------------------

func _open_bj() -> void:
	_bj = null
	_bj_settled = true
	if _bj_bet < int(_seated["min_bet"]):
		_bj_bet = int(_seated["min_bet"])
	_render_bj()

func _bj_total_text(cards: Array) -> String:
	if cards.is_empty():
		return ""
	var v: Dictionary = BJL.hand_value(cards)
	if bool(v["is_blackjack"]):
		return "BLACKJACK"
	if bool(v["is_bust"]):
		return "%d バースト" % int(v["total"])
	if bool(v["soft"]) and int(v["total"]) < 21:
		return "%d/%d" % [int(v["total"]) - 10, int(v["total"])]
	return str(int(v["total"]))

func _render_bj() -> void:
	var vb := _open_panel("ブラックジャック（ミニマム %d）" % int(_seated["min_bet"]), Vector2(700, 560))
	# dealer row
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 6)
	drow.add_child(_mk_label("ディーラー", 22, PINK))
	var dtotal: String = ""
	if _bj != null:
		var dc: Array = _bj.get("dealer_cards")
		var hide_hole: bool = String(_bj.get("phase")) == "player" or String(_bj.get("phase")) == "insurance"
		var shown: int = dc.size()
		if hide_hole:
			shown = 1
		elif not _bj_settled and _bj_reveal_left() > 0:
			shown = dc.size() - _bj_reveal_left()
		for i in range(shown):
			drow.add_child(_card_rect(int(dc[i]), false, 54))
		if hide_hole and dc.size() > 1:
			drow.add_child(_card_rect(0, true, 54))
		if not hide_hole:
			dtotal = _bj_total_text(dc)
	else:
		drow.add_child(_mk_label("ベットして「配る」を押してください", 20, CpUi.CYAN))
	drow.add_child(_mk_label(dtotal, 24, GOLD))
	vb.add_child(drow)
	# player hands
	var status := ""
	if _bj != null:
		var hands: Array = _bj.get("player_hands")
		for hi in range(hands.size()):
			var h: Dictionary = hands[hi]
			var hrow := HBoxContainer.new()
			hrow.add_theme_constant_override("separation", 6)
			var mark: String = "▶ " if hi == int(_bj.get("active_hand")) and String(_bj.get("phase")) == "player" else ""
			hrow.add_child(_mk_label("%s手 %d（ベット %d）" % [mark, hi + 1, int(h["bet"])], 20, CpUi.ICY))
			for c in h["cards"]:
				hrow.add_child(_card_rect(int(c), false, 54))
			hrow.add_child(_mk_label(_bj_total_text(h["cards"]), 22, GOLD))
			vb.add_child(hrow)
	var st := _mk_label("", 23, CpUi.ICY)
	st.name = "BjStatus"
	vb.add_child(st)
	# controls by phase
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 8)
	vb.add_child(crow)
	var phase: String = "bet" if _bj == null else String(_bj.get("phase"))
	if _bj != null and not _bj_settled and phase == "done":
		phase = "reveal"
	match phase:
		"bet":
			st.text = "ベット額: %d チップ" % _bj_bet
			for d in [25, 100, 500, 1000]:
				var db := _mk_button("+%d" % d, CpUi.CYAN, 92)
				db.pressed.connect(func() -> void:
					_bj_bet += d
					_render_bj())
				crow.add_child(db)
			var clr := _mk_button("クリア", CpUi.CYAN_DIM, 96)
			clr.pressed.connect(func() -> void:
				_bj_bet = 0
				_render_bj())
			crow.add_child(clr)
			var deal := _mk_button("配る", CpUi.YELLOW, 120)
			deal.pressed.connect(_bj_deal)
			crow.add_child(deal)
		"insurance":
			var ins_amt: int = _bj_bet / 2
			st.text = "ディーラーのアップカードは A — インシュランス（%d チップ、配当2:1）を買いますか？" % ins_amt
			var yes := _mk_button("買う", CpUi.YELLOW, 120)
			yes.pressed.connect(func() -> void:
				if _chips() < ins_amt:
					_toast("チップが足りない")
					return
				_main.set("chips", _chips() - ins_amt)
				_track_bet(ins_amt)
				_bj.call("take_insurance", ins_amt)
				_bj_after_action())
			crow.add_child(yes)
			var no := _mk_button("買わない", CpUi.CYAN, 120)
			no.pressed.connect(func() -> void:
				_bj.call("decline_insurance")
				_bj_after_action())
			crow.add_child(no)
		"player":
			st.text = "あなたの番です"
			var hit := _mk_button("HIT", CpUi.YELLOW, 110)
			hit.disabled = not bool(_bj.call("can_hit"))
			hit.pressed.connect(func() -> void:
				_bj.call("hit")
				_bj_after_action())
			crow.add_child(hit)
			var stand := _mk_button("STAND", CpUi.CYAN, 110)
			stand.disabled = not bool(_bj.call("can_stand"))
			stand.pressed.connect(func() -> void:
				_bj.call("stand")
				_bj_after_action())
			crow.add_child(stand)
			var dbl := _mk_button("DOUBLE", CpUi.CYAN, 120)
			dbl.disabled = not bool(_bj.call("can_double"))
			dbl.pressed.connect(func() -> void:
				var h: Dictionary = (_bj.get("player_hands") as Array)[int(_bj.get("active_hand"))]
				var need: int = int(h["bet"])
				if _chips() < need:
					_toast("ダブルに必要なチップが足りない")
					return
				_main.set("chips", _chips() - need)
				_track_bet(need)
				_bj.call("double_down")
				_bj_after_action())
			crow.add_child(dbl)
			var spl := _mk_button("SPLIT", CpUi.CYAN, 110)
			spl.disabled = not bool(_bj.call("can_split"))
			spl.pressed.connect(func() -> void:
				var h2: Dictionary = (_bj.get("player_hands") as Array)[int(_bj.get("active_hand"))]
				var need2: int = int(h2["bet"])
				if _chips() < need2:
					_toast("スプリットに必要なチップが足りない")
					return
				_main.set("chips", _chips() - need2)
				_track_bet(need2)
				_bj.call("split_pair")
				_bj_after_action())
			crow.add_child(spl)
		"reveal":
			st.text = "ディーラーがカードを開いています…"
		"done":
			st.text = _bj_result_text()
			var again := _mk_button("もう一回", CpUi.YELLOW, 130)
			again.pressed.connect(func() -> void:
				_bj = null
				_bj_settled = true
				_render_bj())
			crow.add_child(again)
	var leave := _mk_button("離席", CpUi.RED, 100)
	leave.pressed.connect(func() -> void:
		if _bj != null and String(_bj.get("phase")) != "done":
			_toast("ハンドを放棄して離席した（ベットは没収）")
		_unseat())
	crow.add_child(leave)
	_refresh_bal(vb)

var _bj_reveal_count: int = 0

func _bj_reveal_left() -> int:
	return _bj_reveal_count

func _bj_deal() -> void:
	var min_b: int = int(_seated["min_bet"])
	if _bj_bet < min_b:
		_toast("ミニマムベットは %d チップ" % min_b)
		return
	if _bj_bet > _chips():
		_toast("チップが足りない")
		return
	if _bj_shoe == null or bool(_bj_shoe.call("needs_shuffle")):
		_bj_shoe = BJL.Shoe.new(_rng)
		_toast("新しいシューにシャッフルした（6デッキ）")
	_main.set("chips", _chips() - _bj_bet)
	_track_bet(_bj_bet)
	_bj = BJL.Session.new()
	_bj.call("start", _bj_bet, _bj_shoe)
	_bj_settled = false
	_bj_after_action()

func _bj_after_action() -> void:
	if _bj == null:
		return
	if String(_bj.get("phase")) == "done":
		# reveal the dealer's cards one beat at a time, then settle
		_bj_reveal_count = maxi(1, (_bj.get("dealer_cards") as Array).size() - 1)
		_bj_reveal.clear()
		for i in range(_bj_reveal_count):
			_bj_reveal.append(i)
		_bj_reveal_t = 0.45
	_render_bj()

func _bj_result_text() -> String:
	if _bj == null:
		return ""
	var parts: Array = []
	var res: Array = _bj.call("results")
	for i in range(res.size()):
		var r: Dictionary = res[i]
		var oc: String = {"blackjack": "ブラックジャック！", "win": "勝ち", "dealer_bust": "ディーラーがバースト — 勝ち",
			"lose": "負け", "bust": "バースト — 負け", "push": "プッシュ（引き分け）"}.get(String(r["outcome"]), String(r["outcome"]))
		parts.append("手%d: %s（戻し %d）" % [i + 1, oc, int(r["returned"])])
	var ins_bet: int = int(_bj.get("insurance_bet"))
	if ins_bet > 0:
		var dv: Dictionary = BJL.hand_value(_bj.get("dealer_cards"))
		if bool(dv["is_blackjack"]):
			parts.append("インシュランス的中（戻し %d）" % (ins_bet * 3))
		else:
			parts.append("インシュランスは外れ")
	return " ／ ".join(parts)

func _settle_bj() -> void:
	if _bj == null or _bj_settled:
		return
	_bj_settled = true
	var total: int = int(_bj.call("total_returned"))
	if total > 0:
		_main.set("chips", _chips() + total)
		_track_return(total)
	_show_banner("ブラックジャック 戻し %d チップ" % total if total > 0 else "ブラックジャック — ディーラーの勝ち", 2.6)
	_render_bj()

# --- roulette ---------------------------------------------------------------

var _roul_result: String = ""

func _open_roulette() -> void:
	_roul_bets.clear()
	_roul_first = -1
	_roul_result = ""
	_render_roulette()

func _roul_key(b: Dictionary) -> String:
	var ns: Array = (b["numbers"] as Array).duplicate()
	ns.sort()
	return "%s|%d" % [",".join(ns.map(func(x: Variant) -> String: return str(x))), int(b["payout"])]

func _roul_total() -> int:
	var t: int = 0
	for b in _roul_bets:
		t += int(b["amount"])
	return t

func _roul_add(bet: Dictionary) -> void:
	if _roul_total() + _roul_denom > _chips():
		_toast("チップが足りない")
		return
	var key: String = _roul_key(bet)
	for b in _roul_bets:
		if _roul_key(b) == key:
			b["amount"] = int(b["amount"]) + _roul_denom
			_render_roulette()
			return
	bet["amount"] = _roul_denom
	_roul_bets.append(bet)
	_render_roulette()

func _roul_adjacent(a: int, b: int) -> bool:
	if a == b:
		return false
	if a == 0:
		return b >= 1 and b <= 3
	if b == 0:
		return a >= 1 and a <= 3
	var ca: int = (a - 1) / 3
	var ra: int = (a - 1) % 3
	var cb: int = (b - 1) / 3
	var rb: int = (b - 1) % 3
	return (ca == cb and absi(ra - rb) == 1) or (ra == rb and absi(ca - cb) == 1)

func _roul_tap(n: int) -> void:
	match _roul_mode:
		"straight":
			_roul_add(ROL.straight(n))
		"split":
			if _roul_first < 0:
				_roul_first = n
				_toast("スプリット: 隣の数字をもう1つタップ")
				_render_roulette()
			else:
				if _roul_adjacent(_roul_first, n):
					_roul_add(ROL.split(_roul_first, n))
				else:
					_toast("隣り合った数字のペアだけスプリットできる")
				_roul_first = -1
		"street":
			if n == 0:
				_toast("0 にストリートはない")
				return
			_roul_add(ROL.street(((n - 1) / 3) * 3 + 1))
		"corner":
			if n == 0:
				_toast("0 にコーナーはない")
				return
			var ac: int = mini((n - 1) / 3, 10)
			var ar: int = mini((n - 1) % 3, 1)
			_roul_add(ROL.corner(ac * 3 + ar + 1))
		"sixline":
			if n == 0:
				_toast("0 にラインはない")
				return
			_roul_add(ROL.sixline(mini((n - 1) / 3, 10) * 3 + 1))

func _num_button(n: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(42, 46)
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color.WHITE)
	var col: Color = Color(0.04, 0.3, 0.1) if n == 0 else (Color(0.5, 0.04, 0.07) if ROL.color_of(n) == 1 else Color(0.05, 0.05, 0.08))
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.border_color = Color(0.9, 0.9, 0.9, 0.55)
	sb.set_border_width_all(1)
	b.add_theme_stylebox_override("normal", sb)
	var sb2 := sb.duplicate() as StyleBoxFlat
	sb2.bg_color = col.lightened(0.35)
	b.add_theme_stylebox_override("hover", sb2)
	b.add_theme_stylebox_override("pressed", sb2)
	var amt: int = 0
	for bet in _roul_bets:
		if (bet["numbers"] as Array) == [n]:
			amt = int(bet["amount"])
	b.text = str(n) if amt == 0 else "%d\n%d" % [n, amt]
	if _roul_first == n:
		b.modulate = Color(1.6, 1.6, 0.8)
	b.pressed.connect(func() -> void: _roul_tap(n))
	return b

func _render_roulette() -> void:
	var vb := _open_panel("ルーレット（ミニマム %d）" % int(_seated["min_bet"]), Vector2(780, 620), true)
	vb.add_theme_constant_override("separation", 6)
	if _roul_result != "":
		vb.add_child(_mk_label(_roul_result, 22, GOLD))
	# bet-type mode row
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 6)
	for mode_pair in [["straight", "ストレート"], ["split", "スプリット"], ["street", "ストリート"], ["corner", "コーナー"], ["sixline", "ライン"]]:
		var mb := _mk_button(mode_pair[1], CpUi.YELLOW if _roul_mode == mode_pair[0] else CpUi.CYAN, 108)
		var mv: String = mode_pair[0]
		mb.pressed.connect(func() -> void:
			_roul_mode = mv
			_roul_first = -1
			_render_roulette())
		mrow.add_child(mb)
	vb.add_child(mrow)
	# number grid: [0] + 12x3 + column bets
	var grid_row := HBoxContainer.new()
	grid_row.add_theme_constant_override("separation", 4)
	var zero := _num_button(0)
	zero.custom_minimum_size = Vector2(42, 146)
	grid_row.add_child(zero)
	var grid := GridContainer.new()
	grid.columns = 12
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for row in range(3):
		for col in range(12):
			grid.add_child(_num_button(col * 3 + row + 1))
	grid_row.add_child(grid)
	var colbox := VBoxContainer.new()
	colbox.add_theme_constant_override("separation", 4)
	for ci in [2, 1, 0]:
		var cb := _mk_button("2:1", CpUi.CYAN, 52)
		cb.custom_minimum_size = Vector2(52, 46)
		var civ: int = ci
		cb.pressed.connect(func() -> void: _roul_add(ROL.column(civ)))
		colbox.add_child(cb)
	grid_row.add_child(colbox)
	vb.add_child(grid_row)
	# dozens + even-money
	var drow2 := HBoxContainer.new()
	drow2.add_theme_constant_override("separation", 4)
	for di2 in range(3):
		var db2 := _mk_button(["1st 12", "2nd 12", "3rd 12"][di2], CpUi.CYAN, 120)
		var dv: int = di2
		db2.pressed.connect(func() -> void: _roul_add(ROL.dozen(dv)))
		drow2.add_child(db2)
	vb.add_child(drow2)
	var erow := HBoxContainer.new()
	erow.add_theme_constant_override("separation", 4)
	var evens: Array = [["1-18", ROL.low()], ["EVEN", ROL.even()], ["RED", ROL.red()], ["BLACK", ROL.black()], ["ODD", ROL.odd()], ["19-36", ROL.high()]]
	for ep in evens:
		var eb := _mk_button(String(ep[0]), CpUi.CYAN, 104)
		var ev: Dictionary = ep[1]
		eb.pressed.connect(func() -> void: _roul_add(ev))
		erow.add_child(eb)
	vb.add_child(erow)
	# denom row
	var denrow := HBoxContainer.new()
	denrow.add_theme_constant_override("separation", 6)
	denrow.add_child(_mk_label("チップ:", 20, CpUi.ICY))
	for d in [25, 100, 500, 1000, 5000]:
		var db3 := _mk_button(str(d), CpUi.YELLOW if _roul_denom == d else CpUi.CYAN_DIM, 84)
		var dvv: int = d
		db3.pressed.connect(func() -> void:
			_roul_denom = dvv
			_render_roulette())
		denrow.add_child(db3)
	vb.add_child(denrow)
	# summary + actions
	var parts: Array = []
	for b in _roul_bets:
		parts.append("%s:%d" % [String(b["label"]), int(b["amount"])])
	vb.add_child(_mk_label("ベット: %s" % ("、".join(parts) if not parts.is_empty() else "なし"), 19, CpUi.ICY))
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 8)
	arow.add_child(_mk_label("合計 %d" % _roul_total(), 24, GOLD))
	var clr := _mk_button("クリア", CpUi.CYAN_DIM, 100)
	clr.pressed.connect(func() -> void:
		_roul_bets.clear()
		_render_roulette())
	arow.add_child(clr)
	var rep := _mk_button("リピート", CpUi.CYAN, 110)
	rep.pressed.connect(func() -> void:
		if _roul_last.is_empty():
			_toast("前回のベットがない")
			return
		var tot: int = 0
		for b in _roul_last:
			tot += int(b["amount"])
		if tot > _chips():
			_toast("チップが足りない")
			return
		_roul_bets.clear()
		for b in _roul_last:
			_roul_bets.append((b as Dictionary).duplicate())
		_render_roulette())
	arow.add_child(rep)
	var spin := _mk_button("SPIN", CpUi.YELLOW, 120)
	spin.pressed.connect(_roul_spin)
	arow.add_child(spin)
	var leave := _mk_button("離席", CpUi.RED, 100)
	leave.pressed.connect(_unseat)
	arow.add_child(leave)
	(vb.get_meta("actions_parent") as VBoxContainer).add_child(arow)
	_refresh_bal(vb)

func _roul_spin() -> void:
	var total: int = _roul_total()
	if total < int(_seated["min_bet"]):
		_toast("ミニマムベットは %d チップ" % int(_seated["min_bet"]))
		return
	if total > _chips():
		_toast("チップが足りない")
		return
	if not _seated.has("wheel"):
		_toast("ホイールが見つからない")
		return
	_main.set("chips", _chips() - total)
	_track_bet(total)
	_roul_last.clear()
	for b in _roul_bets:
		_roul_last.append((b as Dictionary).duplicate())
	var winfo: Dictionary = _seated["wheel"]
	var pivot: Node3D = winfo["pivot"]
	var pocket: int = ROL.spin(_rng)
	var idx: int = ROL.WHEEL_ORDER.find(pocket)
	var w0: float = pivot.rotation.y
	var w1: float = w0 + 4.0 * TAU + _rng.randf() * TAU
	var phi: float = POCKET_BASE + float(idx) * POCKET_STEP
	var a0: float = _rng.randf() * TAU
	var base: float = phi - w1
	var k: float = round((a0 - 5.0 * TAU - base) / TAU)
	_spin = {"pivot": pivot, "center": winfo["center"], "t": 0.0, "dur": 5.4,
		"w0": w0, "w1": w1, "a0": a0, "a1": base + k * TAU, "pocket": pocket}
	_ball.visible = true
	_close_panel()
	_show_banner("Rien ne va plus — 回転中…", 2.0)

func _tick_spin(delta: float) -> void:
	var pivot: Node3D = _spin["pivot"]
	var center: Vector3 = _spin["center"]
	_spin["t"] = float(_spin["t"]) + delta
	var u: float = clampf(float(_spin["t"]) / float(_spin["dur"]), 0.0, 1.0)
	var w0: float = float(_spin["w0"])
	var w1: float = float(_spin["w1"])
	pivot.rotation.y = w0 + (w1 - w0) * (1.0 - pow(1.0 - u, 3.0))
	var a0: float = float(_spin["a0"])
	var a1: float = float(_spin["a1"])
	var ang: float = a1 + (a0 - a1) * pow(1.0 - u, 2.0)
	var r: float = BALL_R_OUT
	if u > 0.5:
		var s: float = clampf((u - 0.5) / 0.45, 0.0, 1.0)
		s = s * s * (3.0 - 2.0 * s)
		r = lerpf(BALL_R_OUT, BALL_R_IN, s)
	_ball.global_position = center + Vector3(cos(ang), 0, sin(ang)) * r + Vector3(0, 0.055 * (1.0 - u), 0)
	if u >= 1.0:
		var pocket: int = int(_spin["pocket"])
		_spin.clear()
		var res: Dictionary = ROL.settle(_roul_bets, pocket)
		var ret: int = int(res["total_return"])
		if ret > 0:
			_main.set("chips", _chips() + ret)
			_track_return(ret)
		var cname: String = "緑" if pocket == 0 else ("赤" if ROL.color_of(pocket) == 1 else "黒")
		var net: int = ret - int(res["total_bet"])
		_roul_result = "結果: %d（%s） — 戻し %d（損益 %+d）" % [pocket, cname, ret, net]
		_show_banner(_roul_result, 3.4)
		_roul_bets.clear()
		_render_roulette()

# --- poker (Texas hold'em vs CPU) -------------------------------------------

const PK_NAMES: Array = [["ミカ", 1], ["レン", 0], ["ゴウ", 2], ["サラ", 0], ["ジン", 1]]
var _pk_last_action: Dictionary = {}
var _pk_msg: String = ""
var _pk_raise_to: int = 0

func _open_poker() -> void:
	_main.set("chips", _chips() - 2500)
	_track_bet(0)  # buy-in is a transfer, not a bet
	var players: Array = []
	players.append({"name": "YOU", "stack": 2500, "is_cpu": false, "personality": 2})
	for np in PK_NAMES:
		players.append({"name": String(np[0]), "stack": 2500, "is_cpu": true, "personality": int(np[1])})
	_pk = PKL.Game.new()
	_pk.call("setup", players, _rng.randi() % 6, _rng)
	_pk_last_action.clear()
	_pk_msg = "バイイン 2,500 — ハンド開始"
	_pk.call("start_hand")
	_pk_phase = "play"
	_pk_wait = 0.6
	_render_poker()

func _pk_players() -> Array:
	return _pk.get("players")

func _poker_step() -> void:
	if _pk == null or _pk_phase != "play":
		return
	if bool(_pk.call("is_hand_over")):
		_poker_finish_hand()
		return
	var actor: int = int(_pk.call("current_actor"))
	if actor < 0:
		_render_poker()
		return
	if actor == 0:
		_render_poker()
		return
	var dec: Dictionary = PKL.ai_decide(_pk, actor)
	var act: String = String(dec.get("action", "fold"))
	var amt: int = int(dec.get("amount", 0))
	_pk.call("apply_action", actor, act, amt)
	_pk_last_action[actor] = _pk_action_text(act, amt)
	_pk_msg = "%s: %s" % [String(_pk_players()[actor]["name"]), _pk_last_action[actor]]
	if bool(_pk.call("is_hand_over")):
		_poker_finish_hand()
		return
	_render_poker()

func _pk_action_text(act: String, amt: int) -> String:
	match act:
		"fold":
			return "フォールド"
		"check":
			return "チェック"
		"call":
			return "コール"
		"bet":
			return "ベット %d" % amt
		"raise":
			return "レイズ %d" % amt
		"allin":
			return "オールイン！"
	return act

func _poker_finish_hand() -> void:
	var res: Dictionary = _pk.call("showdown")
	var payouts: Dictionary = res.get("payouts", {})
	var lines: Array = []
	for seat in payouts:
		if int(payouts[seat]) > 0:
			lines.append("%s +%d" % [String(_pk_players()[int(seat)]["name"]), int(payouts[seat])])
	_pk_msg = "ショーダウン: " + ("、".join(lines) if not lines.is_empty() else "配当なし")
	_pk_phase = "showdown"
	_pk_show_t = 4.0
	_render_poker()

func _poker_next_hand_or_rebuy() -> void:
	if _pk == null:
		return
	var stack: int = _pk_player_stack()
	if stack < 500:
		_pk_phase = "rebuy"
		_render_poker()
		return
	_pk_last_action.clear()
	_pk.set("button", (int(_pk.get("button")) + 1) % 6)
	_pk.call("start_hand")
	_pk_phase = "play"
	_pk_wait = 0.6
	_pk_msg = "新しいハンド"
	_render_poker()

func _poker_player_act(act: String, amt: int = 0) -> void:
	if _pk == null or _pk_phase != "play":
		return
	if int(_pk.call("current_actor")) != 0:
		return
	if act == "raise":
		# with no bet yet this street the action is a "bet"
		var cur_bet: int = 0
		for p in _pk_players():
			cur_bet = maxi(cur_bet, int(p.get("committed_street", 0)))
		if cur_bet == 0:
			act = "bet"
	_pk.call("apply_action", 0, act, amt)
	_pk_last_action[0] = _pk_action_text(act, amt)
	_pk_wait = 0.55
	if bool(_pk.call("is_hand_over")):
		_poker_finish_hand()
		return
	_render_poker()

func _render_poker() -> void:
	if _pk == null:
		return
	var vb := _open_panel("テキサスホールデム（SB 25 / BB 50）", Vector2(840, 600))
	vb.add_theme_constant_override("separation", 6)
	var players: Array = _pk_players()
	# board + pot
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 6)
	brow.add_child(_mk_label("ボード", 20, PINK))
	var board: Array = _pk.get("board")
	for i in range(5):
		if i < board.size():
			brow.add_child(_card_rect(int(board[i]), false, 50))
		else:
			brow.add_child(_card_rect(0, true, 50))
	brow.add_child(_mk_label("ポット %d ／ %s" % [int(_pk.call("pot_total")), String(_pk.get("street"))], 22, GOLD))
	vb.add_child(brow)
	vb.add_child(_mk_label(_pk_msg, 21, CpUi.ICY))
	# CPU seats
	for seat in range(1, 6):
		var p: Dictionary = players[seat]
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 6)
		var state: String = "フォールド" if bool(p.get("folded", false)) else ("オールイン" if bool(p.get("allin", false)) else String(_pk_last_action.get(seat, "")))
		srow.add_child(_mk_label("%s（%d）%s" % [String(p["name"]), int(p["stack"]), " — " + state if state != "" else ""], 19, CpUi.ICY))
		if _pk_phase == "showdown" and not bool(p.get("folded", false)):
			for c in p.get("cards", []):
				srow.add_child(_card_rect(int(c), false, 36))
		vb.add_child(srow)
	# player
	var me: Dictionary = players[0]
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 6)
	prow.add_child(_mk_label("YOU（スタック %d）" % int(me["stack"]), 22, GOLD))
	for c in me.get("cards", []):
		prow.add_child(_card_rect(int(c), false, 58))
	if _pk_phase == "showdown" and not bool(me.get("folded", false)) and (me.get("cards") as Array).size() == 2:
		var all_cards: Array = (me["cards"] as Array).duplicate()
		all_cards.append_array(_pk.get("board"))
		if all_cards.size() == 7:
			prow.add_child(_mk_label(PKL.hand_name(PKL.evaluate(all_cards)), 22, PINK))
	vb.add_child(prow)
	# actions
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 8)
	vb.add_child(arow)
	if _pk_phase == "rebuy":
		var cost: int = 2500 - int(me["stack"])
		arow.add_child(_mk_label("スタック不足 — リバイ（%d チップで 2,500 に補充）？" % cost, 21, PINK))
		var rb := _mk_button("リバイ", CpUi.YELLOW, 120)
		rb.disabled = _chips() < cost
		rb.pressed.connect(func() -> void:
			_main.set("chips", _chips() - cost)
			me["stack"] = 2500
			_pk_last_action.clear()
			_pk.set("button", (int(_pk.get("button")) + 1) % 6)
			_pk.call("start_hand")
			_pk_phase = "play"
			_pk_wait = 0.6
			_pk_msg = "リバイ完了 — 新しいハンド"
			_render_poker())
		arow.add_child(rb)
	elif _pk_phase == "play" and int(_pk.call("current_actor")) == 0 and not bool(_pk.call("is_hand_over")):
		var legal: Dictionary = _pk.call("legal_actions")
		var fold := _mk_button("FOLD", CpUi.RED, 110)
		fold.pressed.connect(func() -> void: _poker_player_act("fold"))
		arow.add_child(fold)
		if bool(legal.get("can_check", false)):
			var chk := _mk_button("CHECK", CpUi.CYAN, 110)
			chk.pressed.connect(func() -> void: _poker_player_act("check"))
			arow.add_child(chk)
		else:
			var callb := _mk_button("CALL %d" % int(legal.get("call_amount", 0)), CpUi.YELLOW, 130)
			callb.pressed.connect(func() -> void: _poker_player_act("call"))
			arow.add_child(callb)
		var min_to: int = int(legal.get("min_raise_to", 0))
		var max_to: int = int(legal.get("max_raise_to", 0))
		if max_to > min_to:
			if _pk_raise_to < min_to or _pk_raise_to > max_to:
				_pk_raise_to = min_to
			var slider := HSlider.new()
			slider.min_value = min_to
			slider.max_value = max_to
			slider.step = 25
			slider.value = _pk_raise_to
			slider.custom_minimum_size = Vector2(300, 40)
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var amt_label := _mk_label("レイズ先 %d" % _pk_raise_to, 20, GOLD)
			amt_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			slider.value_changed.connect(func(v: float) -> void:
				_pk_raise_to = int(v)
				amt_label.text = "レイズ先 %d" % _pk_raise_to)
			var srow := HBoxContainer.new()
			srow.add_theme_constant_override("separation", 8)
			srow.add_child(slider)
			srow.add_child(amt_label)
			vb.add_child(srow)
			vb.move_child(srow, arow.get_index())
			var raiseb := _mk_button("RAISE", CpUi.YELLOW, 110)
			raiseb.pressed.connect(func() -> void: _poker_player_act("raise", _pk_raise_to))
			arow.add_child(raiseb)
		var allin := _mk_button("ALL-IN", CpUi.RED, 110)
		allin.pressed.connect(func() -> void: _poker_player_act("allin"))
		arow.add_child(allin)
	var leave := _mk_button("離席", CpUi.RED, 100)
	leave.pressed.connect(func() -> void:
		if _pk_phase == "play" and not bool(me.get("folded", false)) and not bool(_pk.call("is_hand_over")):
			_pk.call("apply_action", 0, "fold", 0)
		var back: int = _pk_player_stack()
		_main.set("chips", _chips() + back)
		_toast("ポーカー離席 — スタック %d をチップに戻した" % back)
		_unseat())
	arow.add_child(leave)
	_refresh_bal(vb)

