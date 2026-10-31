@tool
class_name CurvedTrack
extends Node3D
## CURVED TRACK -- a banked curve built from Block segments.
##
## Set the radius, width, how many degrees it sweeps, and the bank angle
## (how much the outer edge is raised). The inner edge of the track sits
## at this node's height, so place it at ground level. Segments are Blocks,
## so StaticMerger folds them into one body and the seams are smooth.

@export var radius := 10.0:
	set(v):
		radius = v
		_rebuild()
@export var width := 5.0:
	set(v):
		width = v
		_rebuild()
@export var sweep_degrees := 180.0:
	set(v):
		sweep_degrees = v
		_rebuild()
@export var start_degrees := 0.0:
	set(v):
		start_degrees = v
		_rebuild()
@export var bank_degrees := 22.0:
	set(v):
		bank_degrees = v
		_rebuild()
@export var segments := 16:
	set(v):
		segments = max(v, 1)
		_rebuild()
@export var thickness := 0.5:
	set(v):
		thickness = v
		_rebuild()
@export var color := Color(0.85, 0.65, 0.45):
	set(v):
		color = v
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
	var bank := deg_to_rad(bank_degrees)
	# Length along the curve per segment, with a little overlap so there
	# are no slivers of gap on the outside of the curve.
	var length := (radius + width * 0.5) * absf(step) * 1.05
	# Center height so the inner edge of the TOP surface is at y = 0.
	var center_y := (width * 0.5) * sin(bank) - (thickness * 0.5) * cos(bank)
	for i in segments:
		var angle := deg_to_rad(start_degrees) + (i + 0.5) * step
		var radial := Vector3(cos(angle), 0.0, sin(angle))          # points outward
		var tangent := Vector3(-sin(angle), 0.0, cos(angle)) * signf(step)
		var block := Block.new()
		block.size = Vector3(width, thickness, length)
		block.color = color
		add_child(block)
		var basis := Basis.looking_at(tangent, Vector3.UP)
		# Raise whichever local-X end faces outward.
		var outward_sign := 1.0 if basis.x.dot(radial) > 0.0 else -1.0
		basis = basis * Basis(Vector3(0, 0, 1), bank * outward_sign)
		block.transform = Transform3D(basis, radial * radius + Vector3.UP * center_y)
