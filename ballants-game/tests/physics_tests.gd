extends Node3D
## PHYSICS TESTS -- checks that run without anyone playing.
##
## Run from the ballants-game folder:
##     godot --headless -- --tests
## or  ./run_tests.sh   (runs these plus the arena smoke test)
##
## Each test builds a tiny throwaway world (a floor, a wall, a stack...)
## using the REAL player scene and the REAL tuning values, plays it for a
## few seconds, measures, and prints one PASS or FAIL line with the numbers.
## The process exits with code 0 if everything passed, 1 otherwise.
##
## A FAIL means the game broke a promise the design depends on. The
## message says what was measured and what was expected.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const BLOCK_SCENE := preload("res://src/objects/block.tscn")
const CRATE_SCENE := preload("res://src/objects/crate.tscn")

var _failures := 0
var _passes := 0
var _world: Node3D   # the current test's throwaway nodes


func _ready() -> void:
	await get_tree().process_frame
	print("[tests] Ballants physics tests (gravity %.1f, max speed %.1f)" % [Tuning.gravity, Tuning.max_speed])
	await test_input_starts_moving_within_2_frames()
	await test_jump_height_matches_tuning()
	await test_ball_never_passes_through_thin_wall()
	await test_ball_lands_on_thin_platform()
	await test_floor_seams_do_not_launch_ball()
	await test_ramp_crest_does_not_launch_ball()
	await test_stacked_crates_settle_without_jitter()
	print("[tests] %s: %d passed, %d failed" % ["ALL PASSED" if _failures == 0 else "FAILED", _passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# ------------------------------------------------------------ the tests ----

## Principle 1 (responsive input): a push must show up in the ball's speed
## within two physics frames.
func test_input_starts_moving_within_2_frames() -> void:
	var player := await _flat_world_with_player()
	Input.action_press("move_forward")
	await _physics_frames(2)
	var vz := player.linear_velocity.z
	Input.action_release("move_forward")
	_check("input starts moving the ball within 2 frames", vz < -0.01, "forward speed after 2 frames = %.3f m/s" % -vz)
	_teardown()


## Principle 6 (tuned jumps): the apex must match Tuning.jump_height.
func test_jump_height_matches_tuning() -> void:
	var player := await _flat_world_with_player()
	var start_y := player.global_position.y
	Input.action_press("jump")
	await _physics_frames(2)
	Input.action_release("jump")
	var apex := start_y
	for i in 90:
		await get_tree().physics_frame
		apex = maxf(apex, player.global_position.y)
	var height := apex - start_y
	var tolerance := Tuning.jump_height * 0.12 + 0.05
	_check("jump height matches tuning", absf(height - Tuning.jump_height) <= tolerance,
			"measured %.2f m, tuning says %.2f m (±%.2f)" % [height, Tuning.jump_height, tolerance])
	_teardown()


## Principle 7 (stable simulation): at well above top speed, a 10 cm wall
## must still stop the ball.
func test_ball_never_passes_through_thin_wall() -> void:
	var player := await _flat_world_with_player()
	_block(Vector3(0, 2, -10), Vector3(8, 4, 0.1), Vector3.ZERO)
	var speed := Tuning.max_speed * 2.0
	player.linear_velocity = Vector3(0, 0, -speed)
	await _seconds(1.0)
	var z := player.global_position.z
	_check("ball never passes through a thin wall at 2x max speed", z > -10.0,
			"ball ended at z = %.2f (wall at z = -10), speed %.0f m/s" % [z, speed])
	_teardown()


## Principle 7: a fast fall onto a 10 cm platform must land on it.
func test_ball_lands_on_thin_platform() -> void:
	_setup()
	_block(Vector3(0, 5, 0), Vector3(6, 0.1, 6), Vector3.ZERO)
	var player := _player(Vector3(0, 22, 0))
	await _seconds(2.5)
	var y := player.global_position.y
	_check("ball lands on a thin platform after a long fall", y > 5.0,
			"ball resting at y = %.2f (platform top at 5.05)" % y)
	_teardown()


## Principle 4 (predictability): rolling across floor tiles that meet edge
## to edge must not bump the ball into the air.
func test_floor_seams_do_not_launch_ball() -> void:
	_setup()
	for i in 8:
		_block(Vector3(0, -0.5, -i * 4.0), Vector3(4, 1, 4), Vector3.ZERO)
	var player := _player(Vector3(0, 0.6, 0))
	await _seconds(0.8)
	player.linear_velocity = Vector3(0, 0, -Tuning.max_speed)
	Input.action_press("move_forward")
	var max_lift := 0.0
	var max_vy := 0.0
	var pop_z := 0.0
	for i in 90:
		await get_tree().physics_frame
		if player.global_position.z < -26.0:
			break
		max_lift = maxf(max_lift, player.global_position.y - player.radius)
		if player.linear_velocity.y > max_vy:
			max_vy = player.linear_velocity.y
			pop_z = player.global_position.z
	Input.action_release("move_forward")
	_check("floor seams do not launch the ball", max_lift < 0.05 and max_vy < 0.5,
			"max lift above floor %.3f m, max upward speed %.2f m/s (at z = %.2f)" % [max_lift, max_vy, pop_z])
	_teardown()


## Principle 4: cresting a ramp onto a platform should keep the ball on
## the surface instead of popping it into the air.
func test_ramp_crest_does_not_launch_ball() -> void:
	_setup()
	_block(Vector3(0, -0.5, 0), Vector3(6, 1, 16), Vector3.ZERO)
	# Same geometry as the arena's main ramp: 2 m rise over 11.4 m.
	_block(Vector3(0, 0.85, -13.5), Vector3(6, 0.4, 11.4), Vector3(10.1, 0, 0))
	_block(Vector3(0, 1.5, -26), Vector3(6, 1, 14), Vector3.ZERO)
	var player := _player(Vector3(0, 0.6, 6))
	await _seconds(0.8)
	Input.action_press("move_forward")
	var max_up_speed := 0.0
	var reached_top := false
	for i in 300:
		await get_tree().physics_frame
		var p := player.global_position
		if p.z < -20.0:
			reached_top = true
			max_up_speed = maxf(max_up_speed, player.linear_velocity.y)
		if p.z < -30.0:
			break
	Input.action_release("move_forward")
	# Judged by upward SPEED, not height, so the limit means the same thing
	# whatever gravity is set to (3 m/s is a 25 cm hop at gravity 18).
	_check("ramp crest does not launch the ball", reached_top and max_up_speed < 3.0,
			"reached top: %s, max upward speed after crest %.2f m/s (limit 3.0)" % [reached_top, max_up_speed])
	_teardown()


## Principle 7: a column of crates must come to rest and stay put.
func test_stacked_crates_settle_without_jitter() -> void:
	_setup()
	_block(Vector3(0, -0.5, 0), Vector3(10, 1, 10), Vector3.ZERO)
	var crates: Array[RigidBody3D] = []
	for i in 5:
		var crate := CRATE_SCENE.instantiate() as RigidBody3D
		_world.add_child(crate)
		crate.global_position = Vector3(0, 0.4 + i * 0.8, 0)
		crates.append(crate)
	await _seconds(3.0)
	var start_positions: Array[Vector3] = []
	for crate in crates:
		start_positions.append(crate.global_position)
	await _seconds(1.0)
	var max_drift := 0.0
	var lowest_top := 99.0
	for i in crates.size():
		max_drift = maxf(max_drift, crates[i].global_position.distance_to(start_positions[i]))
		lowest_top = minf(lowest_top, crates[i].global_position.y)
	var still_stacked: bool = crates[4].global_position.y > 3.0
	_check("stacked crates settle without jitter", max_drift < 0.01 and still_stacked,
			"drift over 1 s after settling: %.4f m, top crate at y = %.2f" % [max_drift, crates[4].global_position.y])
	_teardown()


# -------------------------------------------------------------- helpers ----

func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		_passes += 1
	else:
		_failures += 1
	print("[tests] %s: %s -- %s" % ["PASS" if ok else "FAIL", name, detail])


func _setup() -> void:
	_world = Node3D.new()
	add_child(_world)


func _teardown() -> void:
	Input.action_release("move_forward")
	Input.action_release("jump")
	_world.queue_free()
	_world = null
	await get_tree().physics_frame
	await get_tree().physics_frame


func _flat_world_with_player() -> RigidBody3D:
	_setup()
	_block(Vector3(0, -0.5, -20), Vector3(20, 1, 80), Vector3.ZERO)
	var player := _player(Vector3(0, 0.6, 0))
	await _seconds(0.8)
	return player


func _block(pos: Vector3, size: Vector3, rotation_deg: Vector3) -> Node3D:
	var block := BLOCK_SCENE.instantiate()
	block.size = size
	_world.add_child(block)
	block.global_position = pos
	block.rotation_degrees = rotation_deg
	return block


## Adds the player. Blocks placed before this call are merged into one
## collision body first, exactly as a real level does.
func _player(pos: Vector3) -> RigidBody3D:
	StaticMerger.merge(_world)
	var player := PLAYER_SCENE.instantiate() as RigidBody3D
	_world.add_child(player)
	player.global_position = pos
	return player


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
