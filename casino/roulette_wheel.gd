extends RefCounted
## Coordinates match build_casino.py: Blender -Y becomes Godot +Z.
const RULES := preload("res://casino/roulette_logic.gd")
const STEP := TAU / 37.0
const POCKET_RADIUS := 0.252
const POCKET_HEIGHT := 0.094
const BALL_RADIUS := 0.014

static func result_at(wheel: Node3D, position: Vector3) -> int:
	var local := wheel.to_local(position)
	var index := posmod(roundi(atan2(local.z, local.x) / STEP), RULES.WHEEL_ORDER.size())
	return RULES.WHEEL_ORDER[index]

static func add_numbers(wheel: Node3D) -> void:
	if wheel.has_node("PocketNumbers"):
		return
	var numbers := Node3D.new()
	numbers.name = "PocketNumbers"
	wheel.add_child(numbers)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(RULES.WHEEL_ORDER.size()):
		var number: int = RULES.WHEEL_ORDER[index]
		var color := Color(0.39, 0.035, 0.045) if RULES.color_of(number) == 1 else Color(0.035, 0.04, 0.055)
		if number == 0:
			color = Color(0.018, 0.32, 0.17)
		var start := index * STEP - STEP * 0.485
		var finish := index * STEP + STEP * 0.485
		var points := [
			Vector3(cos(start) * 0.305, 0.136, sin(start) * 0.305),
			Vector3(cos(start) * 0.351, 0.136, sin(start) * 0.351),
			Vector3(cos(finish) * 0.351, 0.136, sin(finish) * 0.351),
			Vector3(cos(finish) * 0.305, 0.136, sin(finish) * 0.305),
		]
		for corner in [0, 1, 2, 0, 2, 3]:
			surface.set_color(color)
			surface.add_vertex(points[corner])
	var backing := MeshInstance3D.new()
	backing.mesh = surface.commit()
	var ink := StandardMaterial3D.new()
	ink.vertex_color_use_as_albedo = true
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	backing.material_override = ink
	numbers.add_child(backing)
	for index in range(RULES.WHEEL_ORDER.size()):
		var angle := index * STEP
		var radial := Vector3(cos(angle), 0, sin(angle))
		var label := Label3D.new()
		label.text = str(RULES.WHEEL_ORDER[index])
		label.font_size = 48
		label.pixel_size = 0.00057
		label.outline_size = 7
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		numbers.add_child(label)
		label.basis = Basis(radial.cross(Vector3.UP), radial, Vector3.UP)
		label.position = radial * 0.33 + Vector3.UP * 0.138
