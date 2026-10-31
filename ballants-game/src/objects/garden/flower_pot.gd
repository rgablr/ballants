@tool
class_name FlowerPot
extends StaticBody3D
## FLOWER POT -- a terracotta pot, huge at ant scale. The ball can land on
## the soil on top. Collision: one cylinder the size of the pot, so the top
## is a flat landing surface at `height`.

@export var height := 3.0:
	set(v):
		height = v
		_rebuild()
@export var top_radius := 2.2:
	set(v):
		top_radius = v
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
	var bottom_radius := top_radius * 0.72

	var pot := MeshInstance3D.new()
	var pot_mesh := CylinderMesh.new()
	pot_mesh.top_radius = top_radius
	pot_mesh.bottom_radius = bottom_radius
	pot_mesh.height = height
	pot_mesh.radial_segments = 14
	pot_mesh.material = GardenTheme.material("pot")
	pot.mesh = pot_mesh
	pot.position = Vector3(0, height * 0.5, 0)
	add_child(pot)

	var rim := MeshInstance3D.new()
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = top_radius * 1.08
	rim_mesh.bottom_radius = top_radius * 1.08
	rim_mesh.height = height * 0.12
	rim_mesh.radial_segments = 14
	rim_mesh.material = GardenTheme.material("pot_rim")
	rim.mesh = rim_mesh
	rim.position = Vector3(0, height - height * 0.06, 0)
	add_child(rim)

	var soil := MeshInstance3D.new()
	var soil_mesh := CylinderMesh.new()
	soil_mesh.top_radius = top_radius * 0.98
	soil_mesh.bottom_radius = top_radius * 0.98
	soil_mesh.height = 0.1
	soil_mesh.radial_segments = 14
	soil_mesh.material = GardenTheme.material("dirt")
	soil.mesh = soil_mesh
	soil.position = Vector3(0, height + 0.02, 0)
	add_child(soil)

	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = top_radius * 1.08
	cylinder.height = height + 0.07
	shape.shape = cylinder
	shape.position = Vector3(0, (height + 0.07) * 0.5, 0)
	add_child(shape)
