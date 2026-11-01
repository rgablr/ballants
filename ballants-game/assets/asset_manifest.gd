extends Node
## ASSET MANIFEST -- the one list of every model, texture, sound, song and
## font the game uses.
##
## Game code never points at an asset file directly. It asks for an asset by
## its nickname, for example  Assets.instantiate_model("ball").  So to swap an
## asset:
##   1. Put the new file somewhere under res://assets/ (models/, textures/,
##      audio/sounds/, audio/music/, fonts/).
##   2. Change the path next to the nickname below. That's it.
##
## Rules for replacement assets (so the game can ship on Steam without the
## AI-content label): human-made or properly licensed only. CC0 packs such as
## Kenney (kenney.nl) and Quaternius (quaternius.com) are fine. Keep each
## asset's license file next to it, like fonts/Nunito-OFL.txt.
##
## This script is loaded as a global called "Assets".


## 3D models. A path can be a Godot scene (.tscn) or an imported model file
## (.glb / .gltf). Expectations for each one are listed next to it.
const MODELS := {
	# The ball the player rides. Expected: about 1 meter across, centered on
	# its origin. The collision shape is separate and does not depend on it.
	"ball": "res://assets/placeholders/soccer_ball.tscn",

	# The ant that balances on the ball. Expected: feet at the origin (y = 0),
	# facing -Z (Godot's "forward"), about 0.5 meters long. If the model has a
	# set_walk_speed(speed) method or an AnimationPlayer, the game will use it
	# to animate walking; neither is required.
	"ant": "res://assets/placeholders/ant.tscn",
}

## 2D images used on surfaces or in the UI. (None yet: placeholders are
## plain colors.)
const TEXTURES := {
}

## Short sound effects, all from Kenney's CC0 audio packs (license in
## audio/sounds/kenney/). A nickname can list several takes of the same
## sound; one is picked at random each time so repeats don't sound robotic.
const SOUNDS := {
	# The ball bumping into things: a soft knock, and a heavy thud.
	"bump": ["res://assets/audio/sounds/kenney/impactSoft_medium_000.ogg", "res://assets/audio/sounds/kenney/impactSoft_medium_001.ogg", "res://assets/audio/sounds/kenney/impactSoft_medium_002.ogg", "res://assets/audio/sounds/kenney/impactSoft_medium_003.ogg", "res://assets/audio/sounds/kenney/impactSoft_medium_004.ogg"],
	"thud": ["res://assets/audio/sounds/kenney/impactSoft_heavy_000.ogg", "res://assets/audio/sounds/kenney/impactSoft_heavy_001.ogg", "res://assets/audio/sounds/kenney/impactSoft_heavy_002.ogg", "res://assets/audio/sounds/kenney/impactSoft_heavy_003.ogg", "res://assets/audio/sounds/kenney/impactSoft_heavy_004.ogg"],
	# Touching down after a small hop (a soft grassy step).
	"land": ["res://assets/audio/sounds/kenney/footstep_grass_000.ogg", "res://assets/audio/sounds/kenney/footstep_grass_001.ogg", "res://assets/audio/sounds/kenney/footstep_grass_002.ogg", "res://assets/audio/sounds/kenney/footstep_grass_003.ogg", "res://assets/audio/sounds/kenney/footstep_grass_004.ogg"],
	# Jump: a springy "boing".
	"jump": ["res://assets/audio/sounds/kenney/phaseJump1.ogg", "res://assets/audio/sounds/kenney/phaseJump2.ogg", "res://assets/audio/sounds/kenney/phaseJump3.ogg", "res://assets/audio/sounds/kenney/phaseJump4.ogg", "res://assets/audio/sounds/kenney/phaseJump5.ogg"],
	# Rolling into the ant hill's hole: a falling whistle.
	"hill_drop": "res://assets/audio/sounds/kenney/highDown.ogg",
	# An enemy got you: a punch and a sad falling tone.
	"hit": ["res://assets/audio/sounds/kenney/impactPunch_heavy_000.ogg", "res://assets/audio/sounds/kenney/impactPunch_heavy_001.ogg", "res://assets/audio/sounds/kenney/impactPunch_heavy_002.ogg", "res://assets/audio/sounds/kenney/impactPunch_heavy_003.ogg", "res://assets/audio/sounds/kenney/impactPunch_heavy_004.ogg"],
	"hit_tone": "res://assets/audio/sounds/kenney/phaserDown2.ogg",
	# Back at the spawn after being knocked off: a little pop.
	"respawn": "res://assets/audio/sounds/kenney/pepSound1.ogg",
	# Snapping through a blade of thick grass.
	"grass": ["res://assets/audio/sounds/kenney/footstep_grass_000.ogg", "res://assets/audio/sounds/kenney/footstep_grass_001.ogg", "res://assets/audio/sounds/kenney/footstep_grass_002.ogg", "res://assets/audio/sounds/kenney/footstep_grass_003.ogg", "res://assets/audio/sounds/kenney/footstep_grass_004.ogg"],
	# An enemy has noticed you and is about to attack (a scratchy chitter).
	"warn": ["res://assets/audio/sounds/kenney/scratch_001.ogg", "res://assets/audio/sounds/kenney/scratch_002.ogg", "res://assets/audio/sounds/kenney/scratch_003.ogg"],
	# Menus.
	"menu_open": "res://assets/audio/sounds/kenney/open_001.ogg",
	"menu_close": "res://assets/audio/sounds/kenney/close_001.ogg",
	"menu_move": ["res://assets/audio/sounds/kenney/scroll_001.ogg", "res://assets/audio/sounds/kenney/scroll_002.ogg", "res://assets/audio/sounds/kenney/scroll_003.ogg"],
	"menu_change": ["res://assets/audio/sounds/kenney/click_001.ogg", "res://assets/audio/sounds/kenney/click_002.ogg", "res://assets/audio/sounds/kenney/click_003.ogg"],
	"confirm": "res://assets/audio/sounds/kenney/confirmation_001.ogg",
	# Results cards: level complete, world complete.
	"level_complete": "res://assets/audio/sounds/kenney/jingles_PIZZI07.ogg",
	"world_complete": "res://assets/audio/sounds/kenney/jingles_STEEL07.ogg",
}

