class_name BirthdaySong
extends RefCounted
## BIRTHDAY SONG -- "Happy Birthday to You", whose melody is in the public
## domain, arranged and rendered entirely in code as a little oom-pah-pah
## dance band: a lead voice, a waltz bass with chord stabs on beats 2 and
## 3, a kick drum, hand claps and a hi-hat. No recording is involved; it is
## plain math, like the crystal chime and the roll rumble in sound_hooks.gd.
##
##   var song := BirthdaySong.render()   # the party runs this on a worker
##                                       # thread and keeps the result
##
## Timing, for anything that moves to the beat (the song is in 3/4):
##   INTRO_BEATS of drums alone, then VERSES verses of VERSE_BEATS beats
##   (from one "Hap-py" pickup to the next), then TAIL_BEATS of the final
##   chord. FIRST_DOWNBEAT is the beat of bar 1; the pickup is the beat
##   before it.

const BPM := 132.0
const RATE := 22050
const INTRO_BEATS := 8
const VERSE_BEATS := 24
const VERSES := 2
const TAIL_BEATS := 4
const FIRST_DOWNBEAT := INTRO_BEATS + 1

## The tune: [beat from the pickup, MIDI note, length in beats].
## (G4 = 67, C5 = 72.)  "Hap-py birth-day to you" ... "dear Mar-tha" ...
const MELODY := [
	[0.0, 67, 0.5], [0.5, 67, 0.5],                   # Hap-py
	[1.0, 69, 1.0], [2.0, 67, 1.0], [3.0, 72, 1.0],   # birth-day to
	[4.0, 71, 2.0],                                    # you
	[6.0, 67, 0.5], [6.5, 67, 0.5],                   # Hap-py
	[7.0, 69, 1.0], [8.0, 67, 1.0], [9.0, 74, 1.0],   # birth-day to
	[10.0, 72, 2.0],                                   # you
	[12.0, 67, 0.5], [12.5, 67, 0.5],                 # Hap-py
	[13.0, 79, 1.0], [14.0, 76, 1.0], [15.0, 72, 1.0], # birth-day dear
	[16.0, 71, 1.0], [17.0, 69, 1.0],                 # Mar-tha
	[18.0, 77, 0.5], [18.5, 77, 0.5],                 # Hap-py
	[19.0, 76, 1.0], [20.0, 72, 1.0], [21.0, 74, 1.0], # birth-day to
	[22.0, 72, 2.0],                                   # you
]
## The band: [beat from the pickup, length in beats, bass root (C3 = 48),
## chord intervals above the root].
const CHORDS := [
	[1, 3, 48, [0, 4, 7]], [4, 3, 55, [0, 4, 7, 10]], [7, 3, 55, [0, 4, 7, 10]],
	[10, 3, 48, [0, 4, 7]], [13, 3, 48, [0, 4, 7, 10]], [16, 3, 53, [0, 4, 7]],
	[19, 2, 48, [0, 4, 7]], [21, 1, 55, [0, 4, 7, 10]], [22, 2, 48, [0, 4, 7]],
]

static func beats() -> int:
	return INTRO_BEATS + VERSES * VERSE_BEATS + TAIL_BEATS


static func seconds_per_beat() -> float:
	return 60.0 / BPM


static func length() -> float:
	return beats() * seconds_per_beat()


