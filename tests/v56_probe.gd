extends SceneTree
## Probe: does the terrain mesh AS LOADED BY THE GAME contain the
## v5.6 zebra bars? Counts vertices at the bar corners of the
## (0, 44) crossing and prints each surface's material + AABB.
var frames: int = 0
var main: Node

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 15:
		var city: Node = main.get("city")
		var found: Node = city.find_child("TerrainV4", true, false)
		print("find_child TerrainV4: ", found)
		var terr: Node = found
		print("terrain node: ", terr)
		var mi := terr as MeshInstance3D
		var mesh := mi.mesh
		print("surfaces: ", mesh.get_surface_count())
		var bar_verts: int = 0
		var cap_verts: int = 0
		for s in range(mesh.get_surface_count()):
			var arr := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var mat: Material = mesh.surface_get_material(s)
			print("surface ", s, " mat=", mat.resource_name if mat else "?",
					" verts=", verts.size())
			for v in verts:
				if absf(v.x) > 6.4 and absf(v.x) < 7.6 and v.y > 0.05 \
						and v.y < 0.13 and v.z > 41.0 and v.z < 47.0:
					bar_verts += 1
				# terrace cap lip: verts at h+0.03 near the 6 m edge
				if absf(v.y - 6.03) < 0.02 and v.z > -80.0 and v.z < -70.0 \
						and v.x > 60.0 and v.x < 80.0:
					cap_verts += 1
		print("BAR corner verts found: ", bar_verts, " (expect 20)")
		print("CAP lip verts found: ", cap_verts, " (expect >0)")
		print("PROBE DONE")
		quit()
	return false
