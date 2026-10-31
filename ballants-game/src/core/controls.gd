extends Node
## CONTROLS -- one place that answers "which way is the player pushing?"
##
## Normally that is the keyboard / left stick (the move_* actions). When a
## controller with motion sensors (Joy-Con, Switch Pro, DualSense...) is
## connected and Tuning.gyro_steering is on, the scheme becomes:
##   left stick forward  = accelerate along where you're going
##   left stick back     = brake
##   tilt the controller = steer, like a steering wheel
##   right stick click / G = recenter the tilt (hold it the way you like)
##
## Tilt is read from the accelerometer (which way gravity points), smoothed
## by Tuning.gyro_smoothing, so there is no drift to correct. The angle is
## around the controller's forward axis: tilting the top of a Joy-Con held
## upright to the left or right.
##
## Loaded as a global called "Controls".

signal gyro_device_changed(device: int)

## The joypad id providing tilt, or -1 if none.
var gyro_device := -1
## Current steering from tilt, -1 (full left) .. 1 (full right).
var steer := 0.0
## Current tilt in degrees after recentering (for the HUD indicator).
var tilt_degrees := 0.0

var _roll_offset := 0.0
var _raw_roll := 0.0


func _ready() -> void:
	_scan_devices()
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool): _scan_devices())


func _scan_devices() -> void:
	var found := -1
	for device in Input.get_connected_joypads():
		if Input.has_joy_motion_sensors(device):
			found = device
			Input.set_joy_motion_sensors_enabled(device, true)
			break
	if found != gyro_device:
		gyro_device = found
		gyro_device_changed.emit(gyro_device)


## True when tilt steering is in use right now.
func gyro_active() -> bool:
	return Tuning.gyro_steering and gyro_device >= 0


func gyro_device_name() -> String:
	return Input.get_joy_name(gyro_device) if gyro_device >= 0 else ""


func _process(delta: float) -> void:
	if not gyro_active():
		steer = 0.0
		tilt_degrees = 0.0
		return
	var gravity := Input.get_joy_accelerometer(gyro_device)
	if gravity.length() < 1.0:
		return   # no reading yet
	# Roll around the controller's forward axis: how far gravity has moved
	# from "straight down" toward the controller's left or right side.
	_raw_roll = rad_to_deg(atan2(gravity.x, gravity.y))
	var roll := _raw_roll - _roll_offset
	tilt_degrees = lerpf(tilt_degrees, roll, 1.0 - exp(-delta * Tuning.gyro_smoothing))
	var dead: float = Tuning.gyro_deadzone_degrees
	var full: float = maxf(Tuning.gyro_max_tilt_degrees, dead + 1.0)
	var amount := 0.0
	if absf(tilt_degrees) > dead:
		amount = signf(tilt_degrees) * (absf(tilt_degrees) - dead) / (full - dead)
	steer = clampf(amount, -1.0, 1.0) * (-1.0 if Tuning.gyro_invert else 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("gyro_recenter"):
		recenter()


## Makes the controller's current tilt count as "straight".
func recenter() -> void:
	_roll_offset = _raw_roll
	tilt_degrees = 0.0


## The movement input this frame: x = right, y = back (same convention as
## Input.get_vector). With gyro steering, x comes from the tilt.
func get_move_vector() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if gyro_active():
		v.x = clampf(v.x + steer, -1.0, 1.0)
	return v
