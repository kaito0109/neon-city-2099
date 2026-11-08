extends Control
## North-up minimap: roads, player, mission target, cars, drones, kiosks.

var main: Node
var world_extent: float = 345.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _w2m(p: Vector3) -> Vector2:
	var s: float = size.x / (world_extent * 2.0)
	return Vector2((p.x + world_extent) * s, (p.z + world_extent) * s)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.06, 0.88))
	if main == null:
		return
	var city: Node = main.get("city")
	var player: Node = main.get("player")
	if city == null or player == null:
		return
	# Roads.
	var n: int = int(city.get("N"))
	var block: float = float(city.get("BLOCK"))
	for i in range(-n, n + 1):
		var c: float = i * block
		draw_line(_w2m(Vector3(-world_extent, 0, c)), _w2m(Vector3(world_extent, 0, c)), Color(0.25, 0.3, 0.45, 0.8), 1.0)
		draw_line(_w2m(Vector3(c, 0, -world_extent)), _w2m(Vector3(c, 0, world_extent)), Color(0.25, 0.3, 0.45, 0.8), 1.0)
	# Kiosks.
	for k in city.get("poi_kiosks"):
		draw_circle(_w2m(k), 2.0, Color(0.3, 0.9, 1.0))
	# Cars.
	for cnode in get_tree().get_nodes_in_group("cars"):
		draw_circle(_w2m((cnode as Node3D).global_position), 2.0, Color(0.75, 0.75, 0.8))
	# Drones.
	for d in get_tree().get_nodes_in_group("drones"):
		if bool(d.get("active")):
			draw_circle(_w2m((d as Node3D).global_position), 2.6, Color(1.0, 0.2, 0.25))
	# Mission target.
	var target: Variant = main.get("mission_target_pos")
	if target != null:
		var pulse: float = 3.2 + sin(Time.get_ticks_msec() * 0.008) * 0.9
		draw_circle(_w2m(target), pulse, Color(1.0, 0.85, 0.15))
	# Player arrow.
	var pp: Vector2 = _w2m((player as Node3D).global_position)
	# Player arrow. In-game forward is (-sin(a), -cos(a)) in world XZ for both
	# the walk yaw and the car heading; map X->right, Z->down.
	var a: float
	if (player as Node).get("in_car") != null:
		a = float(((player as Node).get("in_car") as Node).get("heading"))
	else:
		a = float((player as Node).get("yaw"))
	var dir := Vector2(-sin(a), -cos(a))
	var perp := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([pp + dir * 6.0, pp + perp * 3.6 - dir * 3.0, pp - perp * 3.6 - dir * 3.0])
	draw_colored_polygon(pts, Color(1, 1, 1))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.4, 0.9, 1.0, 0.5), false, 1.5)
