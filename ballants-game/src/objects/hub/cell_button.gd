class_name CellButton
extends Node3D
## CELL BUTTON -- a small red button on a dark plate, mounted on the inside
## wall of the jail cell (part of the hub's birthday easter egg, see
## birthday_party.gd). Local +Y points out of the wall into the room.
##
## While `armed` (the cell has been unlocked with the key) and the hero is
## within `reach`, the HUD prompts "Push the button (Space / A)"; pressing
## jump pushes it in with a click and fires `pushed`.

signal pushed

## How close the ball's center must be (meters).
@export var reach := 1.7
## Only an armed button prompts and reacts.
var armed := false

const RED := Color(0.95, 0.08, 0.05)

var _cap: MeshInstance3D
var _near := false
var _hud: Node


func _ready() -> void:
	add_to_group("cell_button")
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.22, 0.2, 0.19)
	metal.roughness = 0.5
	metal.metallic = 0.6
	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.3, 0.05, 0.3)
	plate_mesh.material = metal
	plate.mesh = plate_mesh
	plate.position = Vector3(0.0, 0.025, 0.0)
	add_child(plate)
	var rim := MeshInstance3D.new()
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = 0.1
	rim_mesh.bottom_radius = 0.105
	rim_mesh.height = 0.03
	rim_mesh.radial_segments = 14
	rim_mesh.material = metal
	rim.mesh = rim_mesh
	rim.position = Vector3(0.0, 0.065, 0.0)
	add_child(rim)
	var red := StandardMaterial3D.new()
	red.albedo_color = RED
	red.roughness = 0.4
	# A faint glow so it reads as a red button in the dim cell.
	red.emission_enabled = true
	red.emission = RED
	red.emission_energy_multiplier = 0.35
	_cap = MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.07
	cap_mesh.bottom_radius = 0.08
	cap_mesh.height = 0.07
	cap_mesh.radial_segments = 14
	cap_mesh.material = red
	_cap.mesh = cap_mesh
	_cap.position = Vector3(0.0, 0.11, 0.0)
	add_child(_cap)


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near := armed and player != null and not Game.control_locked and not Game.cutscene_active \
			and player.global_position.distance_to(global_position) < reach
	if near == _near:
		return
	_near = near
	var hud := _find_hud()
	if hud == null:
		return
	if near:
		hud.show_prompt("Push the button  (%s)" % ("A" if Controls.last_device == "controller" else "Space"))
	elif hud.prompt_text().begins_with("Push the button"):
		hud.hide_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if _near and event.is_action_pressed("jump"):
		get_viewport().set_input_as_handled()
		push()


## Pushes the button in with a click (and tells whoever listens).
func push() -> void:
	if not armed:
		return
	armed = false
	_near = false
	var hud := _find_hud()
	if hud:
		hud.hide_prompt()
	Sounds.ui("change")
	var tween := create_tween()
	tween.tween_property(_cap, "position:y", 0.08, 0.06)
	tween.tween_callback(func(): Sounds.ui("confirm"))
	tween.tween_interval(0.25)
	tween.tween_property(_cap, "position:y", 0.11, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pushed.emit()


func _find_hud() -> Node:
	if _hud == null or not is_instance_valid(_hud):
		var scene := get_tree().current_scene
		_hud = scene.find_child("HUD", true, false) if scene else null
	return _hud
