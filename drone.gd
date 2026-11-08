extends Node3D
## Police drone: hovers after the player when wanted. Contact hurts.

var target: Node3D = null
var active: bool = false
var _t: float = 0.0
var _light_a: MeshInstance3D
var _light_b: MeshInstance3D
var _mat_a: StandardMaterial3D
var _mat_b: StandardMaterial3D

func _ready() -> void:
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 0.3, 0.8)
	body.mesh = bm
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.05, 0.05, 0.09)
	dm.metallic = 0.5
	dm.roughness = 0.35
	body.material_override = dm
	add_child(body)
	_mat_a = _glow_mat(Color(1, 0.1, 0.15))
	_mat_b = _glow_mat(Color(0.2, 0.4, 1))
	_light_a = _orb(Vector3(-0.3, 0, 0.42), _mat_a)
	_light_b = _orb(Vector3(0.3, 0, 0.42), _mat_b)
	visible = false

func _glow_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 3.5
	return m

func _orb(pos: Vector3, mat: Material) -> MeshInstance3D:
	var o := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.09
	sp.height = 0.18
	o.mesh = sp
	o.position = pos
	o.material_override = mat
	add_child(o)
	return o

func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	var phase: bool = fmod(_t, 0.6) < 0.3
	_mat_a.emission_energy_multiplier = 4.0 if phase else 0.4
	_mat_b.emission_energy_multiplier = 0.4 if phase else 4.0
	if target == null:
		return
	var want: Vector3 = target.global_position + Vector3(0, 2.6, 0)
	var to: Vector3 = want - global_position
	var dist: float = to.length()
	if dist > 0.4:
		# Rubber-band: faster when far so pressure stays on, but a fast car
		# can still pull away and break the search.
		var spd: float = 11.5 if dist < 50.0 else minf(11.5 + (dist - 50.0) * 0.35, 30.0)
		var step: float = minf(dist, spd * delta)
		global_position += to.normalized() * step
	global_position.y += sin(_t * 3.0) * 0.15 * delta
	if to.length() > 0.5:
		look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP)