## Renders the whole song (about a second of work). The caller keeps the
## result; do not cache it in a static variable, or it outlives the audio
## server at exit and Godot crashes while quitting.
static func render() -> AudioStreamWAV:
	var spb := seconds_per_beat()
	var count := int(ceil(length() * RATE)) + RATE
	var mix := PackedFloat32Array()
	mix.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	# Drums: kick on the 1, claps on 2 and 3, hat on every beat and off-beat.
	var sung := INTRO_BEATS + VERSES * VERSE_BEATS
	for b in sung + 1:
		var t := b * spb
		if posmod(b - FIRST_DOWNBEAT, 3) == 0:
			_kick(mix, t)
		else:
			_clap(mix, t, rng)
		_hat(mix, t, 0.07, rng)
		_hat(mix, t + spb * 0.5, 0.035, rng)
	for v in VERSES:
		var base := (INTRO_BEATS + v * VERSE_BEATS) * spb
		for note in MELODY:
			_tone(mix, base + float(note[0]) * spb, float(note[2]) * spb, int(note[1]))
		for chord in CHORDS:
			var start := base + float(chord[0]) * spb
			var root := int(chord[2])
			var intervals: Array = chord[3]
			_bass(mix, start, root, 0.55)
			for k in range(1, int(chord[1])):
				for interval in intervals:
					_stab(mix, start + k * spb, root + 12 + int(interval))
	# The ending: the last chord rings, with a cymbal.
	var tail := sung * spb
	_bass(mix, tail, 48, 1.8)
	for interval in [0, 4, 7, 12]:
		_stab(mix, tail, 60 + interval, 1.6, 0.08)
	_cymbal(mix, tail, rng)
	# To 16-bit, with a soft limiter so the loud bits round off instead of
	# clipping.
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var v := tanh(mix[i] * 1.15)
		data.encode_s16(i * 2, int(v * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return wav


static func _freq(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


## The lead voice: a warm tone with a few harmonics and a touch of vibrato.
static func _tone(mix: PackedFloat32Array, start: float, seconds: float, midi: int) -> void:
	var f := _freq(midi)
	var hold := seconds * 0.9
	var release := 0.14
	var n := int((hold + release) * RATE)
	var i0 := int(start * RATE)
	var phase := 0.0
	for i in n:
		var idx := i0 + i
		if idx >= mix.size():
			break
		var t := float(i) / RATE
		var env: float
		if t < 0.012:
			env = t / 0.012
		elif t < hold:
			env = lerpf(1.0, 0.8, minf((t - 0.012) / 0.15, 1.0))
		else:
			env = 0.8 * (1.0 - (t - hold) / release)
		var vibrato := 1.0 + 0.004 * sin(TAU * 5.5 * t) * clampf((t - 0.12) / 0.2, 0.0, 1.0)
		phase += TAU * f * vibrato / RATE
		var v := sin(phase) + 0.42 * sin(2.0 * phase) + 0.18 * sin(3.0 * phase) + 0.07 * sin(4.0 * phase)
		mix[idx] += v * env * 0.2


## A short, bright chord note (the "pah" of oom-pah-pah).
static func _stab(mix: PackedFloat32Array, start: float, midi: int, seconds := 0.3, amp := 0.055) -> void:
	var f := _freq(midi)
	var n := int(seconds * RATE)
	var i0 := int(start * RATE)
	for i in n:
		var idx := i0 + i
		if idx >= mix.size():
			break
		var t := float(i) / RATE
		var env := minf(t / 0.004, 1.0) * exp(-t * (6.5 if seconds < 1.0 else 1.6))
		var ph := TAU * f * t
		mix[idx] += (sin(ph) + 0.5 * sin(2.0 * ph) + 0.25 * sin(3.0 * ph)) * env * amp


## The "oom": a round bass note on the downbeat.
static func _bass(mix: PackedFloat32Array, start: float, midi: int, seconds: float) -> void:
	var f := _freq(midi)
	var n := int(seconds * RATE)
	var i0 := int(start * RATE)
	for i in n:
		var idx := i0 + i
		if idx >= mix.size():
			break
		var t := float(i) / RATE
		var env := minf(t / 0.006, 1.0) * exp(-t * 3.2) * (1.0 - t / seconds)
		var ph := TAU * f * t
		mix[idx] += (sin(ph) + 0.3 * sin(2.0 * ph)) * env * 0.32


static func _kick(mix: PackedFloat32Array, start: float) -> void:
	var n := int(0.28 * RATE)
	var i0 := int(start * RATE)
	var phase := 0.0
	for i in n:
		var idx := i0 + i
		if idx >= mix.size():
			break
		var t := float(i) / RATE
		var f := 46.0 + 120.0 * exp(-t * 26.0)
		phase += TAU * f / RATE
		mix[idx] += sin(phase) * exp(-t * 9.0) * 0.6


## Hand claps: three quick bursts of noise and a short tail.
static func _clap(mix: PackedFloat32Array, start: float, rng: RandomNumberGenerator) -> void:
	var n := int(0.16 * RATE)
	var i0 := int(start * RATE)
	var last := 0.0
	for i in n:
		var idx := i0 + i
		if idx >= mix.size():
			break
		var t := float(i) / RATE
		var env := exp(-t * 22.0) * 0.45
		for burst in [0.0, 0.011, 0.022]:
			if t >= burst:
				env += exp(-(t - burst) * 110.0)
		var noise := rng.randf_range(-1.0, 1.0)
		var bright := noise - last * 0.6   # thins out the low rumble
		last = noise
		mix[idx] += bright * env * 0.16


static func _hat(mix: PackedFloat32Array, start: float, amp: float, rng: RandomNumberGenerator) -> void:
	var n := int(0.05 * RATE)
	var i0 := int(start * RATE)
	var last := 0.0
	for i in n:
		var idx := i0 + i
		if idx >= mix.size():
			break
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		var bright := noise - last
		last = noise
		mix[idx] += bright * exp(-t * 75.0) * amp


static func _cymbal(mix: PackedFloat32Array, start: float, rng: RandomNumberGenerator) -> void:
	var n := int(1.6 * RATE)
	var i0 := int(start * RATE)
	var last := 0.0
	for i in n:
		var idx := i0 + i
		if idx >= mix.size():
			break
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		var bright := noise - last * 0.8
		last = noise
		mix[idx] += bright * exp(-t * 2.6) * 0.11
