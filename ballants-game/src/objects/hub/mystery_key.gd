class_name MysteryKey
extends Area3D
## MYSTERY KEY -- a tiny yellow key (about a quarter the length of the hero
## ant) hanging in the air, part of the hub's birthday easter egg (see
## birthday_party.gd). It does not glow: it only turns slowly and catches
## the light, so it is easy to miss. Roll through it and it is yours:
## Progress.has_mystery_key goes on, a little sparkle, and it shrinks away.
## The pickup zone is wider than the key so a ball flying past still gets it.

signal found

const COLOR := Color(1.0, 0.82, 0.12)
## Tip to bow, in meters: the hero ant is about 0.5 m long.
const LENGTH := 0.14
## How far the ball's center may be from the key and still take it.
@export var pickup_radius := 1.0

var _model: Node3D
var _taken := false
var _time := 0.0


func _ready() -> void:
	add_to_group("mystery_key")
	_build()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = pickup_radius
	shape.shape = sphere
	add_child(shape)
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


## Bow (a ring), shaft, two teeth: all along the local X axis, brass yellow.
func _build() -> void:
	_model = Node3D.new()
	_model.name = "Key"
	add_child(_model)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = COLOR
	brass.roughness = 0.35
	brass.metallic = 0.45
	var bow := TorusMesh.new()
	bow.inner_radius = LENGTH * 0.11
	bow.outer_radius = LENGTH * 0.22
	bow.rings = 12
	bow.ring_segments = 6
	bow.material = brass
	var bow_instance := MeshInstance3D.new()
	bow_instance.mesh = bow
	bow_instance.position = Vector3(-LENGTH * 0.28, 0.0, 0.0)
	bow_instance.rotation.x = PI * 0.5   # ring stands up, its hole facing ±Z
	_model.add_child(bow_instance)
	var shaft := CylinderMesh.new()
	shaft.top_radius = LENGTH * 0.055
	shaft.bottom_radius = LENGTH * 0.055
	shaft.height = LENGTH * 0.7
	shaft.radial_segments = 8
	shaft.rings = 1
	shaft.material = brass
	var shaft_instance := MeshInstance3D.new()
	shaft_instance.mesh = shaft
	shaft_instance.position = Vector3(LENGTH * 0.15, 0.0, 0.0)
	shaft_instance.rotation.z = PI * 0.5
	_model.add_child(shaft_instance)
	for x in [0.46, 0.34]:
		var tooth := BoxMesh.new()
		tooth.size = Vector3(LENGTH * 0.09, LENGTH * 0.18, LENGTH * 0.07)
		tooth.material = brass
		var tooth_instance := MeshInstance3D.new()
		tooth_instance.mesh = tooth
		tooth_instance.position = Vector3(LENGTH * x, -LENGTH * 0.1, 0.0)
		_model.add_child(tooth_instance)


func _process(delta: float) -> void:
	_time += delta
	if _model and not _taken:
		_model.rotation.y += delta * 0.9
		_model.position.y = sin(_time * 1.6) * 0.04


func is_taken() -> bool:
	return _taken


func _on_body_entered(body: Node3D) -> void:
	if _taken or body is not PlayerBall:
		return
	_taken = true
	set_deferred("monitoring", false)
	Progress.set_flag("has_mystery_key")
	Sounds.ui("confirm")
	Sounds.crystal(global_position)
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3.ONE * 1.8, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_model, "scale", Vector3.ONE * 0.01, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): _model.visible = false)
	found.emit()
