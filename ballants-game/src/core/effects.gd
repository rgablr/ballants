extends Node
## EFFECTS -- the "juice": visible feedback for impacts.
##
## Anything can call Effects.impact(strength, direction, position). Based on
## how hard the hit was (see impact_small / impact_big in the tuning file):
##   small  ->  a puff of dust at the contact point
##   big    ->  dust + screen shake + a few frames of freeze (hit-pause)
## Sounds go through the Sounds global, which is a set of empty hooks for now.
##
## Loaded as a global called "Effects".

const BURST_SCENE := preload("res://src/effects/impact_burst.tscn")

var _pausing := false


func impact(strength: float, direction: Vector3, position: Vector3) -> void:
	var big := strength >= Tuning.impact_big
	_burst(position, direction, strength, big)
	Sounds.impact(strength, position)
	if big:
		for rig in get_tree().get_nodes_in_group("camera_rig"):
			if rig.has_method("shake"):
				rig.shake(Tuning.shake_strength * clampf(strength / (Tuning.impact_big * 2.0), 0.5, 1.5))
		hit_pause(Tuning.hit_pause)


## Freezes the whole game for a moment. Uses real time, so it is immune to
## its own slow-down.
func hit_pause(duration: float) -> void:
	if duration <= 0.0 or _pausing:
		return
	_pausing = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_pausing = false


func _burst(position: Vector3, direction: Vector3, strength: float, big: bool) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var burst := BURST_SCENE.instantiate()
	scene.add_child(burst)
	burst.global_position = position
	if burst.has_method("play"):
		burst.play(direction, strength, big)
