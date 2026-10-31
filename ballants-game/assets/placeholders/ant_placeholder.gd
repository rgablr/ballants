@tool
extends Node3D
## PLACEHOLDER ANT -- a low-poly ant standing upright on its two back legs,
## assembled from basic shapes in code. Its front and middle legs are held
## out like arms for balance.
##
## The back feet are placed ON the ball's surface every frame (a small
## two-bone "IK" solve per leg), so they never float or sink, and walking
## slides them back and forth along the surface.
##
## Any model that replaces this (via the "ant" entry in asset_manifest.gd)
## only needs to match:
##   1. Feet at the origin (y = 0), facing -Z (Godot's "forward").
##   2. Optionally set_walk_speed(speed) and set_ball_radius(radius) methods
##      to animate. Both are optional; without them the model just stands.

const BODY_COLOR := Color(0.45, 0.19, 0.10)
const DARK_COLOR := Color(0.22, 0.09, 0.05)
const EYE_COLOR := Color(0.03, 0.03, 0.03)

const STEP_RATE := 1.6          # leg cycles per meter travelled
const FULL_SWING_SPEED := 4.0   # ball speed (m/s) at which the walk is at full size
const STRIDE := 0.06            # how far each foot slides forward/back (meters)
const BOB := 0.012              # body bounce per step (meters)
const LEAN := 0.18              # body tilt forward at full speed (radians)

const HIP_OFFSET := Vector3(0.045, 0.21, 0.03)   # back-leg hip, right side (x mirrored for left)
const FOOT_REST := Vector3(0.13, 0.0, 0.02)      # where a back foot rests, right side
const FEMUR := 0.12             # upper leg length
const TIBIA := 0.15             # lower leg length

var _ball_radius := 0.5
var _walk_phase := 0.0
var _walk_speed := 0.0

var _body: Node3D
var _legs: Array[Dictionary] = []   # each: {side, femur, tibia}


func _ready() -> void:
	_build()


func set_walk_speed(speed: float) -> void:
	_walk_speed = speed


## Radius of the ball the ant stands on, in this model's units.
func set_ball_radius(ball_radius: float) -> void:
	_ball_radius = max(ball_radius, 0.05)


func _process(delta: float) -> void:
	var amount: float = clamp(_walk_speed / FULL_SWING_SPEED, 0.0, 1.0)
	if not Engine.is_editor_hint():
		_walk_phase += delta * _walk_speed * STEP_RATE * TAU
	_body.position.y = abs(sin(_walk_phase)) * BOB * amount
	_body.rotation.x = -LEAN * amount
	for i in _legs.size():
		var leg: Dictionary = _legs[i]
		var side: float = leg.side
		var foot := Vector3(FOOT_REST.x * side, 0.0, FOOT_REST.z)
		# Opposite legs step in opposite phase.
		foot.z += sin(_walk_phase + PI * i) * STRIDE * amount
		foot.y = _height_on_ball(foot.x, foot.z)
		var hip: Vector3 = _body.to_global(Vector3(HIP_OFFSET.x * side, HIP_OFFSET.y, HIP_OFFSET.z))
		hip = to_local(hip)
		var knee := _solve_knee(hip, foot, side)
		_set_rod(leg.femur, hip, knee)
		_set_rod(leg.tibia, knee, foot)


## Height of the ball's surface at a horizontal offset from the top.
## The ant's origin is the top of the ball, so the ball's center is at
## (0, -radius, 0) in the ant's own space.
func _height_on_ball(x: float, z: float) -> float:
	var r := _ball_radius
	var h2 := r * r - x * x - z * z
	if h2 <= 0.0:
		return -r
	return sqrt(h2) - r


