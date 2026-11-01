class_name ArchBuilder
extends RefCounted
## ARCH BUILDER -- builds the dirt "collar" of an opening in the cave wall:
## an arch-shaped passage (flat floor, straight sides, round top) with a
## thick frame around its mouth, as one flat-shaded mesh plus a matching
## collision shape.
##
## Used by the tunnel entrances and the jail cell. Local space: X right, Y
## up, -Z toward the middle of the cave, +Z into the wall. The mouth frame
## starts at z = -porch (sticking into the cave) and the passage runs to
## z = depth, where a pure black cap closes it.
##
##   build(parent, inner_half_width, inner_height, outer_half_width,
##         outer_height, porch, collar_depth, depth, color)
##
## Returns {"mesh": MeshInstance3D, "shape": ConcavePolygonShape3D,
##          "cap": MeshInstance3D}. The caller adds the shape to its body.

const OUTLINE_POINTS := 14   # points along one arch outline


## Points along an arch outline from the bottom-left, up, over the top and
## down to the bottom-right: straight sides to (height - half_width), then
## a semicircle. All with the same point count so outlines can be joined.
static func outline(half_width: float, height: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var straight := maxf(height - half_width, 0.0)
	var side_points := 2
	var arc_points := OUTLINE_POINTS - side_points * 2
	for i in side_points:
		points.append(Vector2(-half_width, straight * float(i) / side_points))
	for i in arc_points + 1:
		var a := PI - PI * float(i) / arc_points
		points.append(Vector2(cos(a) * half_width, straight + sin(a) * half_width))
	for i in range(side_points - 1, -1, -1):
		points.append(Vector2(half_width, straight * float(i) / side_points))
	return points


static func build(parent: Node3D, inner_half_width: float, inner_height: float,
		outer_half_width: float, outer_height: float, porch: float, collar_depth: float,
		depth: float, color: Color) -> Dictionary:
	var inner := outline(inner_half_width, inner_height)
	var outer := outline(outer_half_width, outer_height)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(inner_half_width * 100.0 + outer_height * 10.0)

	# Front face of the frame: the ring between the outer and inner outlines
	# at z = -porch (seen from the cave, so it faces -Z).
	for i in inner.size() - 1:
		var o0 := Vector3(outer[i].x, outer[i].y, -porch)
		var o1 := Vector3(outer[i + 1].x, outer[i + 1].y, -porch)
		var i0 := Vector3(inner[i].x, inner[i].y, -porch)
		var i1 := Vector3(inner[i + 1].x, inner[i + 1].y, -porch)
		_quad(vertices, normals, colors, o0, o1, i1, i0, Vector3.FORWARD, _tint(color, rng))
	# Outer skin of the frame, from the front face back into the wall.
	for i in outer.size() - 1:
		var a := Vector3(outer[i].x, outer[i].y, -porch)
		var b := Vector3(outer[i + 1].x, outer[i + 1].y, -porch)
		var c := Vector3(outer[i + 1].x, outer[i + 1].y, collar_depth)
		var d := Vector3(outer[i].x, outer[i].y, collar_depth)
		var out := _outward(outer[i], outer[i + 1])
		_quad(vertices, normals, colors, a, d, c, b, out, _tint(color, rng))
	# Inside of the passage: walls and ceiling, all the way to the cap.
	for i in inner.size() - 1:
		var a := Vector3(inner[i].x, inner[i].y, -porch)
		var b := Vector3(inner[i + 1].x, inner[i + 1].y, -porch)
		var c := Vector3(inner[i + 1].x, inner[i + 1].y, depth)
		var d := Vector3(inner[i].x, inner[i].y, depth)
		var inward := -_outward(inner[i], inner[i + 1])
		_quad(vertices, normals, colors, a, b, c, d, inward, _tint(color.darkened(0.25), rng))
	# The floor of the passage, a hair below the cave floor so the two never
	# flicker where they overlap.
	var floor_y := -0.01
	var fl := Vector3(-inner_half_width, floor_y, -porch)
	var fr := Vector3(inner_half_width, floor_y, -porch)
	var bl := Vector3(-inner_half_width, floor_y, depth)
	var br := Vector3(inner_half_width, floor_y, depth)
	_quad(vertices, normals, colors, fl, fr, br, bl, Vector3.UP, color.darkened(0.35))
	# Collision for all of it.
	var shape := ConcavePolygonShape3D.new()
	var faces := PackedVector3Array(vertices)
	# The cap closes the passage (a wall of pure black). Separate surface.
	var cap_vertices := PackedVector3Array()
	var center := Vector3(0.0, inner_height * 0.45, depth - 0.2)
	for i in inner.size() - 1:
		var a := Vector3(inner[i].x, inner[i].y, depth - 0.2)
		var b := Vector3(inner[i + 1].x, inner[i + 1].y, depth - 0.2)
		cap_vertices.append_array([center, a, b])
	cap_vertices.append_array([center, Vector3(inner_half_width, 0.0, depth - 0.2), Vector3(-inner_half_width, 0.0, depth - 0.2)])
	faces.append_array(cap_vertices)
	shape.set_faces(faces)
	shape.backface_collision = true

	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _material())
	var instance := MeshInstance3D.new()
	instance.name = "Collar"
	instance.mesh = mesh
	parent.add_child(instance)

	var cap_mesh := ArrayMesh.new()
	var cap_arrays := []
	cap_arrays.resize(Mesh.ARRAY_MAX)
	cap_arrays[Mesh.ARRAY_VERTEX] = cap_vertices
	var cap_normals := PackedVector3Array()
	for i in cap_vertices.size():
		cap_normals.append(Vector3.FORWARD)
	cap_arrays[Mesh.ARRAY_NORMAL] = cap_normals
	cap_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cap_arrays)
	cap_mesh.surface_set_material(0, CaveShell.black_material())
	var cap := MeshInstance3D.new()
	cap.name = "BlackCap"
	cap.mesh = cap_mesh
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(cap)
	return {"mesh": instance, "shape": shape, "cap": cap}


static var _mat: StandardMaterial3D
static func _material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.roughness = 1.0
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mat


static func _tint(color: Color, rng: RandomNumberGenerator) -> Color:
	var k := rng.randf_range(-0.05, 0.05)
	return Color(color.r + k, color.g + k * 0.7, color.b + k * 0.4)


## Outward normal (in the XY outline plane) of the outline segment a->b,
## for an outline that runs counter-clockwise from bottom-left over the top.
static func _outward(a: Vector2, b: Vector2) -> Vector3:
	var d := (b - a).normalized()
	return Vector3(-d.y, d.x, 0.0).normalized() if d != Vector2.ZERO else Vector3.UP


## Two flat triangles with the given normal. The material is double-sided,
## so winding only matters for lighting, which the explicit normal fixes.
static func _quad(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray,
		a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	for v in [a, b, c, a, c, d]:
		vertices.append(v)
		normals.append(normal)
		colors.append(color)
