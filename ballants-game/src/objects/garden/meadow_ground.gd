@tool
class_name MeadowGround
extends StaticBody3D
## MEADOW GROUND -- the rolling ground of the title area, sculpted in code.
##
## Seen from above it is a FUNNEL, not a path: a wide clearing where you
## start, a valley that gently narrows and slopes downhill toward the giant
## ant hill, and a round hollow around the hill. Grassy berms rise on every
## side (gentle at first, steep at the very edge), so a ball that wanders
## drifts back toward the middle and, eventually, the hill. A worn dirt
## trail runs down the middle as a hint.
##
## One mesh, one collision shape (a triangle mesh of the same surface), so
## there are no seams for the ball to catch on. height_at(x, z) gives the
## ground height anywhere, which the title area uses to stand things on it.
##
## All sizes in meters; the clearing is centered on this node.

## Where the giant ant hill stands, relative to this node.
@export var hill_center := Vector2(0.0, -64.0):
	set(v):
		hill_center = v
		_rebuild()
## Radius of the flat-bottomed hollow around the hill.
@export var hollow_radius := 36.0:
	set(v):
		hollow_radius = v
		_rebuild()
## Radius of the starting clearing.
@export var clearing_radius := 30.0:
	set(v):
		clearing_radius = v
		_rebuild()
## Half-width of the valley where it is narrowest (just before the hollow).
@export var neck_half_width := 13.0:
	set(v):
		neck_half_width = v
		_rebuild()
## Height of the grassy berms that turn you back toward the middle.
@export var berm_height := 6.0:
	set(v):
		berm_height = v
		_rebuild()
## How much higher the clearing is than the hollow: the whole valley
## slopes gently downhill toward the hill so a rolling ball drifts there.
@export var valley_drop := 1.2:
	set(v):
		valley_drop = v
		_rebuild()
## Size of the whole sheet of ground.
@export var size := Vector2(170.0, 180.0):
	set(v):
		size = v
		_rebuild()
## Center of the sheet relative to this node (the clearing is at 0, 0).
@export var sheet_center := Vector2(0.0, -30.0):
	set(v):
		sheet_center = v
		_rebuild()
## Grid spacing; smaller = smoother hills, more triangles.
@export var cell := 1.5:
	set(v):
		cell = maxf(v, 0.5)
		_rebuild()

const GRASS := Color(0.42, 0.72, 0.28)
const GRASS_DARK := Color(0.32, 0.6, 0.22)
const DIRT := Color(0.56, 0.41, 0.26)
const DIRT_LIGHT := Color(0.66, 0.51, 0.33)

var _built := false
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.seed = 3
	_noise.frequency = 0.035
	_built = true
	_rebuild()


## How far outside the playable funnel a point is (negative = inside).
func _outside(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var clearing := p.length() - clearing_radius
	var hollow := p.distance_to(hill_center) - hollow_radius
	# Valley: from the clearing to the hollow, narrowing as it goes.
	var t := clampf(z / hill_center.y, 0.0, 1.0)   # 0 at the clearing, 1 at the hill
	var half := lerpf(clearing_radius * 0.85, neck_half_width, smoothstep(0.0, 0.75, t))
	var valley := absf(x) - half
	if z > 0.0 or z < hill_center.y:
		valley = 999.0
	return minf(minf(clearing, hollow), valley)


## Ground height at a point (local x, z).
func height_at(x: float, z: float) -> float:
	var d := _outside(x, z)
	# Berms: a gentle rise, then a steep wall at the very edge.
	var h := berm_height * smoothstep(0.0, 20.0, d) + berm_height * 2.0 * smoothstep(24.0, 34.0, d)
	# The valley floor slopes down toward the hollow.
	var t := clampf(z / (hill_center.y + hollow_radius * 0.6), 0.0, 1.0)
	h += valley_drop * (1.0 - smoothstep(0.0, 1.0, t))
	# Long, low undulations so it doesn't look ruled flat (never bumpy).
	h += _noise.get_noise_2d(x, z) * 0.35 * smoothstep(-6.0, 4.0, d) + _noise.get_noise_2d(x * 0.5, z * 0.5) * 0.15
	# Keep a flat pad under the giant hill.
	var to_hill := Vector2(x, z).distance_to(hill_center)
	h = lerpf(0.0, h, smoothstep(hollow_radius * 0.72, hollow_radius * 0.9, to_hill))
	return h


func _color_at(x: float, z: float, h: float) -> Color:
	var p := Vector2(x, z)
	var d := _outside(x, z)
	var c := GRASS.lerp(GRASS_DARK, clampf(0.5 + _noise.get_noise_2d(x * 3.0, z * 3.0), 0.0, 1.0) * 0.6)
	c = c.lerp(GRASS_DARK, smoothstep(2.0, 18.0, d) * 0.7)
	# Worn dirt trail from the clearing down to the hollow, a little wiggly.
	var wiggle := sin(z * 0.11) * 2.2 + _noise.get_noise_2d(z, 7.0) * 1.5
	if z < 4.0 and z > hill_center.y + hollow_radius * 0.7:
		var trail := absf(x - wiggle)
		c = c.lerp(DIRT, 1.0 - smoothstep(1.6, 2.6, trail))
	# Dirt patch at the start, and a ring of dug earth around the hill.
	c = c.lerp(DIRT, 1.0 - smoothstep(4.0, 6.5, p.length()))
	var to_hill := p.distance_to(hill_center)
	c = c.lerp(DIRT_LIGHT, 1.0 - smoothstep(hollow_radius * 0.72, hollow_radius * 0.85, to_hill))
	return c


func _rebuild() -> void:
	if not _built:
		return
	for child in get_children():
		child.queue_free()

	var nx := int(size.x / cell) + 1
	var nz := int(size.y / cell) + 1
	var x0 := sheet_center.x - size.x * 0.5
	var z0 := sheet_center.y - size.y * 0.5
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	for j in nz:
		for i in nx:
			heights[j * nx + i] = height_at(x0 + i * cell, z0 + j * cell)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for j in nz - 1:
		for i in nx - 1:
			var corners: Array[Vector3] = []
			for k in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var ii: int = i + k.x
				var jj: int = j + k.y
				corners.append(Vector3(x0 + ii * cell, heights[jj * nx + ii], z0 + jj * cell))
			# Two triangles, clockwise seen from above (Godot's front face).
			for tri in [[0, 1, 2], [1, 3, 2]]:
				for idx in tri:
					var v: Vector3 = corners[idx]
					st.set_color(_color_at(v.x, v.z, v.y))
					st.add_vertex(v)
					faces.append(v)
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true   # the colors above are ordinary (sRGB) colors
	mat.roughness = 0.95
	mesh.surface_set_material(0, mat)
	var instance := MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = mesh
	add_child(instance)

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.name = "Collision"
	collider.shape = shape
	add_child(collider)
