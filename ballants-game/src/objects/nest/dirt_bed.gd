@tool
class_name DirtBed
extends StaticBody3D
## DIRT BED -- a raised bed of dark, damp, tilled soil from the ants'
## fungus garden: a solid box of packed dirt with a darker wet top, a few
## furrows, and tiny glowing fungus buttons along its edges so the lips
## of a jump are readable in the dark. One box collider of exactly `size`
## (looks are separate and never stick out above the top).
##
## The node's origin is the CENTER OF THE TOP surface (so placing a bed
## means saying where its floor is); the box hangs `size.y` below it.

@export var size := Vector3(10.0, 2.0, 10.0):
	set(v):
		size = v
		_rebuild()
## Meters between the glowing buttons along each edge; 0 = none.
@export var buttons_every := 1.6:
	set(v):
		buttons_every = v
		_rebuild()
## Which edges get buttons: x = left/right (the long sides along Z), z = front/back.
@export var buttons_on_sides := true:
	set(v):
		buttons_on_sides = v
		_rebuild()
@export var buttons_on_ends := true:
	set(v):
		buttons_on_ends = v
		_rebuild()
## Run the furrows along Z (true) or along X.
@export var furrows_along_z := true:
	set(v):
		furrows_along_z = v
		_rebuild()
@export var seed := 1:
	set(v):
		seed = v
		_rebuild()
## Leave on: the level's StaticMerger folds this collision into one body.
@export var merge_collision := true

const SIDE_COLOR := Color(0.36, 0.21, 0.11)
const TOP_COLOR := Color(0.27, 0.16, 0.09)       # damp soil
const FURROW_COLOR := Color(0.21, 0.12, 0.07)
const LIP_COLOR := Color(0.5, 0.31, 0.16)
const BUTTON_COLOR := Color(0.75, 1.0, 0.8)
const BUTTON_GLOW := Color(0.4, 0.95, 0.65)

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

	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.name = "Collision"
	col.shape = shape
	col.position.y = -size.y * 0.5
	add_child(col)

	var side_mat := StandardMaterial3D.new()
	side_mat.albedo_color = SIDE_COLOR
	side_mat.roughness = 1.0
	var box := BoxMesh.new()
	box.size = size
	box.material = side_mat
	var box_mi := MeshInstance3D.new()
	box_mi.mesh = box
	box_mi.position.y = -size.y * 0.5
	add_child(box_mi)

	# A lighter lip band just under the top edge, then the damp top.
	var lip_mat := StandardMaterial3D.new()
	lip_mat.albedo_color = LIP_COLOR
	lip_mat.roughness = 1.0
	var lip := BoxMesh.new()
	lip.size = Vector3(size.x + 0.04, 0.18, size.z + 0.04)
	lip.material = lip_mat
	var lip_mi := MeshInstance3D.new()
	lip_mi.mesh = lip
	lip_mi.position.y = -0.1
	add_child(lip_mi)

	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_color = TOP_COLOR
	top_mat.roughness = 0.45     # damp: a little sheen
	top_mat.metallic_specular = 0.6
	var top := PlaneMesh.new()
	top.size = Vector2(size.x - 0.3, size.z - 0.3)
	top.material = top_mat
	var top_mi := MeshInstance3D.new()
	top_mi.mesh = top
	top_mi.position.y = 0.012
	add_child(top_mi)

	# Furrows: thin darker strips (flat, so they never catch the ball).
	var furrow_mat := StandardMaterial3D.new()
	furrow_mat.albedo_color = FURROW_COLOR
	furrow_mat.roughness = 0.4
	var across := size.x if furrows_along_z else size.z
	var along := size.z if furrows_along_z else size.x
	var count := int((across - 1.0) / 1.4)
	for i in count:
		var offset := (float(i) + 0.5) / count * (across - 1.0) - (across - 1.0) * 0.5
		var strip := PlaneMesh.new()
		strip.size = Vector2(0.22, along - 0.8) if furrows_along_z else Vector2(along - 0.8, 0.22)
		strip.material = furrow_mat
		var strip_mi := MeshInstance3D.new()
		strip_mi.mesh = strip
		strip_mi.position = Vector3(offset, 0.02, 0.0) if furrows_along_z else Vector3(0.0, 0.02, offset)
		add_child(strip_mi)

	if buttons_every <= 0.0:
		return
	var button_mat := StandardMaterial3D.new()
	button_mat.albedo_color = BUTTON_COLOR
	button_mat.roughness = 0.6
	button_mat.emission_enabled = true
	button_mat.emission = BUTTON_GLOW
	button_mat.emission_energy_multiplier = 1.4
	var hx := size.x * 0.5 - 0.12
	var hz := size.z * 0.5 - 0.12
	var spots: Array[Vector3] = []
	if buttons_on_sides:
		var n := maxi(int(size.z / buttons_every), 1)
		for i in n + 1:
			var z := -hz + 2.0 * hz * float(i) / n
			spots.append(Vector3(-hx, 0.0, z))
			spots.append(Vector3(hx, 0.0, z))
	if buttons_on_ends:
		var n := maxi(int(size.x / buttons_every), 1)
		for i in range(1, n):
			var x := -hx + 2.0 * hx * float(i) / n
			spots.append(Vector3(x, 0.0, -hz))
			spots.append(Vector3(x, 0.0, hz))
	for spot in spots:
		var s := rng.randf_range(0.06, 0.11)
		var button := SphereMesh.new()
		button.radius = s
		button.height = s * 1.1
		button.radial_segments = 6
		button.rings = 2
		button.material = button_mat
		var mi := MeshInstance3D.new()
		mi.mesh = button
		mi.position = spot + Vector3(rng.randf_range(-0.05, 0.05), s * 0.3, rng.randf_range(-0.05, 0.05))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
