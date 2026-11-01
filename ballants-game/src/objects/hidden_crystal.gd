@tool
class_name HiddenCrystal
extends Area3D
## HIDDEN CRYSTAL -- one of the two sugar crystals hidden in every level.
## Drop hidden_crystal.tscn anywhere in a level and set `which` (0 = the
## level's first hidden crystal, 1 = the second). It glows, turns slowly
## and bobs; roll through it and it is yours: a chime (made in code), a
## burst of sparkles, and the crystal shrinks away.
##
## Crystals count once. If this one was collected on an earlier run it
## shows as a faded GHOST: no glow, no light, still turning, and you can
## roll straight through it (nothing happens). Progress keeps the record
## (see src/core/progress.gd); which level this is comes from the level
## manager, so the piece needs no setup beyond `which`.
##
## The pickup zone is a sphere a little wider than the crystal so a ball
## brushing past still gets it. The crystal is never solid.

## 0 = the level's first hidden crystal, 1 = the second.
@export_range(0, 1) var which := 0
## Size of the crystal in meters (tip to tip is about 2x this).
@export var size := 0.9
## How far the ball's center may be from the middle and still collect it.
@export var pickup_radius := 1.3

const COLOR := Color(0.85, 0.97, 1.0)
const GLOW := Color(0.55, 0.85, 1.0)
const GHOST_ALPHA := 0.28

var ghost := false
var _taken := false
var _crystal: Node3D
var _shape: CollisionShape3D
var _time := 0.0
var _spin := 1.1


func _ready() -> void:
	add_to_group("hidden_crystal")
	_crystal = TunnelEntrance.make_crystal(size)
	_crystal.position.y = size * 1.1
	add_child(_crystal)
	_shape = CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = pickup_radius
	_shape.shape = sphere
	_shape.position.y = size * 1.1
	add_child(_shape)
	monitoring = true
	monitorable = false
	if Engine.is_editor_hint():
		return
	# Start the bob at a different phase per crystal so two never move in
	# step (purely from where it sits, so it is the same every run).
	_time = fmod(absf(global_position.x + global_position.z * 3.0), 10.0)
	ghost = Progress.has_crystal(Levels.current_index, Progress.SLOT_HIDDEN_A + which)
	if ghost:
		_make_ghost()
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	if _crystal:
		_crystal.rotation.y += delta * _spin
		_crystal.position.y = size * 1.1 + sin(_time * 1.8) * 0.12


## Faded, unlit, no light: the crystal you already have.
func _make_ghost() -> void:
	for child in _crystal.get_children():
		if child is OmniLight3D:
			child.queue_free()
		elif child is MeshInstance3D:
			var mesh := child as MeshInstance3D
			var faded := StandardMaterial3D.new()
			faded.albedo_color = Color(COLOR.r, COLOR.g, COLOR.b, GHOST_ALPHA)
			faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			faded.roughness = 0.6
			faded.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.material_override = faded
	_spin = 0.6


func _on_body_entered(body: Node3D) -> void:
	if _taken or ghost or body is not PlayerBall:
		return
	if Levels.current_index < 0:
		return   # not in a listed level: nothing to award
	_taken = true
	var is_new := Progress.collect_hidden(Levels.current_index, which)
	if not is_new:
		return
	_celebrate()


## The chime, the sparkle burst, and the crystal shrinking away.
func _celebrate() -> void:
	set_deferred("monitoring", false)
	Sounds.crystal(global_position)
	_sparkles()
	var tween := create_tween()
	tween.tween_property(_crystal, "scale", Vector3.ONE * 1.5, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_crystal, "scale", Vector3.ONE * 0.01, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): _crystal.visible = false)


## A one-shot burst of small glowing shards flying out and falling.
func _sparkles() -> void:
	var particles := GPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 26
	particles.lifetime = 0.8
	particles.local_coords = false
	particles.position = _crystal.position
	var shard := PrismMesh.new()
	shard.size = Vector3(0.12, 0.2, 0.12)
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR
	material.emission_enabled = true
	material.emission = GLOW
	material.emission_energy_multiplier = 2.5
	shard.material = material
	particles.draw_pass_1 = shard
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = 3.0
	process.initial_velocity_max = 6.0
	process.gravity = Vector3(0.0, -Tuning.gravity * 0.6, 0.0)
	process.damping_min = 1.5
	process.damping_max = 3.0
	process.angular_velocity_min = -400.0
	process.angular_velocity_max = 400.0
	process.scale_min = 0.5
	process.scale_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture
	particles.process_material = process
	add_child(particles)
	particles.emitting = true
	# A flash of light that dies down.
	var light := OmniLight3D.new()
	light.light_color = GLOW
	light.light_energy = 4.0
	light.omni_range = 6.0
	light.shadow_enabled = false
	light.position = _crystal.position
	add_child(light)
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.6)
	tween.tween_callback(light.queue_free)
	get_tree().create_timer(particles.lifetime + 0.3).timeout.connect(particles.queue_free)
