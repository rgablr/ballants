@tool
class_name GlowFungus
extends Node3D
## GLOW FUNGUS -- a cluster of three to five glowing mushrooms with one warm
## light, the nest's lamp. Purely decorative (no collision): put one every
## 10-15 m along a path and the way is readable in the dark. Local Y is
## "up off the surface", so tilt the node to grow it out of a wall.
##
## `amber` (default) is the hub's orange glow; off = a cool blue-white
## variety for contrast (good for marking a hidden spot or a shortcut).

@export var seed := 1:
	set(v):
		seed = v
		_rebuild()
@export var amber := true:
	set(v):
		amber = v
		_rebuild()
## Overall size (1 = the hub's clusters).
@export var size := 1.0:
	set(v):
		size = v
		_rebuild()
@export var light_energy := 1.5:
	set(v):
		light_energy = v
		_rebuild()
@export var light_range := 12.0:
	set(v):
		light_range = v
		_rebuild()

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
	var glow := AnthillTheme.FUNGUS_GLOW if amber else AnthillTheme.FUNGUS_BLUE_GLOW
	var cap_material := AnthillTheme.glow_material("fungus_amber" if amber else "fungus_blue",
			AnthillTheme.COLORS.fungus_cap if amber else AnthillTheme.COLORS.fungus_blue_cap, glow, 0.9)
	var stem_material := AnthillTheme.material("fungus_stem")
	var count := rng.randi_range(3, 5)
	for i in count:
		var s := rng.randf_range(0.5, 1.1) * size
		var offset := Vector3(rng.randf_range(-1.2, 1.2), 0.0, rng.randf_range(-1.2, 1.2)) * size
		var stem := CylinderMesh.new()
		stem.top_radius = 0.08 * s
		stem.bottom_radius = 0.13 * s
		stem.height = 0.5 * s
		stem.radial_segments = 7
		stem.rings = 1
		stem.material = stem_material
		var stem_instance := MeshInstance3D.new()
		stem_instance.mesh = stem
		stem_instance.position = offset + Vector3(0.0, stem.height * 0.5 - 0.05, 0.0)
		stem_instance.rotation = Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25))
		add_child(stem_instance)
		var cap := SphereMesh.new()
		cap.radius = 0.35 * s
		cap.height = 0.7 * s
		cap.radial_segments = 9
		cap.rings = 4
		cap.material = cap_material
		var cap_instance := MeshInstance3D.new()
		cap_instance.mesh = cap
		cap_instance.scale = Vector3(1.0, 0.55, 1.0)
		cap_instance.position = stem_instance.position + Vector3(0.0, stem.height * 0.5, 0.0)
		cap_instance.rotation = stem_instance.rotation
		add_child(cap_instance)
	var light := OmniLight3D.new()
	light.light_color = glow
	light.light_energy = light_energy
	light.omni_range = light_range
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	light.position = Vector3(0.0, 1.0 * size, 0.0)
	add_child(light)
