class_name JailCell
extends StaticBody3D
## JAIL CELL -- a small barred chamber in the cave wall, for an ant that
## turns its back on the colony. A dirt collar like a little tunnel mouth,
## closed by a gate of bars that slides up to open and slams down to shut.
##
## Local space: -Z faces the middle of the cave, +Z into the wall.
##   open()         the bars rise (0.8 s)
##   slam()         the bars drop with a clang and a shake
##   cell_center()  where the ball ends up inside (world space)
## The opening cutscene rolls the ball in by itself; see the hub.

const INNER_HALF_WIDTH := 1.7
const INNER_HEIGHT := 3.2
const OUTER_HALF_WIDTH := 2.9
const OUTER_HEIGHT := 4.4
const PORCH := 1.5
const COLLAR_DEPTH := 4.0
const DEPTH := 5.5
const BAR_Z := -PORCH + 0.45
const COLOR := Color(0.5, 0.29, 0.15)
const BAR_COLOR := Color(0.32, 0.3, 0.3)

var _gate: Node3D
var _gate_shape: CollisionShape3D
var _is_open := false


func _ready() -> void:
	add_to_group("jail")
	var built := ArchBuilder.build(self, INNER_HALF_WIDTH, INNER_HEIGHT, OUTER_HALF_WIDTH, OUTER_HEIGHT,
			PORCH, COLLAR_DEPTH, DEPTH, COLOR)
	var collider := CollisionShape3D.new()
	collider.shape = built.shape
	add_child(collider)
	_build_gate()
	# A cold little light inside so the bars show against the dark.
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.7, 0.9)
	light.light_energy = 0.8
	light.omni_range = 7.0
	light.shadow_enabled = false
	light.position = Vector3(0.0, INNER_HEIGHT - 0.4, 2.0)
	add_child(light)


func _build_gate() -> void:
	_gate = Node3D.new()
	_gate.name = "Gate"
	add_child(_gate)
	var material := StandardMaterial3D.new()
	material.albedo_color = BAR_COLOR
	material.roughness = 0.45
	material.metallic = 0.6
	var bar_mesh := CylinderMesh.new()
	bar_mesh.top_radius = 0.07
	bar_mesh.bottom_radius = 0.07
	bar_mesh.height = INNER_HEIGHT + 0.6
	bar_mesh.radial_segments = 6
	bar_mesh.rings = 1
	bar_mesh.material = material
	var count := 8
	for i in count:
		var bar := MeshInstance3D.new()
		bar.mesh = bar_mesh
		var x := lerpf(-INNER_HALF_WIDTH + 0.15, INNER_HALF_WIDTH - 0.15, float(i) / (count - 1))
		bar.position = Vector3(x, bar_mesh.height * 0.5 - 0.3, BAR_Z)
		_gate.add_child(bar)
	for y in [0.4, INNER_HEIGHT - 0.9]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(INNER_HALF_WIDTH * 2.0 + 0.3, 0.14, 0.14)
		rail_mesh.material = material
		rail.mesh = rail_mesh
		rail.position = Vector3(0.0, y, BAR_Z)
		_gate.add_child(rail)
	# The gate's own solid body moves with it.
	var body := StaticBody3D.new()
	body.name = "GateBody"
	_gate_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(INNER_HALF_WIDTH * 2.0 + 0.3, INNER_HEIGHT + 0.6, 0.3)
	_gate_shape.shape = box
	_gate_shape.position = Vector3(0.0, INNER_HEIGHT * 0.5, BAR_Z)
	body.add_child(_gate_shape)
	_gate.add_child(body)


func is_open() -> bool:
	return _is_open


## The bars slide up into the ceiling.
func open() -> void:
	if _is_open:
		return
	_is_open = true
	_gate_shape.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(_gate, "position:y", INNER_HEIGHT + 0.4, 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	Sounds.play("menu_open", -4.0, 0.6)


## The bars slam shut.
func slam() -> void:
	if not _is_open:
		return
	_is_open = false
	var tween := create_tween()
	tween.tween_property(_gate, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		_gate_shape.set_deferred("disabled", false)
		Sounds.play("thud", 2.0, 0.7)
		Effects.impact(Tuning.impact_big * 1.5, Vector3.DOWN, to_global(Vector3(0.0, 0.2, BAR_Z))))


## Where the prisoner sits: the middle of the chamber, on the floor.
func cell_center() -> Vector3:
	return to_global(Vector3(0.0, 0.5, (COLLAR_DEPTH + DEPTH) * 0.5 - 1.0))


## A spot in front of the bars, on the cave floor, to roll in from.
func approach_point() -> Vector3:
	return to_global(Vector3(0.0, 0.5, -PORCH - 4.0))
