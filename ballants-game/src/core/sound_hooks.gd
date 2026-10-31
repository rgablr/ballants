extends Node
## SOUND HOOKS -- every place the game would make a sound calls one of
## these. They are empty on purpose (sound is out of scope for now). When
## audio is added, fill these in and register the clips in the asset
## manifest's SOUNDS table; nothing else needs to change.
##
## Loaded as a global called "Sounds".


## A collision: strength is the sudden speed change in m/s.
## Suggested: pick a clip by strength (soft thud / hard thud), place it in
## 3D at `position`, scale volume with strength.
func impact(strength: float, position: Vector3) -> void:
	pass


## The ball left the ground on purpose.
func jump() -> void:
	pass


## The ball touched down; fall_speed is how fast it was falling (m/s).
func land(fall_speed: float) -> void:
	pass


## The level's goal was reached.
func goal() -> void:
	pass


## Called every frame with the ball's rolling speed; for a looping roll
## sound whose pitch and volume follow speed.
func rolling(speed: float, grounded: bool) -> void:
	pass
