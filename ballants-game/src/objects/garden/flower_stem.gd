@tool
class_name FlowerStem
extends StaticBody3D
## FLOWER STEM -- a giant flower seen from ant height: a thick stem the
## ball bounces off, leaves partway up, and a flower head far above.
## Collision is a plain cylinder for the stem only (the head is out of
## reach). Bounciness comes from the ball's own bounce setting.
##
## Every flower is in the "flower" group; flies land on them and bees visit
## them (top_position() is where they land).

@export var stem_radius := 0.7:
	set(v):
		stem_radius = v
		_rebuild()
@export var stem_height := 10.0:
	set(v):
		stem_height = v
		_rebuild()
@export_enum("petal_pink", "petal_yellow", "petal_white", "petal_purple") var petal_color := "petal_pink":
	set(v):
		petal_color = v
		_rebuild()
@export var petal_count := 6:
	set(v):
		petal_count = max(v, 3)
		_rebuild()

var _built := false


func _ready() -> void:
	add_to_group("flower")
	_built = true
	_rebuild()


## The middle of the flower head, where an insect would land (world space).
func top_position() -> Vector3:
	return global_position + Vector3.UP * (stem_height + 0.3 + stem_radius * 0.8)


func _rebuild() -> void:
	if not _built:
		return
	for child in get_children():
		child.queue_free()

	# Stem: visible cylinder + matching collision cylinder.
	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = stem_radius * 0.85
	stem_mesh.bottom_radius = stem_radius
	stem_mesh.height = stem_height
	stem_mesh.radial_segments = 10
	stem_mesh.material = GardenTheme.material("stem")
	stem.mesh = stem_mesh
	stem.position = Vector3(0, stem_height * 0.5, 0)
	add_child(stem)

	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = stem_radius
	cylinder.height = stem_height
	shape.shape = cylinder
	shape.position = Vector3(0, stem_height * 0.5, 0)
	add_child(shape)

	# Two leaves partway up (decorative).
	for i in 2:
		var leaf := MeshInstance3D.new()
		var leaf_mesh := SphereMesh.new()
		leaf_mesh.radius = 1.0
		leaf_mesh.height = 2.0
		leaf_mesh.radial_segments = 8
		leaf_mesh.rings = 4
		leaf_mesh.material = GardenTheme.material("leaf")
		leaf.mesh = leaf_mesh
		var angle := i * PI + 0.6
		leaf.position = Vector3(cos(angle) * 1.6, stem_height * (0.35 + 0.2 * i), sin(angle) * 1.6)
		leaf.rotation = Vector3(0.3, -angle, 0.4)
		leaf.scale = Vector3(1.8, 0.12, 0.9)
		add_child(leaf)

	# Flower head: a center disc and a ring of petals.
	var head_y := stem_height + 0.3
	var center := MeshInstance3D.new()
	var center_mesh := SphereMesh.new()
	center_mesh.radius = stem_radius * 1.6
	center_mesh.height = stem_radius * 1.6
	center_mesh.radial_segments = 10
	center_mesh.rings = 5
	center_mesh.material = GardenTheme.material("flower_center")
	center.mesh = center_mesh
	center.position = Vector3(0, head_y, 0)
	add_child(center)
	for i in petal_count:
		var petal := MeshInstance3D.new()
		var petal_mesh := SphereMesh.new()
		petal_mesh.radius = 1.0
		petal_mesh.height = 2.0
		petal_mesh.radial_segments = 8
		petal_mesh.rings = 4
		petal_mesh.material = GardenTheme.material(petal_color)
		petal.mesh = petal_mesh
		var angle := TAU * i / petal_count
		var reach := stem_radius * 3.2
		petal.position = Vector3(cos(angle) * reach, head_y - 0.2, sin(angle) * reach)
		petal.rotation = Vector3(0, -angle, 0.25)
		petal.scale = Vector3(stem_radius * 2.4, stem_radius * 0.5, stem_radius * 1.4)
		add_child(petal)
