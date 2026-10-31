@tool
class_name LeafPatch
extends SlickPatch
## LEAF PATCH -- a fallen leaf lying on the path; slippery (a SlickPatch
## with a leaf mesh). "leaf_length" runs along local Z.

@export var leaf_length := 4.0:
	set(v):
		leaf_length = v
		_rebuild()
@export var leaf_width := 2.4:
	set(v):
		leaf_width = v
		_rebuild()

var _leaf: MeshInstance3D


func _ready() -> void:
	super()
	_rebuild()


func _rebuild() -> void:
	if _leaf:
		_leaf.queue_free()
	size = Vector3(leaf_width, 1.2, leaf_length)
	_leaf = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = GardenTheme.material("leaf_wet")
	_leaf.mesh = mesh
	_leaf.scale = Vector3(leaf_width, 0.08, leaf_length)
	_leaf.position = Vector3(0, 0.02, 0)
	add_child(_leaf)
	var rib := MeshInstance3D.new()
	var rib_mesh := BoxMesh.new()
	rib_mesh.size = Vector3(0.12, 0.05, leaf_length * 0.9)
	rib_mesh.material = GardenTheme.material("stem")
	rib.mesh = rib_mesh
	rib.position = Vector3(0, 0.06, 0)
	_leaf.add_child(rib)
	rib.scale = Vector3(1.0 / leaf_width, 1.0 / 0.08, 1.0 / leaf_length)
