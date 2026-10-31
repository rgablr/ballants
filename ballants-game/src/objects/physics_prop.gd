@tool
class_name PhysicsProp
extends RigidBody3D
## PHYSICS PROP -- a loose object the player can push, knock over, or ride:
## crates, boulders, planks. Falls, rolls and tumbles under physics.
##
## Like Block, one shape setting drives both the look and the collision.
## Weight comes from the tuning file when tuning_mass_name is set (for
## example "crate_mass"), so all crates can be re-weighed in one place.

enum ShapeType { BOX, SPHERE }

@export var shape_type: ShapeType = ShapeType.BOX:
	set(value):
		shape_type = value
		_rebuild()

## Box dimensions (ignored for spheres).
@export var size := Vector3(0.8, 0.8, 0.8):
	set(value):
		size = value
		_refresh()

## Sphere radius (ignored for boxes).
@export var radius := 0.6:
	set(value):
		radius = value
		_refresh()

@export var color := Color(0.62, 0.45, 0.28):
	set(value):
		color = value
		_refresh()

## Name of a value in config/physics_tuning.gd to use as this prop's weight,
## e.g. "crate_mass". Leave empty to use the Mass field in the Inspector.
@export var tuning_mass_name := ""

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D
var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.roughness = 0.85
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)
	_collision = CollisionShape3D.new()
	add_child(_collision)
	_rebuild()

	if not Engine.is_editor_hint() and not tuning_mass_name.is_empty():
		var tuned = Tuning.get(tuning_mass_name)
		if tuned == null:
			push_error("PhysicsProp: no '%s' in physics_tuning.gd" % tuning_mass_name)
		else:
			mass = tuned


func _rebuild() -> void:
	if _mesh_instance == null:
		return
	match shape_type:
		ShapeType.BOX:
			_mesh_instance.mesh = BoxMesh.new()
			_collision.shape = BoxShape3D.new()
		ShapeType.SPHERE:
			var sphere := SphereMesh.new()
			sphere.radial_segments = 16
			sphere.rings = 8
			_mesh_instance.mesh = sphere
			_collision.shape = SphereShape3D.new()
	_mesh_instance.mesh.material = _material
	_refresh()


func _refresh() -> void:
	if _mesh_instance == null or _mesh_instance.mesh == null:
		return
	match shape_type:
		ShapeType.BOX:
			(_mesh_instance.mesh as BoxMesh).size = size
			(_collision.shape as BoxShape3D).size = size
		ShapeType.SPHERE:
			(_mesh_instance.mesh as SphereMesh).radius = radius
			(_mesh_instance.mesh as SphereMesh).height = radius * 2.0
			(_collision.shape as SphereShape3D).radius = radius
	_material.albedo_color = color
