extends SceneTree
## v5.8 probe: the visual ground grid in the terrace quadrant must
## be the SAME surface as the collision patch — same 2 m lattice,
## same heights (+0.02 paint lift), same triangulation. Vertex
## check: every mesh vertex that sits on the collision lattice in
## the quadrant must match _terrain_height + 0.02, and (nearly)
## every lattice point must be present in the mesh.
var frames: int = 0
var main: Node

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames < 30:
		return false
	var city: Node = main.get("city")
	var best_mesh: Mesh = null
	var best_xf: Transform3D = Transform3D.IDENTITY
	var stack: Array = [city]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for ch in nd.get_children():
			stack.append(ch)
		if nd is MeshInstance3D:
			var mi := nd as MeshInstance3D
			if mi.mesh != null and mi.mesh.get_surface_count() > 0:
				var arr: Array = mi.mesh.surface_get_arrays(0)
				if (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 15000:
					best_mesh = mi.mesh
					best_xf = mi.global_transform
					print("terrain xf origin=", best_xf.origin, " basis=", best_xf.basis)
	if best_mesh == null:
		print("V58 FAIL no terrain mesh found")
		quit()
		return false
	print("terrain xf origin=", best_xf.origin, " sx=", best_xf.basis.x.length(),
			" sy=", best_xf.basis.y.length(), " sz=", best_xf.basis.z.length())
	for s in range(best_mesh.get_surface_count()):
		var m2: Material = best_mesh.surface_get_material(s)
		var a2: Array = best_mesh.surface_get_arrays(s)
		print("  surface ", s, " mat=", (m2.resource_name if m2 != null else "?"),
				" verts=", (a2[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	var seen: Dictionary = {}
	var worst: float = 0.0
	var checked: int = 0
	for s in range(best_mesh.get_surface_count()):
		var mat: Material = best_mesh.surface_get_material(s)
		var mname: String = mat.resource_name if mat != null else ""
		if mname != "BankMat" and mname != "GroundMat":
			continue
		var arr: Array = best_mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for v0 in verts:
			var v: Vector3 = best_xf * v0
			if v.x < 43.9 or v.x > 244.1 or v.z < -244.1 or v.z > -51.9:
				continue
			var lx: float = (v.x - 44.0) / 2.0
			var lz: float = (v.z + 244.0) / 2.0
			if absf(lx - roundf(lx)) > 0.01 or absf(lz - roundf(lz)) > 0.01:
				continue
			var key: String = str(int(roundf(lx))) + "," + str(int(roundf(lz)))
			seen[key] = true
			# Compare at the AUTHORED lattice point (the import shifts
			# vertices by a few mm; on a 5:1 riser that alone reads as
			# ~3 cm of height difference at the shifted position).
			var ax: float = 44.0 + roundf(lx) * 2.0
			var az: float = -244.0 + roundf(lz) * 2.0
			var expect: float = float(city.call("_terrain_height", ax, az)) + 0.02
			if absf(v.y - expect) > worst:
				worst = absf(v.y - expect)
				print("  worst at ", v, " expect ", snappedf(expect, 0.001))
			checked += 1
	print("V58 lattice verts checked: ", checked, " unique: ", seen.size(),
			" worst |dy|: ", snappedf(worst, 0.0001))
	if seen.size() < 9500:
		print("V58 FAIL lattice coverage too low")
	elif worst > 0.03:
		print("V58 FAIL visual grid deviates from collision")
	else:
		print("V58 PASS visual grid == collision surface")
	quit()
	return false
