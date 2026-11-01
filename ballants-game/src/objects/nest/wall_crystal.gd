@tool
class_name WallCrystal
extends Node3D
## WALL CRYSTAL -- a few amber crystal shards jutting out of the dirt with
## their own light; the nest's other lamp (see glow_fungus.gd). Decorative
## only, no collision. Local Y points out of the surface it grows from.

@export var seed := 1:
	set(v):
		seed = v
		_rebuild()
@export var size := 1.0:
	set(v):
		size = v
		_rebuild()
@export var light_energy := 1.1:
	set(v):
		light_energy = v
		_rebuild()
@export var light_range := 10.0:
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
	var material := AnthillTheme.glow_material("wall_crystal", AnthillTheme.COLORS.crystal, AnthillTheme.CRYSTAL_GLOW, 1.3)
	var count := rng.randi_range(3, 6)
	for i in count:
		var length := rng.randf_range(0.9, 1.8) * size
		var shard := CylinderMesh.new()
		shard.top_radius = 0.05 * size
		shard.bottom_radius = rng.randf_range(0.18, 0.3) * size
		shard.height = length
		shard.radial_segments = 6
		shard.rings = 1
		shard.material = material
		var instance := MeshInstance3D.new()
		instance.mesh = shard
		instance.rotation = Vector3(rng.randf_range(-0.6, 0.6), rng.randf() * TAU, rng.randf_range(-0.6, 0.6))
		instance.position = Vector3(rng.randf_range(-0.8, 0.8), 0.0, rng.randf_range(-0.8, 0.8)) * size
		instance.position += instance.basis.y * (length * 0.4)
		add_child(instance)
	var light := OmniLight3D.new()
	light.light_color = AnthillTheme.CRYSTAL_GLOW
	light.light_energy = light_energy
	light.omni_range = light_range
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	light.position = Vector3(0.0, 1.0 * size, 0.0)
	add_child(light)
