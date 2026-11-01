@tool
class_name FalseWall
extends Node3D
## FALSE WALL -- a crumbling-looking section of dirt wall that the ball can
## roll straight through: it hides a shortcut tunnel. Looks almost like a
## DirtWall of the same size, but on close inspection the dirt is looser
## (loose clods, a slightly lighter crumbly color) with thin cracks. NO
## collision. Place it in the gap left in a real wall, same length and
## height, so from a distance the wall reads as unbroken.
##
## `subtlety` 0 = obviously different, 1 = almost identical to the wall.

@export var length := 6.0:
	set(v):
		length = v
		_rebuild()
@export var height := 3.0:
	set(v):
		height = v
		_rebuild()
@export var thickness := 1.0:
	set(v):
		thickness = v
		_rebuild()
@export_range(0.0, 1.0) var subtlety := 0.7:
	set(v):
		subtlety = v
		_rebuild()
@export var seed := 9:
	set(v):
		seed = v
		_rebuild()
## How far the top leans outward (-X), as a fraction of the height; match
## the DirtTrack's wall_lean so it lines up with the real wall.
@export var lean := 0.18:
	set(v):
		lean = v
		_rebuild()

var _built := false


func _ready() -> void:
	_built = true
	_rebuild()


func _rebuild() -> void:
	if not _built:
		return
	for child in get_children():
		child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# Everything hangs off a tilted node so the wall leans like a real one.
	var tilt := Node3D.new()
	tilt.name = "Tilt"
	tilt.rotation.z = atan(lean)
	add_child(tilt)
	# The face: a box of crumbly dirt, a touch lighter than the wall.
	var packed: Color = DirtTrack.COLOR_WALL
	var crumble: Color = AnthillTheme.COLORS.crumble
	var face_material := StandardMaterial3D.new()
	face_material.albedo_color = packed.lerp(crumble, (1.0 - subtlety) * 0.7)
	face_material.roughness = 1.0
	var core := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(thickness, height, length)
	box.material = face_material
	core.mesh = box
	core.position = Vector3(0.0, height * 0.5, 0.0)
	tilt.add_child(core)
	# Loose clods stuck all over both faces (more than a real wall has).
	var clod_material := AnthillTheme.material("dirt_light")
	var clods := int(ceil(length * 1.6 * (1.3 - subtlety * 0.5)))
	for i in clods:
		var s := rng.randf_range(0.2, 0.45)
		var z := rng.randf_range(-length * 0.5 + s, length * 0.5 - s)
		var y := rng.randf_range(s, height - s * 0.5)
		var side := signf(rng.randf() - 0.5)
		CritterParts.sphere(tilt, Vector3(side * thickness * 0.5, y, z), s, Vector3(0.6, 0.8, 1.0), clod_material, 6)
	# Thin dark cracks running down the faces.
	var crack_material := AnthillTheme.material("crack")
	var cracks := 2 + int((1.0 - subtlety) * 3.0)
	for i in cracks:
		var z := rng.randf_range(-length * 0.4, length * 0.4)
		var side := signf(rng.randf() - 0.5)
		var top := Vector3(side * (thickness * 0.5 + 0.01), height * rng.randf_range(0.7, 1.0), z)
		var mid := top + Vector3(0.0, -height * 0.35, rng.randf_range(-0.4, 0.4))
		var bottom := mid + Vector3(0.0, -height * rng.randf_range(0.25, 0.4), rng.randf_range(-0.4, 0.4))
		CritterParts.rod(tilt, top, mid, 0.03, crack_material)
		CritterParts.rod(tilt, mid, bottom, 0.025, crack_material)
	# Lumps along the top edge like a real wall, so the silhouette matches.
	var lump_material := AnthillTheme.material("dirt_dark")
	var lumps := int(ceil(length / 1.5))
	for i in lumps:
		var z := -length * 0.5 + (i + 0.5) * (length / lumps) + rng.randf_range(-0.3, 0.3)
		var s := rng.randf_range(0.5, 0.9) * thickness
		var lump := CritterParts.sphere(tilt, Vector3(rng.randf_range(-0.2, 0.2) * thickness, height + rng.randf_range(-0.25, 0.15) * s, z),
				s, Vector3(1.2, 0.6, 1.0), lump_material, 7)
		lump.rotation.y = rng.randf() * TAU
