class_name Level
extends Node3D
## LEVEL -- the script every level scene uses.
##
## A level scene only needs to contain the COURSE: a StartPoint, a Goal,
## at least one FallZone, and the pieces in between (Blocks, rails, garden
## pieces, props). This script adds everything else when the level starts:
##   - the Player, placed at the StartPoint
##   - the CameraRig, HUD, tuning panel and debug overlay
##   - a huge safety-net FallZone at y = -10 if the level has none
## It also folds all Block collision into one body (see static_merger.gd).
##
## A level may still contain its own Player/CameraRig/HUD (the test arena
## does); then nothing is added.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const CAMERA_SCENE := preload("res://src/camera/orbit_camera.tscn")
const HUD_SCENE := preload("res://src/ui/hud.tscn")
const TUNING_PANEL_SCENE := preload("res://src/ui/tuning_panel.tscn")
const DEBUG_OVERLAY_SCENE := preload("res://src/ui/debug_overlay.tscn")
const FALL_ZONE_SCENE := preload("res://src/objects/fall_zone.tscn")

## Shown in the HUD when this level is not in the level list.
@export var level_name := "Untitled level"


func _ready() -> void:
	StaticMerger.merge(self)
	_ensure_player_and_camera()
	_ensure_ui()
	_ensure_fall_zone()


func _ensure_player_and_camera() -> void:
	var player := _find_first(self, PlayerBall) as PlayerBall
	var rig := find_child("CameraRig", true, false) as Node3D
	var start := _find_first(self, StartPoint) as StartPoint

	if player == null:
		player = PLAYER_SCENE.instantiate()
		player.name = "Player"
		if start:
			player.position = start.global_position + Vector3.UP * 0.6
		add_child(player)
	if rig == null:
		rig = CAMERA_SCENE.instantiate()
		rig.name = "CameraRig"
		rig.target = player
		add_child(rig)
		if start:
			rig.aim(start.global_rotation.y, deg_to_rad(Tuning.camera_pitch_default))
	if player.camera_rig == null:
		player.camera_rig = rig


func _ensure_ui() -> void:
	if find_child("HUD", true, false) == null:
		var hud := HUD_SCENE.instantiate()
		hud.name = "HUD"
		add_child(hud)
	if find_child("TuningPanel", true, false) == null:
		var panel := TUNING_PANEL_SCENE.instantiate()
		panel.name = "TuningPanel"
		add_child(panel)
	if find_child("DebugOverlay", true, false) == null:
		var overlay := DEBUG_OVERLAY_SCENE.instantiate()
		overlay.name = "DebugOverlay"
		add_child(overlay)


func _ensure_fall_zone() -> void:
	if _find_first(self, FallZone) != null:
		return
	var zone := FALL_ZONE_SCENE.instantiate()
	zone.name = "SafetyNetFallZone"
	zone.position = Vector3(0, -10, 0)
	add_child(zone)


static func _find_first(node: Node, type) -> Node:
	if is_instance_of(node, type):
		return node
	for child in node.get_children():
		var found := _find_first(child, type)
		if found:
			return found
	return null
