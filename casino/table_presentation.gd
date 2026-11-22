extends Node3D
## Props belong to the occupied table and are rebuilt from the betting state.

var camera: Camera3D
var cards: Dictionary = {}
var chips: Node3D
var atlas: Texture2D
var _chip_template: Node3D

func setup(table: Dictionary, texture: Texture2D) -> void:
	atlas = texture
	global_position = table["table_pos"]
	camera = Camera3D.new()
	camera.fov = 55
	add_child(camera)
	camera.position = Vector3(0, 2.55, 1.85)
	camera.look_at(to_global(Vector3(0, 0.55, 0.52)))
	camera.make_current()
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.10, 2.75, 0.25)
	fill.light_color = Color(1.0, 0.86, 0.69)
	fill.light_energy = 1.35
	fill.omni_range = 4.0
	add_child(fill)
	chips = Node3D.new()
	add_child(chips)
	_chip_template = ModelLoader.load_model("res://assets/models/casino_chip.glb")
	if _chip_template != null:
		_chip_template.hide()
		add_child(_chip_template)

func focus_wheel(center: Vector3) -> void:
	camera.global_position = center + Vector3(0.17, 1.09, 0.61)
	camera.look_at(center)
	camera.fov = 49

func frame_table() -> void:
	camera.position = Vector3(0, 2.55, 1.85)
	camera.look_at(to_global(Vector3(0, 0.55, 0.52)))
	camera.fov = 55

func clear_cards() -> void:
	for entry in cards.values():
		entry["node"].queue_free()
	cards.clear()

func show_card(key: String, value: int, target: Vector3, delay: float) -> void:
	if atlas == null:
		return
	if cards.has(key):
		var entry: Dictionary = cards[key]
		var node: Sprite3D = entry["node"]
		if not (entry["target"] as Vector3).is_equal_approx(target):
			entry["target"] = target
			node.create_tween().tween_property(node, "position", target, 0.18)
		if entry["value"] != value:
			entry["value"] = value
			_flip(node, value, delay)
		return
	var node := Sprite3D.new()
	node.name = "Card_" + key
	node.texture = atlas
	node.region_enabled = true
	node.shaded = false
	node.rotation.x = -PI * 0.5
	node.pixel_size = 0.137 / (atlas.get_width() / 13.0)
	node.position = Vector3(0.85, 0.96, -0.25)
	node.hide()
	_set_face(node, -1)
	add_child(node)
	cards[key] = {"node": node, "value": value, "target": target}
	var tween := node.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(node.show)
	tween.tween_property(node, "position", target + Vector3(0, 0.075, 0), 0.17).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "position", target, 0.10)
	if value >= 0:
		_flip(node, value, delay + 0.25)

func _flip(node: Sprite3D, value: int, delay: float) -> void:
	var tween := node.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(node, "rotation:x", 0.0, 0.11)
	tween.tween_callback(_set_face.bind(node, value))
	tween.tween_property(node, "rotation:x", -PI * 0.5, 0.12)

func _set_face(node: Sprite3D, value: int) -> void:
	var cell := atlas.get_size() / Vector2(13, 5)
	var column := 0 if value < 0 else value % 13
	var row := 4 if value < 0 else floori(float(value) / 13)
	node.region_rect = Rect2(Vector2(column, row) * cell + Vector2.ONE, cell - Vector2.ONE * 2.0)

func clear_chips() -> void:
	for chip in chips.get_children():
		chips.remove_child(chip)
		chip.queue_free()

func place_stack(at: Vector3, value: int) -> void:
	if value <= 0:
		return
	var count := clampi(ceili(float(value) / 25.0), 1, 7)
	for idx in range(count):
		var token: Node3D
		if _chip_template != null:
			token = _chip_template.duplicate()
			token.show()
		else:
			var disk := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.02
			cylinder.bottom_radius = 0.02
			cylinder.height = 0.004
			disk.mesh = cylinder
			token = disk
		token.scale = Vector3.ONE * 1.65
		chips.add_child(token)
		token.position = at + Vector3(0, idx * 0.007, 0)
