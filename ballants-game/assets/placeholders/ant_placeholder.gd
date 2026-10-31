@tool
extends Node3D
## PLACEHOLDER ANT -- a low-poly ant assembled from basic shapes in code.
##
## Any model that replaces this (via the "ant" entry in asset_manifest.gd)
## only needs to match two things:
##   1. Feet at the origin (y = 0), facing -Z (Godot's "forward").
##   2. Optionally a set_walk_speed(speed) method to animate walking. If it
##      is missing, the ant just stays still, which is fine.

const BODY_COLOR := Color(0.45, 0.19, 0.10)
const DARK_COLOR := Color(0.22, 0.09, 0.05)
const EYE_COLOR := Color(0.03, 0.03, 0.03)

const LEG_SWING := 0.5     # radians each leg swings at full walking speed
const STEP_RATE := 2.4     # leg cycles per meter travelled
const FULL_SWING_SPEED := 4.0  # ball speed (m/s) at which legs swing their maximum

var _legs: Array[Node3D] = []
var _walk_phase := 0.0
var _walk_speed := 0.0


func _ready() -> void:
	_build()


func set_walk_speed(speed: float) -> void:
	_walk_speed = speed


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_walk_phase += delta * _walk_speed * STEP_RATE * TAU
	var swing: float = LEG_SWING * clamp(_walk_speed / FULL_SWING_SPEED, 0.0, 1.0)
	for i in _legs.size():
		# Tripod gait: alternate legs move together, like a real ant.
		var phase := _walk_phase + PI * (i % 2)
		_legs[i].rotation.y = sin(phase) * swing


func _build() -> void:
	var body := _material(BODY_COLOR)
	var dark := _material(DARK_COLOR)
	var eye := _material(EYE_COLOR)

	# Three body segments: head, thorax (middle), abdomen (back).
	_sphere(self, Vector3(0.0, 0.15, -0.17), 0.075, Vector3.ONE, body)
	_sphere(self, Vector3(0.0, 0.14, 0.0), 0.065, Vector3.ONE, body)
	_sphere(self, Vector3(0.0, 0.14, 0.17), 0.08, Vector3(1.0, 0.9, 1.5), body)
	# Eyes.
	_sphere(self, Vector3(0.04, 0.17, -0.22), 0.018, Vector3.ONE, eye)
	_sphere(self, Vector3(-0.04, 0.17, -0.22), 0.018, Vector3.ONE, eye)
	# Antennae.
	_capsule(self, Vector3(0.02, 0.19, -0.21), Vector3(0.07, 0.3, -0.33), 0.008, dark)
	_capsule(self, Vector3(-0.02, 0.19, -0.21), Vector3(-0.07, 0.3, -0.33), 0.008, dark)

	# Six legs: left side first (front, middle, back), then right side.
	for side in [1.0, -1.0]:
		for z in [-0.07, 0.0, 0.07]:
			var hip := Vector3(side * 0.05, 0.14, z)
			var knee := Vector3(side * 0.17, 0.22, z * 1.6)
			var foot := Vector3(side * 0.25, 0.0, z * 2.6)
			var pivot := Node3D.new()
			pivot.position = hip
			add_child(pivot)
			_capsule(pivot, Vector3.ZERO, knee - hip, 0.012, dark)
			_capsule(pivot, knee - hip, foot - hip, 0.01, dark)
			_legs.append(pivot)


func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m


func _sphere(parent: Node3D, pos: Vector3, radius: float, scale_by: Vector3, mat: Material) -> void:
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


## A thin rod from point a to point b.
func _capsule(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var length := a.distance_to(b)
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = length + radius * 2.0
	mesh.radial_segments = 6
	mesh.rings = 2
	mesh.material = mat
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	# CapsuleMesh points along its Y axis; aim that axis from a to b.
	var y := (b - a).normalized()
	var helper := Vector3.FORWARD if abs(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(helper).normalized()
	var z := x.cross(y)
	instance.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	parent.add_child(instance)