## Background songs, played one after another in a shuffled loop, quietly
## under the sound effects. All CC0 from OpenGameArt.org, made by human
## composers (see ASSET_CREDITS.md).
const MUSIC := {
	"green_hills": "res://assets/audio/music/green_hills.mp3",
	"sunflower_valley": "res://assets/audio/music/sunflower_valley.ogg",
	"summer_sunday": "res://assets/audio/music/summer_sunday.wav",
	"napping_on_a_cloud": "res://assets/audio/music/napping_on_a_cloud.ogg",
}

## Fonts. "ui" is applied to every piece of text in the game. Keep it a font
## with a plain zero (no dot or slash through it), like Nunito.
const FONTS := {
	"ui": "res://assets/fonts/Nunito.ttf",
}


func _ready() -> void:
	# Apply the UI font to every Control in the game at once, via the root
	# window's theme. The HUD and future menus inherit it automatically.
	var theme := Theme.new()
	theme.default_font = font("ui")
	theme.default_font_size = 18
	get_tree().root.theme = theme


## Creates a fresh copy of a model ready to add to the scene tree.
## Always returns a Node3D, even on failure, so callers never crash; the
## failure is reported in the Output panel instead.
func instantiate_model(nickname: String) -> Node3D:
	var path: String = MODELS.get(nickname, "")
	if path.is_empty():
		push_error("Assets: no model nicknamed '%s' in asset_manifest.gd" % nickname)
		return Node3D.new()
	var packed := load(path)
	if packed is PackedScene:
		var node := (packed as PackedScene).instantiate()
		if node is Node3D:
			return node
		push_error("Assets: model '%s' (%s) is not a 3D scene" % [nickname, path])
		node.free()
		return Node3D.new()
	push_error("Assets: could not load model '%s' from %s" % [nickname, path])
	return Node3D.new()


func texture(nickname: String) -> Texture2D:
	return _load_typed(TEXTURES, nickname, "texture") as Texture2D


## A sound effect. If the nickname lists several takes, a random one.
func sound(nickname: String) -> AudioStream:
	var entry: Variant = SOUNDS.get(nickname, "")
	if entry is Array:
		var takes: Array = entry
		return _load_path(takes.pick_random(), nickname, "sound") as AudioStream
	return _load_typed(SOUNDS, nickname, "sound") as AudioStream


func music(nickname: String) -> AudioStream:
	return _load_typed(MUSIC, nickname, "music") as AudioStream


func font(nickname: String) -> Font:
	return _load_typed(FONTS, nickname, "font") as Font


func _load_typed(table: Dictionary, nickname: String, kind: String) -> Resource:
	var path: String = table.get(nickname, "")
	if path.is_empty():
		push_error("Assets: no %s nicknamed '%s' in asset_manifest.gd" % [kind, nickname])
		return null
	return _load_path(path, nickname, kind)


func _load_path(path: String, nickname: String, kind: String) -> Resource:
	var res := load(path)
	if res == null:
		push_error("Assets: could not load %s '%s' from %s" % [kind, nickname, path])
	return res
