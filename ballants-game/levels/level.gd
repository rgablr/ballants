extends Node3D
## LEVEL -- the script every level scene uses. Right now it only names the
## level; later it is the natural home for per-level music, intro text,
## checkpoints, and so on.
##
## A level scene is expected to contain:
##   - a Player (src/player/player.tscn) with its camera_rig set
##   - a CameraRig (src/camera/orbit_camera.tscn) with its target set
##   - a Goal (src/objects/goal.tscn)
##   - the HUD (src/ui/hud.tscn)
## plus any Blocks and props that make up the course.

@export var level_name := "Untitled level"
