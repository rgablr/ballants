@tool
class_name CurvedGrassWall
extends Node3D
## CURVED GRASS WALL -- a GrassWall bent around an arc, so a curved path
## (CurvedTrack) can be fenced the same way a straight one is.
##
## Uses the same arc convention as CurvedTrack: at angle A the wall passes
## through (radius * cos A, 0, radius * sin A) relative to this node, so
## put the node at the curve's center and give it the same start_degrees
## and sweep_degrees as the track, with radius = track radius +/- half the
## track width (+ 0.5 for the wall's own thickness).

@export var radius := 20.0:
	set(v):
		radius = v
		_rebuild()
@export var sweep_degrees := 90.0:
	set(v):
		sweep_degrees = v
		_rebuild()
@export var start_degrees := 0.0:
	set(v):
		start_degrees = v
		_rebuild()
## One straight GrassWall per segment; more = smoother.
@export var segments := 8:
	set(v):
		segments = max(v, 1)
		_rebuild()
@export var base_height := 0.8:
	set(v):
		base_height = v
		_rebuild()
@export var seed := 11:
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
	var step := deg_to_rad(sweep_degrees) / segments
	# Each chord is a bit longer than the arc so the corners meet.
	var chord := 2.0 * radius * sin(absf(step) * 0.5) + 0.6
	for i in segments:
		var angle := deg_to_rad(start_degrees) + (i + 0.5) * step
		var wall := GrassWall.new()
		wall.length = chord
		wall.base_height = base_height
		wall.seed = seed + i * 3
		add_child(wall)
		# The wall runs along its local Z; the tangent at this angle is
		# (-sin A, 0, cos A), which is local Z turned by -A about Y.
		wall.position = Vector3(cos(angle), 0.0, sin(angle)) * radius
		wall.rotation = Vector3(0.0, -angle, 0.0)
