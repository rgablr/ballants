class_name VoiceSynth
extends Node
## VOICE SYNTH -- the babbly "jibber" a character makes while its line
## types out, like the talking animals in Animal Crossing. Nothing is
## recorded or AI-made: each blip is a short pitched tone computed here
## (a sine with a couple of harmonics, a little pitch glide and a quick
## fade), in a handful of pitch steps. While text types, every few letters
## one blip plays, its step chosen by the letter (vowels higher) plus a
## random nudge, so the same line always babbles about the same way.
##
## The voice block in cutscenes/characters.json sets pitch, how often a
## blip plays ("every" letters), how far the pitch wanders ("variation"),
## the blip length, the wave ("soft" or "buzz" for a gruffer voice) and
## loudness. Defaults are in CutsceneStyle.VOICE_DEFAULTS.

const STEPS := 7            # pitch steps available, centred on the voice's pitch
const STEP_RATIO := 1.149   # one step = a fifth of an octave
const RATE := 22050

var _config := {}
var _blips: Array[AudioStreamWAV] = []
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _letters_since := 99


func _init(config: Dictionary) -> void:
	_config = CutsceneStyle.VOICE_DEFAULTS.duplicate()
	for key in config:
		_config[key] = config[key]
	for i in STEPS:
		var ratio := pow(STEP_RATIO, i - STEPS / 2)
		_blips.append(_make_blip(CutsceneStyle.VOICE_BASE_HZ * float(_config.pitch) * ratio))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 3:
		var player := AudioStreamPlayer.new()
		player.bus = Sounds.SFX_BUS
		player.volume_db = float(_config.volume_db)
		add_child(player)
		_players.append(player)


## Called for every character as it appears. Plays a blip every "every"
## letters (spaces and punctuation don't count, and dots stay silent).
func on_letter(ch: String) -> void:
	if not _is_letter(ch):
		return
	_letters_since += 1
	if _letters_since < int(_config.every):
		return
	_letters_since = 0
	var middle := STEPS / 2
	var step := middle
	if ch.to_lower() in "aeiouy":
		step += 1
	step += int(round(randf_range(-1.0, 1.0) * float(_config.variation)))
	step = clampi(step, 0, STEPS - 1)
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _blips[step]
	player.pitch_scale = randf_range(0.96, 1.04)
	player.play()


## A new line starts: the first letter blips at once.
func reset() -> void:
	_letters_since = 99


static func _is_letter(ch: String) -> bool:
	return ch.length() == 1 and (ch.to_lower() != ch.to_upper() or ch.is_valid_int())


## One blip at a frequency: a tone with a gentle glide, harmonics for body,
## a soft attack and a fade to nothing.
func _make_blip(frequency: float) -> AudioStreamWAV:
	var length := float(_config.length)
	var buzz := str(_config.wave) == "buzz"
	var count := int(RATE * length)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var glide_dir := 1.0 if randf() < 0.5 else -1.0
	for i in count:
		var t := float(i) / count
		# The pitch slides about 8% over the blip, up or down.
		var f := frequency * (1.0 + glide_dir * 0.08 * (t - 0.5))
		phase += f / RATE
		var v := sin(TAU * phase)
		if buzz:
			# Odd harmonics make it rougher and lower-sounding.
			v += 0.45 * sin(TAU * phase * 3.0) + 0.2 * sin(TAU * phase * 5.0)
			v *= 0.65
		else:
			v += 0.3 * sin(TAU * phase * 2.0)
			v *= 0.8
		var attack := minf(t / 0.08, 1.0)
		var release := 1.0 - smoothstep(0.35, 1.0, t)
		v *= attack * release
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
