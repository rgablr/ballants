@tool
class_name GrassWall
extends Node3D
## GRASS WALL -- a low solid edge of turf with tall blades on top. Runs
## along this node's local Z axis. Use it to fence the sides of a path
## early in a level; the solid base stops the ball, the blades show where
## the edge is from far away.

@export var length := 12.0:
	set(v):
		length = v
		_rebuild()
## Height of the solid base the ball bumps into.
@export var base_height := 0.8:
	set(v):
		base_height = v
		_rebuild()
@export var seed := 7:
	set(v):
		seed = v
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
	var base := Block.new()
	base.size = Vector3(1.0, base_height, length)
	base.color = GardenTheme.COLORS.grass_dark
	base.position = Vector3(0, base_height * 0.5, 0)
	add_child(base)
	var clumps := int(ceil(length / 2.0))
	for i in clumps:
		var clump := GrassClump.new()
		clump.radius = 0.5
		clump.blade_count = 6
		clump.height_min = 1.8
		clump.height_max = 3.2
		clump.seed = seed + i
		clump.position = Vector3(0, base_height, -length * 0.5 + (i + 0.5) * (length / clumps))
		add_child(clump)
