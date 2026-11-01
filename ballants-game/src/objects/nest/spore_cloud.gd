@tool
class_name SporeCloud
extends GPUParticles3D
## SPORE CLOUD -- pale, softly glowing spores drifting slowly upward and
## sideways through a box of air. Decoration only (no collision, nothing
## to do with play): scatter a few over a fungus garden, and SporePatch
## uses one to show where the floor is slick.
##
## `size` is the box the spores start in (centered on the node, but the
## bottom of the box sits at the node's origin); they rise `drift_height`
## over their lifetime and fade in and out. The random pattern uses a
## fixed seed, so it looks the same every run.

@export var size := Vector3(10.0, 3.0, 10.0):
	set(v):
		size = v
		_setup()
@export var spore_count := 60:
	set(v):
		spore_count = v
		_setup()
@export var color := Color(0.82, 1.0, 0.78):
	set(v):
		color = v
		_setup()
@export var glow := 1.4:
	set(v):
		glow = v
		_setup()
## Spore size in meters.
@export var spore_size := 0.05:
	set(v):
		spore_size = v
		_setup()
## Meters the spores rise over their life.
@export var drift_height := 1.6:
	set(v):
		drift_height = v
		_setup()
@export var spore_seed := 1:
	set(v):
		spore_seed = v
		_setup()

var _ready_done := false


func _ready() -> void:
	_ready_done = true
	_setup()


func _setup() -> void:
	if not _ready_done:
		return
	amount = maxi(spore_count, 1)
	lifetime = 6.0
	preprocess = 6.0
	explosiveness = 0.0
	randomness = 0.6
	local_coords = true
	use_fixed_seed = true
	seed = spore_seed
	visibility_aabb = AABB(Vector3(-size.x * 0.5 - 1.0, -0.5, -size.z * 0.5 - 1.0),
			Vector3(size.x + 2.0, size.y + drift_height + 1.5, size.z + 2.0))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mesh := SphereMesh.new()
	mesh.radius = spore_size
	mesh.height = spore_size * 2.0
	mesh.radial_segments = 4
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = glow
	mesh.material = mat
	draw_pass_1 = mesh

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(size.x * 0.5, size.y * 0.5, size.z * 0.5)
	process.emission_shape_offset = Vector3(0.0, size.y * 0.5, 0.0)
	process.direction = Vector3.UP
	process.spread = 60.0
	var speed := drift_height / lifetime
	process.initial_velocity_min = speed * 0.5
	process.initial_velocity_max = speed * 1.5
	process.gravity = Vector3(0.0, 0.0, 0.0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.4
	process.turbulence_noise_scale = 3.0
	process.turbulence_influence_min = 0.05
	process.turbulence_influence_max = 0.12
	process.scale_min = 0.6
	process.scale_max = 1.4
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture
	process_material = process
	emitting = true
