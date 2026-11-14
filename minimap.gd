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
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.004, 0.012, 0.022, 0.92))
	if main == null:
		return
	var city: Node = main.get("city")
	var player: Node = main.get("player")
	if city == null or player == null:
		return
	# Roads: v4 draws the authored network from the layout's line
	# list; the old procedural grid is the fallback.
	var ext_v: Variant = city.get("map_extent")
	if ext_v != null:
		world_extent = float(ext_v)
	var rl: Array = city.get("road_lines")
	if not rl.is_empty():
		for seg in rl:
			draw_line(_w2m(seg[0]), _w2m(seg[1]), Color(0.3, 0.55, 0.68, 0.9), 1.0)
	else:
		var n: int = int(city.get("N"))
		var block: float = float(city.get("BLOCK"))
		for i in range(-n, n + 1):
			var c: float = i * block
			draw_line(_w2m(Vector3(-world_extent, 0, c)), _w2m(Vector3(world_extent, 0, c)), Color(0.3, 0.55, 0.68, 0.9), 1.0)
			draw_line(_w2m(Vector3(c, 0, -world_extent)), _w2m(Vector3(c, 0, world_extent)), Color(0.3, 0.55, 0.68, 0.9), 1.0)
	# Kiosks: yellow diamonds (objective colour).
	for k in city.get("poi_kiosks"):
		var kp: Vector2 = _w2m(k)
		draw_colored_polygon(PackedVector2Array([
			kp + Vector2(0, -3.2), kp + Vector2(3.2, 0), kp + Vector2(0, 3.2), kp + Vector2(-3.2, 0)]),
			Color(0.99, 0.93, 0.04))
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
		var pulse: float = 4.4 + sin(Time.get_ticks_msec() * 0.008) * 1.1
		var tp: Vector2 = _w2m(target)
		draw_colored_polygon(PackedVector2Array([
			tp + Vector2(0, -pulse), tp + Vector2(pulse, 0), tp + Vector2(0, pulse), tp + Vector2(-pulse, 0)]),
			Color(1.0, 0.0, 0.235))
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
	var pts_big := PackedVector2Array([pp + dir * 7.4, pp + perp * 4.6 - dir * 3.8, pp - perp * 4.6 - dir * 3.8])
	draw_colored_polygon(pts_big, Color(0.0, 0.94, 1.0))
	draw_colored_polygon(pts, Color(1, 1, 1))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.94, 1.0, 0.55), false, 1.5)
	# Red corner tick, CP panel signature.
	draw_line(Vector2(0, 1), Vector2(size.x * 0.18, 1), Color(1.0, 0.0, 0.235), 3.0)
