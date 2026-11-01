class_name JailCell
extends StaticBody3D
## JAIL CELL -- a small barred chamber in the cave wall, for an ant that
## turns its back on the colony. A dirt collar like a little tunnel mouth,
## closed by an arched door of bars (the same shape as the opening) hung on
## a hinge: it swings out into the cave to open and slams shut.
##
## Local space: -Z faces the middle of the cave, +Z into the wall.
##   open()         the door swings open (0.9 s)
##   slam()         the door slams shut with a clang and a shake
##   cell_center()  where the ball ends up inside (world space)
## In the opening cutscene the Queen bats the ball in; see the hub.

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

var _hinge: Node3D
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


## How far the door sits inside the arch on every side, so it never
## touches the dirt when it swings.
const DOOR_INSET := 0.14
## How far it swings open (degrees), out into the cave.
const OPEN_ANGLE := 84.0


## An arched door of bars, the same shape as the opening, hung on a hinge
## at its left edge. It swings out into the cave to open.
func _build_gate() -> void:
	var half := INNER_HALF_WIDTH - DOOR_INSET
	var height := INNER_HEIGHT - DOOR_INSET
	var straight := height - half   # the arch's sides are straight up to here
	_hinge = Node3D.new()
	_hinge.name = "Hinge"
	_hinge.position = Vector3(-half, 0.0, BAR_Z)
	add_child(_hinge)
	_gate = Node3D.new()
	_gate.name = "Gate"
	_gate.position = Vector3(half, 0.0, 0.0)   # door coordinates: x = 0 at its middle
	_hinge.add_child(_gate)
	var material := StandardMaterial3D.new()
	material.albedo_color = BAR_COLOR
	material.roughness = 0.45
	material.metallic = 0.6
	# The frame: the arch outline as a chain of thick rods, plus the sill.
	var outline := ArchBuilder.outline(half, height)
	for i in outline.size() - 1:
		var a := Vector3(outline[i].x, outline[i].y + 0.05, 0.0)
		var b := Vector3(outline[i + 1].x, outline[i + 1].y + 0.05, 0.0)
		CritterParts.rod(_gate, a, b, 0.07, material)
	CritterParts.rod(_gate, Vector3(-half, 0.08, 0.0), Vector3(half, 0.08, 0.0), 0.07, material)
	# Upright bars, each as tall as the arch is at that point.
	var count := 7
	for i in count:
		var x := lerpf(-half, half, float(i + 1) / (count + 1))
		var top := straight + sqrt(maxf(half * half - x * x, 0.0)) if absf(x) < half else straight
		CritterParts.rod(_gate, Vector3(x, 0.08, 0.0), Vector3(x, top, 0.0), 0.055, material)
	# A cross bar, and a lock plate on the free edge.
	CritterParts.rod(_gate, Vector3(-half, straight * 0.55, 0.0), Vector3(half, straight * 0.55, 0.0), 0.05, material)
	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.28, 0.36, 0.16)
	plate_mesh.material = material
	plate.mesh = plate_mesh
	plate.position = Vector3(half - 0.2, straight * 0.55, 0.0)
	_gate.add_child(plate)
	# Hinge knuckles on the wall side.
	for y in [0.4, straight * 0.85]:
		var knuckle := MeshInstance3D.new()
		var knuckle_mesh := CylinderMesh.new()
		knuckle_mesh.top_radius = 0.1
		knuckle_mesh.bottom_radius = 0.1
		knuckle_mesh.height = 0.3
		knuckle_mesh.material = material
		knuckle.mesh = knuckle_mesh
		knuckle.position = Vector3(0.0, y, 0.0)
		_hinge.add_child(knuckle)
	# The door's solid body moves with it.
	var body := AnimatableBody3D.new()
	body.name = "GateBody"
	_gate_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(half * 2.0, height, 0.25)
	_gate_shape.shape = box
	_gate_shape.position = Vector3(0.0, height * 0.5, 0.0)
	body.add_child(_gate_shape)
	_gate.add_child(body)


func is_open() -> bool:
	return _is_open


## The door swings open, out into the cave.
func open() -> void:
	if _is_open:
		return
	_is_open = true
	var tween := create_tween()
	tween.tween_property(_hinge, "rotation:y", deg_to_rad(OPEN_ANGLE), 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	Sounds.play("menu_open", -4.0, 0.55)


## The door slams shut and rattles.
func slam() -> void:
	if not _is_open:
		return
	_is_open = false
	var tween := create_tween()
	tween.tween_property(_hinge, "rotation:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		Sounds.play("thud", 2.0, 0.7)
		Effects.impact(Tuning.impact_big * 1.5, Vector3.BACK, to_global(Vector3(0.0, 0.8, BAR_Z))))
	tween.tween_property(_hinge, "rotation:y", deg_to_rad(6.0), 0.07)
	tween.tween_property(_hinge, "rotation:y", 0.0, 0.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## The point on the back wall a flying ball hits (center height y).
func back_wall_point(y: float) -> Vector3:
	return to_global(Vector3(0.0, y, DEPTH - 0.2 - 0.55))


## The middle of the doorway, a little in front of the door (height y).
func mouth_point(y: float) -> Vector3:
	return to_global(Vector3(0.0, y, -PORCH - 0.6))


## Where the prisoner sits: the middle of the chamber, on the floor.
func cell_center() -> Vector3:
	return to_global(Vector3(0.0, 0.5, (COLLAR_DEPTH + DEPTH) * 0.5 - 1.0))


## A spot in front of the bars, on the cave floor, to roll in from.
func approach_point() -> Vector3:
	return to_global(Vector3(0.0, 0.5, -PORCH - 4.0))
