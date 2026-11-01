@tool
class_name CrumbPile
extends StaticBody3D
## CRUMB PILE -- a heap of pale food crumbs the workers have stacked up:
## a solid block (one box collider, `size`, base at y = 0) hidden under a
## jumble of chunky crumbs. Used to block part of a corridor so you have
## to change lanes. Like DirtTrack it opts into the level's StaticMerger.

@export var size := Vector3(3.0, 1.4, 2.5):
	set(v):
		size = v
		_rebuild()
@export var seed := 1:
	set(v):
		seed = v
		_rebuild()
@export var merge_collision := true

const CRUMB := Color(0.93, 0.86, 0.68)
const CRUMB_DARK := Color(0.78, 0.68, 0.48)

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
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0.0, size.y * 0.5, 0.0)
	add_child(shape)
	var pale := CritterParts.material(CRUMB, 0.95)
	var dark := CritterParts.material(CRUMB_DARK, 0.95)
	var core := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size * Vector3(0.96, 0.9, 0.96)
	mesh.material = dark
	core.mesh = mesh
	core.position = Vector3(0.0, size.y * 0.45, 0.0)
	add_child(core)
	# Chunky crumbs heaped over it: boxes tipped at odd angles.
	var n := int(size.x * size.z * 1.6) + 4
	for i in n:
		var c := MeshInstance3D.new()
		var b := BoxMesh.new()
		var s := rng.randf_range(0.45, 0.85)
		b.size = Vector3(s, s * rng.randf_range(0.55, 0.8), s * rng.randf_range(0.7, 1.0))
		b.material = pale if rng.randf() < 0.75 else dark
		c.mesh = b
		var x := rng.randf_range(-0.5, 0.5) * (size.x - s * 0.6)
		var z := rng.randf_range(-0.5, 0.5) * (size.z - s * 0.6)
		var edge := maxf(absf(x) / (size.x * 0.5), absf(z) / (size.z * 0.5))
		c.position = Vector3(x, size.y * (1.0 - edge * 0.55) - s * 0.25, z)
		c.rotation = Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))
		add_child(c)
