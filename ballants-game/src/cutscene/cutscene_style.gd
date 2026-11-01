class_name CutsceneStyle
extends RefCounted
## CUTSCENE STYLE -- the one place to tune how every cutscene looks and
## sounds: the text box, typing speed, the voices' defaults, the camera and
## the skip hold. Wording, speakers and camera targets live in the JSON
## files under res://cutscenes/ instead, so lines can be edited without
## touching code. Per-character voice pitch and camera framing live in
## cutscenes/characters.json.

# --- Text box ----------------------------------------------------------
## Fraction of the screen the box's left edge starts at (it sits to the
## right of whoever is talking) and how wide / tall it is, as fractions.
const BOX_LEFT := 0.5
const BOX_WIDTH := 0.46
const BOX_BOTTOM := 0.88          # the box's bottom edge, fraction from the top
const BOX_HEIGHT := 0.24
const BOX_COLOR := Color(0.0, 0.0, 0.0, 0.58)
const BOX_CORNER := 14
const BOX_PADDING := 22
const NAME_SIZE := 24
const NAME_COLOR := Color(1.0, 0.86, 0.5)
const TEXT_SIZE := 27
const TEXT_COLOR := Color(1.0, 0.98, 0.94)
const HINT_COLOR := Color(1.0, 0.9, 0.65, 0.9)
const CHOICE_SIZE := 28
const CHOICE_COLOR := Color(1.0, 0.95, 0.8)
const CHOICE_SELECTED := Color(1.0, 0.78, 0.3)

# --- Typing -------------------------------------------------------------
## Characters per second when a character doesn't say otherwise.
const TYPE_SPEED := 32.0
## Extra pause (seconds) after . ! ? and after , while typing.
const PAUSE_SENTENCE := 0.22
const PAUSE_COMMA := 0.09
## Seconds the finished line must sit before a press can move on, so a
## press that completed the line can't also skip it.
const ADVANCE_GUARD := 0.15

# --- Voice ("jibber") ----------------------------------------------------
## Defaults a character's "voice" block can override: pitch multiplies
## VOICE_BASE_HZ; "every" is one blip per that many letters; "variation" is
## how far (in steps of a fifth of an octave) a blip wanders.
const VOICE_BASE_HZ := 440.0
const VOICE_DEFAULTS := {"pitch": 1.0, "every": 2, "variation": 1.0, "length": 0.07, "wave": "soft", "volume_db": -9.0}

# --- Camera -------------------------------------------------------------
const CAMERA_FOV := 55.0
## Default seconds for a smooth move between shots (a "cut" uses 0).
const CAMERA_MOVE := 0.9
## Framings every character gets unless its "shots" block overrides them.
## distance/height are meters from the target's origin; yaw is degrees
## around the target from straight in front (0 = looking at its face);
## look_height is where on the target the camera aims.
const SHOT_DEFAULTS := {
	"face": {"distance": 1.6, "height": 0.5, "yaw": 22.0, "look_height": 0.3},
	"wide": {"distance": 5.0, "height": 1.6, "yaw": 35.0, "look_height": 0.4},
	"over": {"distance": 2.6, "height": 1.0, "yaw": 150.0, "look_height": 0.3},
}
## Seconds the camera takes to hand back to the normal game camera.
const CAMERA_RELEASE := 0.7

# --- Skipping -----------------------------------------------------------
## Hold Esc / Start this long to skip the whole cutscene.
const SKIP_HOLD := 1.0

# --- Item popup ---------------------------------------------------------
const ITEM_FLOAT_TIME := 1.3
const ITEM_POPUP_TIME := 2.0
