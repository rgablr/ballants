@tool
class_name Block
extends StaticBody3D
## BLOCK -- a solid, unmoving box used to build levels: floors, walls,
## pillars, platforms, and ramps (just rotate it).
##
## One "size" controls both what you see and what you collide with, so the
## two can never disagree. Drop block.tscn into a level, set Size and Color
## in the Inspector, done.

@export var size := Vector3(4.0, 1.0, 4.0):
	set(value):
		size = value
		_refresh()

@export var color := Color(0.76, 0.73, 0.67):
	set(value):
		color = value
		_refresh()

## Leave on for anything that never moves. StaticMerger folds the collision
## of all such blocks into one body so the ball rolls over seams smoothly.
@export var merge_collision := true

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D
var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.roughness = 0.9

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = BoxMesh.new()
	_mesh_instance.mesh.material = _material
	add_child(_mesh_instance)

	_collision = CollisionShape3D.new()
	_collision.shape = BoxShape3D.new()
	add_child(_collision)

	_refresh()


func _refresh() -> void:
	if _mesh_instance == null:
		return
	(_mesh_instance.mesh as BoxMesh).size = size
	(_collision.shape as BoxShape3D).size = size
	_material.albedo_color = color
