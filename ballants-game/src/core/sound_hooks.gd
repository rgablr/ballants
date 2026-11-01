extends Node
## SOUNDS -- every sound effect in the game goes through here. Game code
## says what happened ("the ball jumped", "a menu row changed") and this
## picks the clip, its loudness and pitch. Clips are looked up by nickname
## in the asset manifest's SOUNDS table, so swapping a sound never touches
## this file.
##
## Two mixer channels ("buses") are set up here: SFX for sound effects and
## Music for the songs (see music.gd). Each can be turned down on its own.
##
## Three sounds are made in code rather than recorded: the rolling rumble
## (soft filtered noise), the bees' buzz (a wobbly hum) and the low, uneasy
## drone that fades in when an enemy is near. All plain math, like the
## placeholder models.
##
## Loaded as a global called "Sounds".

const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"
const VOICES := 12          # how many sounds can play at once
## The roll rumble: loudest at a medium roll, easing back off toward top
## speed so it never drowns out everything else.
const LOUDEST_ROLL_DB := -24.0
const TOP_SPEED_ROLL_DB := -29.0
const QUIETEST_ROLL_DB := -42.0
## The enemy drone: silent beyond FAR meters from the nearest enemy, at its
## loudest within NEAR meters.
const DREAD_FAR := 13.0
const DREAD_NEAR := 3.0
const DREAD_LOUDEST_DB := -15.0

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _roll: AudioStreamPlayer
var _roll_target := QUIETEST_ROLL_DB
var _roll_pitch := 1.0
var _roll_fed_at := -1.0   # when rolling() was last called
var _last_thud := -1.0      # time of the last bump/landing, so one touch-down
                            # doesn't play both a bump and a landing
var _buzz: AudioStreamWAV
var _dread: AudioStreamPlayer
var _dread_target := -80.0
var _bumped := {}           # critter id -> time it last made its bump sound


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # menu clicks play while paused
	_make_bus(SFX_BUS)
	_make_bus(MUSIC_BUS)
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = SFX_BUS
		add_child(voice)
		_voices.append(voice)
	_roll = AudioStreamPlayer.new()
	_roll.bus = SFX_BUS
	_roll.stream = _make_rumble()
	_roll.volume_db = QUIETEST_ROLL_DB
	_roll.process_mode = Node.PROCESS_MODE_PAUSABLE   # hush while paused
	add_child(_roll)
	_dread = AudioStreamPlayer.new()
	_dread.bus = SFX_BUS
	_dread.stream = _make_dread()
	_dread.volume_db = -80.0
	_dread.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_dread)


func _make_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


## Plays a sound by its manifest nickname. volume_db 0 is the clip as
## recorded; -6 is about half as loud. pitch 1.0 is normal.
func play(nickname: String, volume_db := 0.0, pitch := 1.0) -> void:
	var stream := Assets.sound(nickname)
	if stream == null:
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = pitch
	voice.play()