## Two-bone IK: where does the knee go so the leg reaches from hip to foot
## with fixed femur/tibia lengths? The knee bends outward and up, like an
## insect's.
func _solve_knee(hip: Vector3, foot: Vector3, side: float) -> Vector3:
	var to_foot := foot - hip
	var distance: float = clamp(to_foot.length(), 0.01, FEMUR + TIBIA - 0.001)
	var direction := to_foot / to_foot.length()
	# Distance along hip->foot where the knee sits, and how far off that line.
	var along := (FEMUR * FEMUR - TIBIA * TIBIA + distance * distance) / (2.0 * distance)
	var off := sqrt(max(FEMUR * FEMUR - along * along, 0.0))
	var pole := Vector3(side, 0.6, 0.2).normalized()
	var perpendicular := (pole - direction * pole.dot(direction))
	if perpendicular.length_squared() < 0.0001:
		perpendicular = Vector3.UP
	return hip + direction * along + perpendicular.normalized() * off


func _build() -> void:
	var body := _material(BODY_COLOR)
	var dark := _material(DARK_COLOR)
	var eye := _material(EYE_COLOR)

	# Everything except the back legs hangs off _body so it can bob and lean.
	_body = Node3D.new()
	add_child(_body)

	# Abdomen: tilted egg pointing down and back.
	var abdomen := _sphere(_body, Vector3(0.0, 0.17, 0.07), 0.08, Vector3(1.0, 1.0, 1.45), body)
	abdomen.rotation_degrees.x = 40.0
	# Thorax (middle) and head.
	_sphere(_body, Vector3(0.0, 0.3, -0.01), 0.06, Vector3.ONE, body)
	_sphere(_body, Vector3(0.0, 0.42, -0.05), 0.07, Vector3.ONE, body)
	# Eyes.
	_sphere(_body, Vector3(0.035, 0.44, -0.105), 0.016, Vector3.ONE, eye)
	_sphere(_body, Vector3(-0.035, 0.44, -0.105), 0.016, Vector3.ONE, eye)
	# Antennae.
	_rod(_body, Vector3(0.02, 0.47, -0.07), Vector3(0.06, 0.58, -0.14), 0.008, dark)
	_rod(_body, Vector3(-0.02, 0.47, -0.07), Vector3(-0.06, 0.58, -0.14), 0.008, dark)

	for side in [1.0, -1.0]:
		# Middle legs: hang down at the sides like relaxed arms.
		_rod(_body, Vector3(side * 0.05, 0.3, -0.01), Vector3(side * 0.14, 0.26, -0.03), 0.011, dark)
		_rod(_body, Vector3(side * 0.14, 0.26, -0.03), Vector3(side * 0.12, 0.1, -0.05), 0.009, dark)
		# Front legs: held out forward for balance.
		_rod(_body, Vector3(side * 0.045, 0.34, -0.04), Vector3(side * 0.12, 0.38, -0.1), 0.011, dark)
		_rod(_body, Vector3(side * 0.12, 0.38, -0.1), Vector3(side * 0.08, 0.33, -0.19), 0.009, dark)
		# Back legs: built once, positioned every frame in _process.
		var femur := _rod(self, Vector3.ZERO, Vector3.UP * FEMUR, 0.013, dark)
		var tibia := _rod(self, Vector3.ZERO, Vector3.UP * TIBIA, 0.011, dark)
		_legs.append({"side": side, "femur": femur, "tibia": tibia})


func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m


func _sphere(parent: Node3D, pos: Vector3, radius: float, scale_by: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	mesh.material = mat
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.scale = scale_by
	parent.add_child(instance)
	return instance


## A thin rod from point a to point b.
func _rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.radial_segments = 6
	mesh.rings = 2
	mesh.material = mat
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	parent.add_child(instance)
	_set_rod(instance, a, b)
	return instance


## Re-aims an existing rod so it runs from a to b.
func _set_rod(instance: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var mesh := instance.mesh as CapsuleMesh
	var length := a.distance_to(b)
	mesh.height = length + mesh.radius * 2.0
	# CapsuleMesh points along its Y axis; aim that axis from a to b.
	var y := (b - a).normalized() if length > 0.0001 else Vector3.UP
	var helper := Vector3.FORWARD if abs(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(helper).normalized()
	var z := x.cross(y)
	instance.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
