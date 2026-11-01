class_name StorageGate
extends Node3D
## STORAGE GATE -- a slab of packed dirt that slides sideways across a
## doorway on a fixed rhythm: open, slide shut, stay shut, slide open,
## over and over. Solid when shut (it is a moving body, so it also shoves
## the ball if you are caught in the doorway as it closes).
##
## The rhythm comes from the physics config, so the F1 panel tunes it:
##   storage_gate_period         seconds for one full open-and-shut cycle
##   storage_gate_open_fraction  part of the cycle it is FULLY open
##   storage_gate_slide_time     seconds each slide takes
## Time is the level's worker clock (see WorkerLine.clock_start: physics
## steps since the level loaded, restarted by a restart), so the door is
## in step with the worker lines and the same every run. `phase` (0..1)
## shifts this door's cycle.
##
## Local space: the doorway is centered on the origin, floor at y = 0, the
## door's face is across local Z (you roll through along -Z). It slides
## toward +X by `width` into the wall beside it, so put a wall at least
## `width` long on the +X side to hide it when open. Two lamps on the
## lintel glow while it is open and flicker just before it opens.

@export var width := 4.0
@export var height := 3.0
@export var thickness := 0.6
@export_range(0.0, 1.0) var phase := 0.0
@export var seed := 5

var _door: AnimatableBody3D
var _clock_start := 0
var _lamps: Array[OmniLight3D] = []
var _lamp_material: StandardMaterial3D


func _ready() -> void:
	_clock_start = WorkerLine.clock_start(self)
	_build()
	_place(true)


func period() -> float:
	return maxf(Tuning.storage_gate_period, 0.5)


func _open_fraction() -> float:
	return clampf(Tuning.storage_gate_open_fraction, 0.05, 0.95)


func _slide() -> float:
	return clampf(Tuning.storage_gate_slide_time, 0.05, period() * 0.45)


## Level-clock time (mod period) of the middle of an open window.
func mid_open_time() -> float:
	return fposmod((_open_fraction() * 0.5 - phase) * period(), period())


## How open the door is right now: 0 shut, 1 fully open.
func openness() -> float:
	return openness_at(WorkerLine.clock(self, _clock_start))


func openness_at(t: float) -> float:
	var p := period()
	var u := fposmod(t / p + phase, 1.0) * p      # seconds into the cycle
	var open_time := _open_fraction() * p
	var slide := _slide()
	if u < open_time:
		return 1.0
	if u < open_time + slide:
		return 1.0 - smoothstep(0.0, 1.0, (u - open_time) / slide)
	if u > p - slide:
		return smoothstep(0.0, 1.0, (u - (p - slide)) / slide)
	return 0.0


func _physics_process(_delta: float) -> void:
	_place(false)


func _place(snap: bool) -> void:
	var t := WorkerLine.clock(self, _clock_start)
	var o := openness_at(t)
	_door.position = Vector3(o * width, 0.0, 0.0)
	if snap:
		_door.reset_physics_interpolation()
	# Lamps: lit while open, a warning flicker in the second before opening.
	var p := period()
	var u := fposmod(t / p + phase, 1.0) * p
	var warn := u > p - _slide() - 1.0 and u < p - _slide()
	var glow := o
	if warn:
		glow = 0.35 if fmod(u * 6.0, 1.0) < 0.5 else 0.05
	for lamp in _lamps:
		lamp.light_energy = 0.15 + glow * 2.0
	if _lamp_material:
		_lamp_material.emission_energy_multiplier = 0.3 + glow * 3.0


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_door = AnimatableBody3D.new()
	_door.name = "Door"
	_door.sync_to_physics = true
	add_child(_door)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, thickness)
	shape.shape = box
	shape.position = Vector3(0.0, height * 0.5, 0.0)
	_door.add_child(shape)
	var slab := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	mesh.material = AnthillTheme.material("packed")
	slab.mesh = mesh
	slab.position = shape.position
	_door.add_child(slab)
	# Lumps and clay bands on both faces, and two cross-braces of root.
	var dark := AnthillTheme.material("dirt_dark")
	var clay := AnthillTheme.material("clay")
	var root := AnthillTheme.material("root")
	for i in 9:
		var face := 1.0 if i % 2 == 0 else -1.0
		var p := Vector3(rng.randf_range(-width * 0.42, width * 0.42), rng.randf_range(0.3, height - 0.3), face * thickness * 0.5)
		CritterParts.sphere(_door, p, rng.randf_range(0.2, 0.38), Vector3(1.3, 0.8, 0.35),
				clay if rng.randf() < 0.3 else dark, 7)
	for face in [1.0, -1.0]:
		var z: float = face * (thickness * 0.5 + 0.06)
		CritterParts.rod(_door, Vector3(-width * 0.45, 0.4, z), Vector3(width * 0.45, height - 0.4, z), 0.09, root)
		CritterParts.rod(_door, Vector3(-width * 0.45, height - 0.4, z), Vector3(width * 0.45, 0.4, z), 0.09, root)
	# The lintel over the doorway (decoration: the walls beside it carry it).
	var lintel := MeshInstance3D.new()
	var beam := BoxMesh.new()
	beam.size = Vector3(width + 1.6, 0.7, thickness + 0.9)
	beam.material = AnthillTheme.material("dirt_dark")
	lintel.mesh = beam
	lintel.position = Vector3(0.0, height + 0.35, 0.0)
	add_child(lintel)
	_lamp_material = AnthillTheme.glow_material("storage_gate_lamp", Color(1.0, 0.8, 0.45), AnthillTheme.FUNGUS_GLOW, 1.0).duplicate() as StandardMaterial3D
	for side in [-1.0, 1.0]:
		var bulb := CritterParts.sphere(self, Vector3(side * (width * 0.5 + 0.3), height + 0.75, thickness * 0.5 + 0.5),
				0.22, Vector3.ONE, _lamp_material, 8)
		bulb.name = "Lamp"
		var light := OmniLight3D.new()
		light.light_color = AnthillTheme.FUNGUS_GLOW
		light.omni_range = 7.0
		light.shadow_enabled = false
		light.position = bulb.position + Vector3(0.0, -0.2, 0.4)
		add_child(light)
		_lamps.append(light)