## Plays a sound from a spot in the world: louder close by, fading with
## distance. The player is followed closely by the camera, so the player's
## own sounds use play() instead.
func play_at(nickname: String, position: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	var stream := Assets.sound(nickname)
	var scene := get_tree().current_scene
	if stream == null or scene == null:
		return
	var voice := AudioStreamPlayer3D.new()
	voice.bus = SFX_BUS
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = pitch
	voice.unit_size = 4.0
	voice.max_distance = 30.0
	scene.add_child(voice)
	voice.global_position = position
	voice.finished.connect(voice.queue_free)
	voice.play()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _vary() -> float:
	return randf_range(0.92, 1.08)


## A collision: strength is the sudden speed change in m/s.
func impact(strength: float, _position: Vector3) -> void:
	if _now() - _last_thud < 0.08:
		return
	_last_thud = _now()
	var loud := clampf(inverse_lerp(Tuning.impact_small, Tuning.impact_big * 1.5, strength), 0.0, 1.0)
	if strength >= Tuning.impact_big:
		play("thud", lerpf(-6.0, 0.0, loud), _vary())
	else:
		play("bump", lerpf(-18.0, -6.0, loud), _vary())


## The ball left the ground on purpose.
func jump() -> void:
	play("jump", -14.0, _vary())


## The ball touched down; fall_speed is how fast it was falling (m/s).
func land(fall_speed: float) -> void:
	if fall_speed < 1.5 or _now() - _last_thud < 0.08:
		return
	_last_thud = _now()
	if fall_speed > 7.0:
		play("thud", -4.0, _vary())
	else:
		play("land", lerpf(-16.0, -5.0, clampf(fall_speed / 7.0, 0.0, 1.0)), _vary())


## The ball crossed into an ant hill's hole.
func goal() -> void:
	play("hill_drop", -6.0)


## An enemy knocked the ant off the ball.
func hit() -> void:
	play("hit", 0.0, _vary())
	play("hit_tone", -8.0)


## Back at the spawn after being knocked off.
func respawn() -> void:
	play("respawn", -8.0)


## Bumped into a friendly bug: a bouncy plip from where it is.
func critter_bump(position: Vector3) -> void:
	play_at("critter_bump", position, -2.0, randf_range(1.1, 1.45))


## For bugs the ball can roll into: call every step with the bug's middle
## and size. Plays the bump sound when the ball touches it (at most once a
## second per bug).
func critter_touch(critter: Node, point: Vector3, radius: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or player.global_position.distance_to(point) > radius + 0.5:
		return
	var id := critter.get_instance_id()
	if _now() - float(_bumped.get(id, -10.0)) < 1.0:
		return
	_bumped[id] = _now()
	critter_bump(point)


## A blade of thick grass snapped.
func grass_snap(position: Vector3) -> void:
	play_at("grass", position, -2.0, randf_range(1.2, 1.5))


## An enemy noticed the player and is winding up to attack.
func enemy_warn(position: Vector3) -> void:
	play_at("warn", position, 2.0, randf_range(0.9, 1.1))


## Menus: "open", "close", "move" (to another row), "change" (a value).
func ui(what: String) -> void:
	match what:
		"open": play("menu_open", -6.0)
		"close": play("menu_close", -6.0)
		"move": play("menu_move", -10.0)
		"change": play("menu_change", -6.0, _vary())
		"confirm": play("confirm", -6.0)


## The results cards. The music dips out of the way for the jingle.
func level_complete() -> void:
	Music.duck(2.5)
	play("level_complete", -4.0)


func world_complete() -> void:
	Music.duck(3.0)
	play("world_complete", -4.0)


## Called every physics step with the ball's rolling speed; drives the
## looping roll rumble (louder and higher the faster you go, silent in the
## air).
func rolling(speed: float, grounded: bool) -> void:
	_roll_fed_at = _now()
	var amount := clampf(speed / Tuning.max_speed, 0.0, 1.2) if grounded else 0.0
	if amount <= 0.03:
		_roll_target = -80.0
	elif amount < 0.45:
		_roll_target = lerpf(QUIETEST_ROLL_DB, LOUDEST_ROLL_DB, sqrt(amount / 0.45))
	else:
		_roll_target = lerpf(LOUDEST_ROLL_DB, TOP_SPEED_ROLL_DB, minf((amount - 0.45) / 0.55, 1.0))
	_roll_pitch = lerpf(0.6, 1.15, minf(amount, 1.2) / 1.2)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _now() - _roll_fed_at > 0.1:
		_roll_target = -80.0   # nobody is rolling (ball sinking, scene change)
	if _roll_target > -60.0 and not _roll.playing:
		_roll.play()
	_roll.volume_db = lerpf(_roll.volume_db, _roll_target, 1.0 - exp(-delta * 12.0))
	_roll.pitch_scale = lerpf(_roll.pitch_scale, _roll_pitch, 1.0 - exp(-delta * 8.0))
	if _roll.playing and _roll.volume_db < -60.0:
		_roll.stop()
	_update_dread(delta)


## Fades the drone with the distance to the nearest enemy.
func _update_dread(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var nearest := INF
	if player and not Game.level_complete:
		for enemy in get_tree().get_nodes_in_group("enemy"):
			var flat := Vector2(enemy.global_position.x - player.global_position.x,
					enemy.global_position.z - player.global_position.z)
			nearest = minf(nearest, flat.length())
	var close := clampf(inverse_lerp(DREAD_FAR, DREAD_NEAR, nearest), 0.0, 1.0) if nearest < INF else 0.0
	_dread_target = lerpf(-50.0, DREAD_LOUDEST_DB, close) if close > 0.0 else -80.0
	if _dread_target > -60.0 and not _dread.playing:
		_dread.play()
	_dread.volume_db = lerpf(_dread.volume_db, _dread_target, 1.0 - exp(-delta * 2.5))
	if _dread.playing and _dread.volume_db < -62.0:
		_dread.stop()


var _crystal_chime: AudioStreamWAV

## Picking up a hidden sugar crystal: a bright three-note rising chime
## with a glassy shimmer, made in code (no recording).
func crystal(position: Vector3) -> void:
	if _crystal_chime == null:
		_crystal_chime = _make_crystal_chime()
	var scene := get_tree().current_scene
	if scene == null:
		return
	var voice := AudioStreamPlayer3D.new()
	voice.bus = SFX_BUS
	voice.stream = _crystal_chime
	voice.volume_db = -4.0
	voice.unit_size = 6.0
	voice.max_distance = 40.0
	scene.add_child(voice)
	voice.global_position = position
	voice.finished.connect(voice.queue_free)
	voice.play()


func _make_crystal_chime() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 0.9
	var count := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	# Three notes a major third and a fifth apart, each ringing on under
	# the next, with a high sparkle over the top.
	var notes := [[0.0, 880.0], [0.09, 1108.7], [0.18, 1318.5]]
	for i in count:
		var t := float(i) / rate
		var v := 0.0
		for note in notes:
			var start: float = note[0]
			if t < start:
				continue
			var u := t - start
			var f: float = note[1]
			var env := minf(u / 0.012, 1.0) * exp(-u * 4.5)
			v += (sin(TAU * f * u) + 0.35 * sin(TAU * f * 2.0 * u) + 0.12 * sin(TAU * f * 3.0 * u)) * env * 0.3
		var sparkle := sin(TAU * 3520.0 * t) * exp(-t * 7.0) * 0.08 * (0.5 + 0.5 * sin(TAU * 28.0 * t))
		v += sparkle
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	return _wav(data, rate)


## One second of soft, low "brown" noise that loops seamlessly: a ball
## rolling over grass and dirt.
func _make_rumble() -> AudioStreamWAV:
	var rate := 22050
	var data := PackedByteArray()
	data.resize(rate * 2)
	var brown := 0.0
	var smooth := 0.0
	var samples := PackedFloat32Array()
	samples.resize(rate)
	for i in rate:
		brown = clampf(brown * 0.995 + randf_range(-1.0, 1.0) * 0.08, -1.0, 1.0)
		smooth = lerpf(smooth, brown, 0.25)
		samples[i] = smooth
	# Cross-fade the end into the start so the loop has no click.
	var blend := 2000
	for i in blend:
		var t := float(i) / blend
		samples[i] = lerpf(samples[rate - blend + i], samples[i], t)
	for i in rate:
		data.encode_s16(i * 2, int(clampf(samples[i] * 2.2, -1.0, 1.0) * 32000.0))
	return _wav(data, rate)


## The enemy drone: four seconds of low, slowly beating tones a tritone
## apart (the classic "uneasy" interval), swelling and fading, looping
## seamlessly. Every frequency is a multiple of 0.25 Hz so the loop closes.
func _make_dread() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 4
	var count := rate * seconds
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		var swell := 0.75 + 0.25 * sin(TAU * t / seconds)
		var low := sin(TAU * 110.0 * t) + sin(TAU * 110.5 * t)       # slow beating
		var uneasy := sin(TAU * 155.5 * t) * 0.6                     # a tritone up
		var shimmer := sin(TAU * 311.0 * t) * 0.15 * (0.5 + 0.5 * sin(TAU * 0.75 * t))
		var v := (low * 0.5 + uneasy + shimmer) * 0.32 * swell
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var wav := _wav(data, rate)
	wav.loop_end = count
	return wav


## A bee's buzz: a looping hum with a slight wobble. Shared by every bee.
func buzz_stream() -> AudioStreamWAV:
	if _buzz:
		return _buzz
	var rate := 22050
	var data := PackedByteArray()
	data.resize(rate * 2)
	var phase := 0.0
	for i in rate:
		var t := float(i) / rate
		# 4 wobbles per second loop exactly in one second.
		var freq := 210.0 + 12.0 * sin(TAU * 4.0 * t)
		phase = fmod(phase + freq / rate, 1.0)
		var saw := phase * 2.0 - 1.0
		var hum := saw * 0.6 + sin(TAU * phase * 2.0) * 0.25
		data.encode_s16(i * 2, int(hum * 0.5 * 32000.0))
	_buzz = _wav(data, rate)
	return _buzz


func _wav(data: PackedByteArray, rate: int) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = rate
	return wav
