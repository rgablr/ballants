# Ballants – Setup Notes

Branch: `setup/foundation` (your original work is untouched on `main`).
Engine: Godot 4.7.2, standard build (GDScript), Jolt physics.

Everything below was built and then verified by actually running the game:
the automated checks (`./run_tests.sh`, see section 3) all pass, and
screenshots confirmed the visuals.

**Two rounds of work are recorded here.** Part A (sections 1–6) is the
original setup. Part B (sections 7–11) is the tools-and-feel round:
tuning panel, debug overlay, physics tests, feel pass, bigger arena,
design doc. New questions are in section 11.

---

## 1. What was kept, fixed and replaced

The original repo had one test scene (a flat floor, a ball, a camera) and
three small scripts. You said nothing had to be kept, so I judged each piece
on whether it would make the full game easier or harder to build.

| Original piece | Decision | Why |
|---|---|---|
| `main.tscn` (floor + ball + camera) | **Replaced** by `levels/test_arena.tscn` | Built from CSG shapes, which generate heavy mesh-based collision. Replaced with reusable `Block` pieces that use plain box collision and can be resized in the Inspector. |
| `rigid_body_3d.gd` (ball movement) | **Replaced** by `src/player/player_ball.gd` | The idea (push a RigidBody relative to the camera) was right and I kept that approach. But it read raw keys (no gamepad, not remappable), allowed infinite mid-air jumps, had no speed cap, and every number was hard-coded. |
| `camera_3d.gd` (follow camera) | **Replaced** by `src/camera/orbit_camera.gd` | The orbit math was sound, but it only rotated while holding the left mouse button, had no gamepad support, and would clip through walls. New one uses a spring arm (pulls in when a wall is in the way), mouse-look, and right stick. |
| `spot_light_3d.gd` | **Removed** | Empty template, not attached to anything. |
| `project.godot` settings | **Kept and extended** | Jolt physics and Forward+ renderer were good choices. Added the input map, window size, globals, and bumped the version to 4.7 (what's installed now). |
| `.gitignore`, `.editorconfig`, `icon.svg` | **Kept** | Fine as-is. |

---

## 2. How the project is organized (plain words)

Terms, defined once:

- **Scene** (`.tscn` file): Godot's word for a reusable bundle of objects
  — a ball, a crate, a whole level. Scenes can contain other scenes.
- **Node**: one object inside a scene (a shape, a light, a camera).
- **Script** (`.gd` file): code attached to a node that gives it behavior.
- **Global** (Godot calls it an "autoload"): a script that is always loaded
  and reachable from anywhere by name. We have four: `Tuning`, `Assets`,
  `Game`, `DevTools`.
- **RigidBody3D**: a node the physics engine moves (falls, rolls, bounces).
  The ball, crates and boulder are these.
- **StaticBody3D**: a solid thing physics never moves. Floors, walls, ramps.
- **Area3D**: an invisible zone that notices when something enters it.
  The goal and bounce pads are these.
- **Collision shape**: the invisible simple shape (box/sphere/cylinder) that
  physics actually uses. Separate from the visible mesh.
- **Mesh**: the visible 3D surface. Can be swapped without touching collision.
- **Signal**: a message a node sends ("level completed") that other nodes
  can listen for, so they don't need to know about each other directly.

### Folder map

```
ballants-game/
  project.godot              Godot settings: input map, globals, main scene
  config/
    physics_tuning.gd        ★ ALL feel numbers, with comments. Edit freely.
  assets/
    asset_manifest.gd        ★ ALL asset paths by nickname. Swap assets here.
    fonts/Nunito.ttf         UI font (plain zero), with its OFL license
    placeholders/            Temporary ball + ant built in code / shader
    models/ textures/ audio/ Empty, ready for real assets
  src/
    core/game.gd             Global: gravity, restart, mouse capture, "level done"
    core/dev_tools.gd        Global: --autotest and --screenshot helpers
    player/player.tscn       The player: ball physics + ant rider
    player/player_ball.gd    Movement, ground detection, jump, respawn
    player/ant_rider.gd      Keeps the ant visual standing on the ball
    camera/orbit_camera.*    Third-person camera on a spring arm
    objects/block.*          Resizable solid box (floors, walls, ramps)
    objects/physics_prop.gd  Pushable box/sphere (crate.tscn, boulder.tscn)
    objects/seesaw.tscn      Plank on a hinge
    objects/bounce_pad.*     Launches whatever rolls on it
    objects/ant_hill.*       The finish: a dirt mound with a hole to drop into
    ui/transition.gd         Global: fade to black + "Level complete" results
    ui/hud.*                 On-screen text
  levels/
    level.gd                 Shared script for every level
    test_arena.tscn          The one test environment
```

### The three design rules and where they live

1. **Physics is separate from visuals.** `player.tscn` has a sphere collision
   shape and an empty `Visual` node; at startup it asks the manifest for the
   ball model and drops it inside `Visual`. Same for the ant. `Block` and
   `PhysicsProp` build both their mesh and their collision from one `size`
   value so they can never disagree. Swapping a model never touches physics.

2. **One asset list.** `assets/asset_manifest.gd` maps nicknames to files.
   Code says `Assets.instantiate_model("ball")`, never a file path. Each
   entry has a comment stating what the replacement must look like (size,
   where its origin is, which way it faces).

3. **One tuning file.** `config/physics_tuning.gd` holds gravity, speeds,
   jump height, camera distance, prop weights, etc. Every value has a
   plain-English comment. Change a number, save, press F5.

### How things talk to each other

- The **level scene** holds a `Player`, a `CameraRig`, a `HUD`, an `AntHill`, and
  the course pieces. The Player is told which CameraRig to use; the CameraRig
  is told which Player to follow. (Both set in the level's Inspector.)
- The **Player** reads the camera's facing to decide which way "forward" is,
  so turning the camera turns the controls.
- The **AntHill** tells the global `Game` the level is complete. `Game`
  fires a signal. The level manager hears it, fades the screen to black
  (the `Transition` global) and shows the results. The hill, HUD and
  Transition never reference each other, so each can be changed alone.
- `Game` also listens for the restart key and reloads the level.

### Adding things without breaking things

- **New level:** duplicate `test_arena.tscn`, rearrange the Blocks, keep the
  Player/CameraRig/HUD/AntHill nodes. Set it as the main scene in Project
  Settings to play it.
- **New obstacle type:** new scene in `src/objects/`. If it's solid and
  still, start from `Block`; if it moves, start from `PhysicsProp`; if it
  reacts to the player entering, copy `bounce_pad`.
- **New ability (e.g. ant stands up):** add to `player_ball.gd` for anything
  physical, `ant_rider.gd` for anything visual. Add its numbers to the
  tuning file.
- **Real art:** drop files under `assets/`, point the manifest at them.
  For a rigged character later, the Mixamo-compatible rig advice still
  applies, but the ant itself is not humanoid, so a custom ant rig with an
  AnimationPlayer is the realistic path; `ant_rider.gd` already looks for a
  `set_walk_speed()` method and can be extended to drive an AnimationPlayer.

---

## 3. How to run the game

**In the editor:** open Godot → Import → pick `ballants-game/project.godot`
→ press F5. The mouse is grabbed for camera control; press Esc to free it,
click the window to grab it again.

**Controls**

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Roll | W A S D | Left stick |
| Jump | Space | A (bottom face button) |
| Camera | Mouse (or arrow keys) | Right stick |
| Restart level | R | Start |
| Free / grab mouse | Esc / click | — |
| Tuning panel | F1 | — |
| Debug overlay | F2 | — |

**From a terminal** (inside the `ballants-game` folder):

```
godot                                   # just play
./run_tests.sh                          # ALL automated checks, with a summary
godot --headless -- --tests             # physics tests only
godot -- --autotest                     # arena smoke test, prints PASS/FAIL
godot -- --screenshot=/tmp/shot.png     # save a picture after 1.5 s and quit
godot -- --zoom=2                       # camera closer, for ant close-ups
godot -- --press=toggle_tuning_panel    # press an input action at start
godot -- --camera-yaw=180 --camera-pitch=35   # aim the camera at start
```

---

## 4. Acceptance criteria (test by playing)

**Movement**
- Hold W: the ball starts rolling away from the camera and takes about a
  second to reach full speed. The speed readout (bottom-left) climbs to
  14.0 m/s and stops there on flat ground.
- Release W at full speed: the ball keeps rolling and takes several seconds
  to coast to a stop. It does not stop dead.
- At full speed, press S: the ball slows noticeably faster than it coasted,
  then reverses.
- At full speed, tap A or D: the ball drifts in a wide arc, not a sharp
  turn. Hold it longer to turn more. Sharp corners at speed will overshoot.
- Roll through the two grey pillars in front of the start: the ball fits
  between them.
- Roll up the tan ramp: the ball slows a little going up and speeds up
  coming back down.
- Roll toward the dark wall on the left: the ball bounces off it slightly.

**Camera**
- Roll in any direction and let go of the mouse: within a second or two
  the camera swings around to sit behind the ball, looking the way it's
  rolling.
- Hold S from a standstill: the ball rolls toward the camera, the camera
  swings around behind it, and the ball keeps going in a straight line
  the whole time (the controls don't flip mid-swing). Release S, and W now
  continues in the same direction.
- Move the mouse right: the camera orbits so you look further right, and
  stays there for about a second after you stop moving the mouse, then
  eases back behind the direction of travel. Hold W while turning it: the
  ball curves to follow the new camera direction.
- Move the mouse up/down: the view tilts, but stops before going below the
  ground or straight overhead. It eases back to the default tilt on its own.
- With a gamepad, the right stick does the same.
- Roll close to a wall with the camera behind you: the camera moves in
  rather than showing you the inside of the wall.

**Jump**
- Press Space on flat ground: the ball jumps about 1.6 ball-heights and
  lands without sliding sideways. (Measured by the autotest: 1.5 m.)
- Press Space in mid-air: nothing happens. No double jumps.
- Roll off a platform edge and press Space within a tenth of a second:
  the jump still happens (coyote time).
- Press Space just before landing: the jump happens on landing (buffer).
- Jump from the moving ball: it keeps its forward speed through the air.

**Objects**
- Crates (left of start): rolling into them pushes them; the stacked one
  topples. They feel lighter than the ball.
- Boulder (right of start): rolling into it moves it, but it pushes back
  harder and can shove the ball around.
- Seesaw (far left): roll onto one end and the plank tips down under you;
  the other end rises.
- Orange bounce pad (right of the ramp): rolling onto it launches the ball
  about 5 m straight up, with a visible squash on the pad.
- Second bounce pad (far right, near the raised landing): launches you
  high enough to land on the raised platform with a crate on it if you have
  some sideways speed.
- Narrow beam (right side, reached by the second ramp): rolling along it at
  speed is hard; drifting off drops you to the ground.

**Goal and restart**
- Roll up the ant hill on the raised platform and drop into its hole: the
  screen fades to black, "GOAL!" and your time show, and the arena reloads.
  (Section 20 has the current finish sequence.)
- Press R at any time: the level reloads, crates and boulder return to
  their start positions, the ball is back at the start, the message is gone.
- Roll off the edge of the green ground and fall: after about a second the
  ball reappears at the start (no restart needed).

**Visual**
- The ant stands upright on its two back legs on top of the ball at all
  times, even when the ball spins. It is about half the ball's height.
- Its back feet stay on the ball's surface; they never float above it or
  sink into it, including while walking and while leaning.
- When the ball rolls, the ant faces the direction it is moving, leans
  forward, and its back feet shuffle; faster rolling = faster shuffle.
- When you accelerate hard or brake hard, the ant slides a little toward
  the back of the ball, then settles back on top.
- Jump: the ant stretches slightly on take-off and squashes on landing,
  then springs back.
- All on-screen text uses Nunito (the zeros in "0.0 m/s" are plain ovals).

---

## 5. Known issues and suggested next steps

Known issues
- **The ant can't actually fall off.** The balance lean is visual only.
  Whether balance becomes a fail state is the biggest open design question
  (see Q1 below).
- **Jump height is ~0.1 m short of the tuning value** (1.5 m measured vs
  1.6 m set). This is physics-step rounding, not a bug; set the number a
  touch higher if it matters.
- **Holding A or D alone makes you circle.** With the camera swinging
  behind you, "right" keeps rotating as the camera does, so the ball
  spirals. Most follow-camera games behave this way; say so if it bothers you.
- **No "balance" feedback yet** beyond the ant's lean: no wobble meter,
  no sound, no camera shake.
- **Bounce pads also launch crates and the boulder.** Intentional for now
  (it's fun), easy to restrict.
- **No menus, pause, sound, save, or extra levels** — out of scope, as agreed.
- The Godot editor will add `uid=` tags and rewrite some scene files the
  first time you save them. That's normal; commit the result.

Suggested next steps, in order
1. **Play it and tune the feel** using `config/physics_tuning.gd`. The
   three numbers that matter most: `roll_acceleration` (snappiness),
   `max_speed`, `rolling_resistance` (how long it coasts).
2. **Decide the balance mechanic** (Q1) — it defines the game.
3. **First real level** once the feel is right: a short course with a
   start, 3–4 hazards, and the goal.
4. **Tilt-based level pieces**: moving platforms, tilting floors, narrow
   paths with drop-offs — the things that punish momentum.
5. **Placeholder audio** from a CC0 pack via the manifest (roll loop that
   scales with speed, jump, land, goal).

---

## 6. Questions for you

**Q1. What should "losing your balance" mean?**
- (a) Visual only, as now — you fail by falling off the level, like Monkey Ball.
- (b) The ant can be thrown off the ball by hard impacts/sharp turns; you
  lose when it hits the ground.
- (c) A balance meter that fills with abuse; full meter = ant falls off.
- (d) Not sure yet; keep it visual until the first real level exists.

**Q2. When the player falls off the world or loses, what should happen?**
- (a) Instantly reappear at the start (as now).
- (b) Reappear at the last checkpoint.
- (c) Short "fell!" message, then restart.
- (d) Lives system.

**Q3. Camera behavior when you're not touching it:** answered — it swings
behind the direction of travel, with a look-around that eases back.
`camera_auto_follow_speed` and `camera_look_hold_time` in the tuning file
set how fast and how long.

**Q4. Current feel target, before you've played it — which is closest?**
- (a) Heavy momentum: slow to start, slow to stop, wide turns (Monkey Ball).
- (b) Medium: as it is now.
- (c) Snappy: quick to start and stop, turns are tight; difficulty comes
  from level design rather than control.

**Q5. Level style to prototype first:**
- (a) Linear courses: start → hazards → goal, 1–2 minutes each.
- (b) One open hub area with several goals to find.
- (c) Both: a hub that contains entrances to linear courses.

**Q6. Jump: keep it?**
- (a) Yes, as now (fixed height).
- (b) Yes, but hold-for-higher (short tap = small hop).
- (c) No jump: pure rolling, Monkey Ball style. Ramps and pads only.

**Q7. Ant and ball art direction for placeholder-to-real handoff:**
- (a) Keep building visuals in code/shaders for now; real art much later.
- (b) Pull in a free CC0 pack (Kenney/Quaternius) soon for a more
  representative look while prototyping.
- (c) You will supply models; I should only define the specs they need to meet.

---
---

# Part B – Tools, tests, feel and arena (2026-10-31)

## 7. What changed, by task

**Task 1 – Tuning panel (F1).** `src/ui/tuning_panel.gd`. The panel is
built *from the tuning file itself*: its section headers become groups,
its `##` comments become tooltips, and the `RANGES` table at the bottom
of the file sets each slider's limits. Changes apply live through
`Tuning.set_value()`, which fires a signal the ball, camera, gravity and
props listen to. **Save to file** rewrites only the numbers in
`physics_tuning.gd` and keeps every comment; **Reset** restores what the
file had at startup.

**Task 2 – Debug overlay (F2).** `src/ui/debug_overlay.gd`. Green
wireframes for every collision shape, a yellow velocity arrow on the ball,
and a readout: FPS, physics rate, speed, velocity, position, spin, and
state (GROUNDED / AIRBORNE / AIRBORNE with coyote time).

**Task 3 – Automated physics tests.** `tests/physics_tests.gd` plus
`run_tests.sh`. Seven checks (listed in section 9). Writing them found a
real bug: the ball popped 0.4 m into the air crossing the seam between
two floor tiles. Cause: every Block was its own physics body, and the
engine can only smooth "internal edges" within one body. Fix:
`StaticMerger` folds all Block collision into one body at level start.
Seam lift is now 0.002 m. Also enabled continuous collision on the ball
and Jolt's enhanced edge removal, and pinned physics to 60 Hz.

**Task 4 – Feel pass.** See DESIGN.md section 5 for how each principle is
applied. In short: turn assist and ground stick (fake physics), springy
wobbling ant lean driven by acceleration *and* input, impacts detected
from sudden velocity changes, ball squash in world space, dust bursts,
screen shake, hit-pause, speed-widened field of view, empty sound hooks
in `src/core/sound_hooks.gd`. Masses re-balanced: ball 2.0, crate 0.4,
light box 0.15, domino 0.3, boulder 4.0.

**Task 5 – Bigger arena.** Ground is now 140×140. Added: a 180° banked
curve (generated by `CurvedTrack`), a narrow bridge with a kink, a launch
ramp into a gap with a landing platform, a 7×6 field of light boxes, a
box pyramid, boxes on a tilted ramp, and a 16-domino run with a starter
block. `PropSpawner` lays out grids, rows and pyramids.

**Task 6 – DESIGN.md** at the repo root. Concept, mechanic, controls,
goals, the seven principles as applied, art direction, roadmap M0–M5.

**Assets.** No CC0 soccer ball or ant exists on Kenney, Quaternius or Poly
Pizza (Poly Pizza's are all CC-BY 3.0). Placeholders stay. Candidates and
details are in `ASSET_CREDITS.md`; see Q8.

## 8. New files, in plain words

```
ballants-game/
  run_tests.sh                 Run every automated check
  tests/physics_tests.gd       The physics test suite
  src/ui/tuning_panel.gd       F1 panel
  src/ui/debug_overlay.gd      F2 overlay
  src/core/effects.gd          Global: dust, shake, hit-pause on impacts
  src/core/sound_hooks.gd      Global: empty functions where sounds will go
  src/effects/impact_burst.gd  One dust puff, built in code
  src/objects/static_merger.gd Folds Block collision into one body
  src/objects/curved_track.gd  Banked curve generator
  src/objects/prop_spawner.gd  Grid / row / pyramid of props
  src/objects/light_box.tscn   Very light pushable box
  src/objects/domino.tscn      Tall thin tile for domino runs
DESIGN.md                      Game design document
ASSET_CREDITS.md               Every asset, source, creator, license
```

## 9. Acceptance criteria for Part B

**Tuning panel (F1)**
- Press F1: a panel slides in on the right with sections World, Ball,
  Feel (fake physics), Juice, Jump, Camera, Ant (visual), Interactive
  objects. The mouse is freed. Press F1 again: it closes and the mouse is
  grabbed.
- Hover any row: a tooltip shows the explanation from the tuning file.
- Drag **max speed** down to 5 while rolling: the speed readout caps at
  5.0 immediately. Drag **gravity** to 40: jumps become short and fast at
  once, no restart needed.
- Drag **ball mass** up: crates barely move when hit; drag it down: the
  boulder shoves you harder.
- Change a value, click **Save to file**, close the game, reopen the
  tuning file: the number is changed, all comments intact. Run the game:
  the new value is in effect.
- Change several values, click **Reset**: all sliders snap back to the
  file's values.

**Debug overlay (F2)**
- Press F2: green wireframes outline the ball, floor, every block, crate,
  bounce pad and goal zone. The ball shows a yellow arrow that grows with
  speed and points where it's going. Top-right text shows FPS and the
  numbers.
- Stand still: state reads GROUNDED. Jump: it reads AIRBORNE. Roll off a
  platform edge: for a split second it reads "AIRBORNE (coyote time: can
  still jump)".
- Press F2 again: everything disappears and the game is unaffected.

**Automated tests**
- In a terminal, in `ballants-game`, run `./run_tests.sh`. It prints a
  line per check and ends with `RESULT: all checks passed`. The seven
  physics checks:
  1. input starts moving the ball within 2 frames
  2. jump height matches tuning (±12%)
  3. ball never passes through a 10 cm wall at 2× max speed
  4. ball lands on a 10 cm platform after a 17 m fall
  5. floor seams do not launch the ball (lift < 5 cm)
  6. ramp crest does not launch the ball (lift < 25 cm)
  7. stacked crates settle without jitter (drift < 1 cm over 1 s)
  plus the arena smoke test (rolls, caps, jumps, no false impacts while
  rolling, landing counts as an impact, restart, seesaw).
- A FAIL line names the check and prints what was measured versus what
  was expected, e.g. `measured 0.9 m, tuning says 1.6 m`.
- To break one on purpose: set `jump_height` to 5 in the tuning file and
  run the tests; check 2 should still pass (it reads the tuning), but set
  `gravity` to 2 and check 6 fails because the ball floats off the crest.

**Feel pass**
- Tap W for one frame and release: the ant visibly dips forward before
  the ball has noticeably moved.
- Hold W from a stop: the ant is thrown back over the rear of the ball,
  then wobbles upright as speed steadies. Let go at speed: the ant lurches
  forward. Hold A while rolling fast: the ant leans outward (to the
  right) in the turn.
- Hold W then tap D: the ball's path bends right right away, but it still
  needs a wide arc to come fully around.
- Roll off the goal platform (2 m drop) onto the ground: a puff of dust
  chunks at the contact point, the ball visibly flattens and springs back.
- Roll at full speed into the gate pillar or the bounce wall: dust,
  squash sideways, a brief screen shake, and a tiny freeze-frame.
- Roll at full speed on flat ground: no dust, no squash, no shake (false
  impacts would show up as random puffs).
- Speed up from 0 to 14 m/s: the view visibly widens.
- Roll over the main ramp's crest at speed: the ball follows the surface
  onto the platform rather than hopping off it.
- Camera-relative movement still works: turn the camera with the mouse
  while holding W; the ball curves to follow.

**Arena additions**
- Banked curve (south-west, the big half-ring): enter it at speed from
  the straight marker strip. The bank holds you through the curve; enter
  too fast and you ride up and over the outer edge.
- Narrow bridge (east, x ≈ 26): roll up the ramp and along the 1.2 m
  deck. Oversteer and you drop to the ground. The kink near the far end
  needs a deliberate, early turn.
- Jump gap (south, x ≈ 10): hit the orange ramp at full speed and you
  clear the gap and land on the platform (a backstop wall catches
  overshoots). Hit it slowly and you fall short onto the ground.
- Box field (west): plough through 42 light boxes; they scatter and
  tumble, far lighter than you.
- Box pyramid: a 6-row pyramid that collapses when hit.
- Boxes on ramp: five boxes on a tilted slab; nudge the uphill one and
  they slide into each other.
- Dominoes: roll onto the small grey starter block next to the first
  domino and nudge it; all 16 fall in sequence.

## 10. Known issues after Part B

- The jump still measures ~0.1 m below the tuning value (physics step
  rounding). Tolerated by the tests; raise `jump_height` slightly if you
  want exact.
- Hit-pause freezes *everything* including the ant's wobble; on a long
  hit-pause that can look like a stutter. It's 0.06 s by default.
- The ant's lean at full acceleration is dramatic (it hangs off the back
  of the ball). Intentional for readability; `ant_max_lean` caps it.
- The banked curve has no walls, so overshooting the outer edge drops you
  to the ground (that is the punishment; a kill-zone could replace it).
- Dominoes rest on the ground and only start if nudged from the starter
  side; from the far side they fall away from the run.
- Dust chunks are plain tan cubes; fine for now.

## 11. New questions

**Q8. Models (ball and ant). Poly Pizza has usable low-poly ones, but all
are CC-BY 3.0 (credit required in the game), not CC0. What should I do?**
- (a) CC-BY is fine; download the Poly Pizza ball and ant, credit them in
  ASSET_CREDITS.md and a credits screen.
- (b) Keep the code-built placeholders until you commission or make
  models yourself.
- (c) You'll pick models and tell me which to use.

**Q9. Ant falling off the ball as a fail state. Not built, as agreed. Which
version should I prototype first when you say go?**
- (a) Lean past a threshold for more than a moment → ant falls off, short
  "fell!" message, respawn at last checkpoint.
- (b) A balance meter that fills with abuse (hard hits, extreme leans)
  and drains when steady; full = fall.
- (c) Hard impacts above a threshold knock the ant off instantly; leaning
  never does.
- (d) Keep it visual-only; the challenge stays "don't fall off the level".

**Q10. Hit-pause and screen shake intensity:**
- (a) As built (subtle: 0.06 s pause, 0.25 m shake).
- (b) Stronger, more arcade.
- (c) No hit-pause, keep shake.
- (d) Neither; let the ant and dust carry the feedback.

**Q11. The ant's "thrown back" lean during acceleration:**
- (a) As built (dramatic, hangs off the back).
- (b) Halve it; keep the wobble.
- (c) Replace the slide-around-the-ball with a body bend (feet stay on
  top, upper body tilts).

**Q12. Next level kit piece to build:**
- (a) Moving / tilting platforms.
- (b) Surface types (ice, sand, rubber) changing grip.
- (c) Checkpoints and a kill-zone system for real levels.
- (d) Breakable objects and triggers (buttons, doors).

---
---

# Part C – Level system and the Backyard Garden (2026-10-31, overnight)

Branch: `garden-world` (made from `setup/foundation`, which now also
holds your saved F1 tuning pass as its last commit).

## 12. What was built

**Level system** (I built this; no subagents)
- `levels/level_list.gd` — the one list of levels: world, name, par time,
  scene path. Three Backyard Garden entries.
- `Levels` global (`src/core/level_manager.gd`) — loads levels, times the
  run (the clock starts on your first movement input, stops at the goal),
  shows "Level complete" with your time versus par, then loads the next
  level after 3 s; after level 3 it wraps to level 1. Falling out restarts
  the level after a short "Fell out!".
- Keys: **R** restart, **1 / 2 / 3** jump to a level, **0** the test arena.
- Every level is its own scene built from pieces. The level script
  (`levels/level.gd`) adds the player at the StartPoint, the camera, the
  HUD, the panels, and a safety-net FallZone at y = −10 if a level has none.
- New pieces: `StartPoint`, `FallZone`, `SlickPatch` (lowers the ball's
  grip and push while inside), `Rail`.
- The HUD shows world + level name, the timer and par.
- **Level bot** (`src/core/level_bot.gd`, `godot -- --drive=file.json`): a
  bot that presses the real input actions to steer the ball through a
  list of waypoints. A PASS line means the level is completable with the
  real physics. `run_tests.sh` now drives every `tests/levels/*.json`.
- Dev flags: `--level=N` (0 = arena), `--scene=res://path`.

**Backyard Garden theme** (I built this)
- `levels/garden/garden_theme.tscn` — sky, warm sun, light fog, and the
  shared named materials (`GardenTheme.material("grass")` etc.). One place
  to recolor the whole world.
- Garden piece kit in `src/objects/garden/`, all code-built with separate
  collision: `DirtTile`, `SidewalkSlab`, `GrassClump` (decorative or
  solid), `GrassWall`, `FlowerStem` (bouncy cylinder, flower head far
  above), `Pebble` (convex hull), `FlowerPot` (flat landable top),
  `Puddle` (water + fall zone), `LeafPatch` (slick), `Hose` (chain of
  capsules with a radius that can narrow, bendable, hump-able).
- `levels/garden/garden_showcase.tscn` shows one of each
  (`godot -- --scene=res://levels/garden/garden_showcase.tscn`).
- Scale rule: the ball is one pea. Grass 2–4 m, stems 8–14 m, slabs 12 m.

**Assets:** Kenney's download button is script-driven (a plain fetch
returns a stub page), and Poly Pizza's garden models are CC-BY, so every
garden piece is code-built. Nothing new in ASSET_CREDITS.md beyond that
note. See Q13.

## 13. How to make or edit a level

1. **Copy a starter.** Duplicate any `levels/garden/level_*.tscn` (or open
   it in Godot and Save As). A level scene must have: the root node with
   `levels/level.gd` as its script, a `GardenTheme`, one `StartPoint`, one
   `AntHill` (the finish), and at least one `FallZone` below everything.
2. **Place pieces.** In the Godot editor, drag scenes from
   `src/objects/garden/` and `src/objects/` into the level and set their
   properties in the Inspector (size, length, radius, color…). Every piece
   builds its own look and collision from those properties, so you never
   edit meshes or collision shapes by hand. Blocks and tiles are merged
   into one physics body when the level starts, so you can tile floors
   freely; overlap tiles slightly instead of leaving hairline gaps.
3. **Conventions.** The StartPoint faces −Z and courses run toward −Z.
   Place a tile with its top at y = 0 by setting position.y to −height/2.
   Rotate a tile around X to make a ramp. Keep the path visible: the
   camera sits close, so mark turns with tall pieces (grass walls,
   flowers, pebbles).
4. **Register it.** Add a line to `levels/level_list.gd` with the world,
   name, par time and scene path. Order in that list = play order. The
   main scene (`project.godot`) is level 1.
5. **Prove it.** Write `tests/levels/level_N.json` with waypoints along
   the intended route (format at the top of `src/core/level_bot.gd`) and
   run `godot --headless -- --drive=$(pwd)/tests/levels/level_N.json`
   from `ballants-game`. PASS = a human can do it. `./run_tests.sh` runs
   every level's drive.
6. **Look at it.** `godot -- --level=N --screenshot=/tmp/l.png --zoom=30
   --camera-pitch=40` gives an overview picture.

## 14. Acceptance criteria – level system

- Start the game: it opens on *Backyard Garden – Sidewalk Crack*, with
  the level name and `0:00.00  par 0:45.00` at the top. The clock stays at
  zero until you first push a direction or jump, then counts up.
- Press **2** or **3**: that level loads at once, clock reset to zero.
  Press **0**: the free-roam test arena loads, no timer shown. Press
  **1**: back to level 1.
- Drop into the ant hill: the clock stops, the screen wipes to black,
  "Level complete!", your time and the par verdict show; three seconds
  later the next level fades in. Finish level 3: level 1 loads.
  (Changed in section 20; the ring goal is gone.)
- Roll off the edge of any level: "Fell out!", and the level restarts
  from the start point after about a second, clock reset.
- Press **R** at any moment: the level restarts, props reset, clock reset.
- In the test arena, the ant hill shows "GOAL!" and your time on the black
  screen, then the arena reloads; falling off the arena's edge respawns in
  place.
- Roll onto a leaf (level 2): the ball slides and steers lazily until it
  leaves the leaf.
- Terminal: `./run_tests.sh` lists one `[drive] PASS` line per level.

## 15. The three levels (built by three subagents in parallel, then merged)

Each level has its own design notes next to its scene
(`ballants-game/levels/garden/level_N_notes.md`) with the full table of
layout measurements and the physics values they depend on. The
highlights:

**Level 1 – Sidewalk Crack** (teaches speed and steering; bot time 28.8 s,
par 45 s). A raised sidewalk, ~212 m to the ring: a 48 m fenced straight
with a jagged crack to follow → a fenced 45° left (radius 24 m) → a 36 m
fenced diagonal → an **open** 90° right (radius 20 m, no walls, curb
lines) → a narrowing straight (12 m → 9 m wide) → the small challenge, an
open 45° left of radius 15 m that does not fit at top speed → a fenced
crest and a 20 m downhill (3 m drop) → a walled goal plateau. Falling off
the sidewalk drops onto a lawn below the fall height. New reusable
pieces: `CrackLine` (painted line through points), `CurvedGrassWall`,
`Lawn`.

**Level 2 – Flowerbed Slalom** (teaches turning with momentum; bot time
30.2 s normal line, 26.6 s via the shortcut; par 60 s). A 190 m raised
dirt bed between two water furrows. Twelve rows of three thick stems
(radius 1.1 m) each leave a 4.2 m opening on alternating sides, so the
ball swings ~7 m sideways between rows. Section 1: three rows 20 m apart,
walls both sides. Section 2: four rows 13 m apart, wall on the left,
water on the right. Section 3: five rows 11 m apart, water both sides,
five leaf patches on the swing lines. Shortcut: rows 2 and 4 of section 3
have a 1.8 m gap between stem surfaces, marked by white stems and a
trodden-dirt strip; it skips three swings and saves ~3.5 s.

**Level 3 – Garden Hose Bridge** (teaches balance and careful speed; bot
time 21.6 s, par 75 s). A 78 m hose over a 32 × 81 m puddle: a 24 m wide
straight (radius 2.0 m) → a gentle hump (+0.8 m over 9 m, draped over a
pebble) → an S-bend of four 15° turns each way (bend radius 13.4 m) while
narrowing to radius 1.1 → an 8 m narrow straight aimed at a flower pot →
a 2 m jump up 0.5 m onto the pot (landing disc 5.6 m across) → a 0.5 m
drop to the far bank and the ring. Tall flowers stand outside each bend
so the close camera sees the turn coming.

**Layout ↔ physics, the short version** (full tables in the notes files):
- Curve radii everywhere come from `turn_assist` and `max_speed`: the
  minimum comfortable turn radius is about v²/12.6 (15.5 m at top speed,
  5 m at 8 m/s). Level 1's open curves (20 m and 15 m) and level 2's row
  spacing (20 → 13 → 11 m, i.e. turn radii ~12 → 5 → 3.5 m) are set
  against that.
- Straight lengths come from `roll_acceleration` (0 → 14 m/s in ~14 m)
  and `brake_multiplier` (14 → 0 in ~11 m).
- Jump and gap sizes come from `jump_height` and `gravity` (launch
  5.6 m/s, 1.13 s airtime on flat; the pot jump is 2 m across and 0.5 m
  up, far inside the 1.4 m apex).
- Fall heights come from `fall_respawn_y` (−2.5): every puddle's fall
  zone sits above that so the "Fell out!" restart always fires first.
- Hump and crest shapes come from `ground_stick` (0.37): rises of up to
  ~1 m over 6 m hold the ball at cruising speed.
- Stem thickness and knock-back come from `ball_bounce` (0.47).
- Leaf behavior comes from the leaf `grip` (0.2) and `rolling_resistance`.
- Landmark heights come from `camera_distance` (2.14 m, very close):
  anything the player must see coming is 8–14 m tall.
- **If you change any of those tuning values, re-run `./run_tests.sh`:**
  the level drives will tell you which level stopped being completable.

## 16. Acceptance criteria – the levels

**Level 1**
- From the start, hold W: the ball reaches top speed on the fenced
  straight and the grass walls keep you on even without steering.
- The first bend (fenced) is makeable at full speed without braking.
- The open right-hander: enter at full speed and do nothing: you roll off
  the outer edge, "Fell out!", restart. Steer from the entry: you make it.
- The 15 m left near the end: at full speed you cannot hold it; ease off
  to ~12 m/s or less and it fits.
- The downhill adds speed by itself; the ring is 12 m onto the plateau
  and the end wall stops an overshoot. Time for a first clean run: 35–60 s.

**Level 2**
- Rows cannot be passed anywhere except their opening (the 0.6 m gaps
  between stems are too small for the ball).
- Hit a stem head-on at speed: the ball bounces back about half as fast;
  it does not stop dead or pass through.
- Roll onto a leaf while turning: the turn stops happening until you
  leave the leaf; set turns up before the leaf.
- In section 2, a late right-hand swing ends in the water on the right
  and restarts the level.
- The shortcut gaps (white stems, dirt strip) are passable at speed if
  you line up; taking both saves a few seconds.

**Level 3**
- The ball rolls from the dirt onto the hose with no bump.
- Over the hump at a careful speed (≤ 6 m/s) the ball stays on; at full
  speed it lifts off and usually lands in the water.
- The S-bend is holdable at 4–6 m/s; drifting off either side lands in the
  puddle, "Fell out!", restart.
- From the narrow straight, a jump at 3–6 m/s lands on the pot's soil;
  rolling off the end without jumping lands in the water.
- Off the pot onto the far bank and through the ring. Finishing level 3
  loads level 1.

**All levels**
- `./run_tests.sh` ends with `RESULT: all checks passed`, including one
  `[drive] PASS` per level and "after completing level N the game loaded
  level N+1" (level 3 → level 1).

## 17. Known issues after Part C

- **Camera distance 2.14 m** (from your saved tuning) is very close: you
  see little of the road ahead, so the levels lean on tall landmarks. If
  the levels feel blind, try `camera_distance` 4–6 and
  `camera_height_offset` 1.0 in F1. The levels were built and tested
  against your saved values.
- **Inverted camera Y is on** in your saved tuning (`invert_camera_y`).
- The garden is code-built shapes only; Kenney's CC0 Nature Kit would
  improve it but must be downloaded in a browser (Q13).
- Level 1's curves are flat (no banking) by design; the inner edges of
  curved slabs show faint facets from the block segments.
- Level 2's three stems per row merge into one bouquet from high above;
  invisible from the ball's camera.
- Level 3's hose radius blends linearly over the whole hose, so the "wide
  straight" is already narrowing slightly before the bends. A per-point
  radius would fix it if wanted.
- Level 2's scene file contains `;` comment lines; Godot drops them if
  you re-save the scene from the editor. Harmless.
- One commit on `garden-world` ("Backyard Garden theme and piece kit") is
  empty: its files landed in the commit before it. Message only; nothing
  is missing.
- Godot prints a few "Leaked instance dependency" warnings when a
  headless run quits. Engine noise, not ours.

## 18. New questions

**Q13. Garden models. Kenney's Nature Kit is CC0 but needs a browser
download. What do you want?**
- (a) You download it (kenney.nl/assets/nature-kit → Download) and drop
  the zip in `ballants-game/assets/models/`; I wire the flowers, grass and
  stones in through the manifest, scaled to ant size.
- (b) Keep the code-built garden; it reads fine for prototyping.
- (c) You'll source or make garden models yourself later.

**Q14. Camera for the garden levels (yours is 2.14 m, close):**
- (a) Keep it; the levels' landmarks are enough.
- (b) Move it back to 4–5 m and a bit higher for these courses.
- (c) Make camera distance a per-level setting in the level list.

**Q15. Par times (45 / 60 / 75 s; the bot does 29 / 30 / 22 s):**
- (a) Keep them loose for now.
- (b) Tighten to about 1.5× the bot time (45 / 45 / 35 s).
- (c) Add medals: gold = bot time + 20%, silver = par, bronze = finish.

**Q16. What happens after level 3?**
- (a) Loop back to level 1 (as now).
- (b) A "World complete" screen with all three times, then level 1.
- (c) Go to the test arena.

**Q17. Next for the level system:**
- (a) Checkpoints inside levels (restart from the last one).
- (b) A simple level-select menu (replacing the 1/2/3 keys).
- (c) Best times saved to disk and shown on the HUD.
- (d) A 4th garden level: you describe it, I build it.

## 19. Fluidity, backdrop and Joy-Con tilt steering (added after your playtest)

**Fluidity.** Physics interpolation is on: physics still steps 60 times a
second, but the ball, ant and camera are drawn at smooth in-between
positions, so a 120 Hz display no longer shows the ball jumping in steps.
If the game still feels *heavy* rather than *jerky*, that is
`roll_acceleration` (your saved 10.5; 16–22 is snappier) — F1.

**Backdrop.** Every garden level now sits inside scenery: a lawn far
below, a picket fence ring, bushes, giant trees, a house, giant flowers.
Settings on the GardenTheme node: `backdrop_radius`, `backdrop_lawn_y`,
`backdrop_enabled`.

**Tilt steering (Joy-Con, Switch Pro, DualSense, DualShock 4).** This
Godot build reads controller motion sensors natively (verified). Scheme,
on by itself when such a controller is connected (`gyro_steering` in F1):

| Action | Control |
|---|---|
| Accelerate | Left stick forward |
| Brake (never reverse) | Left stick back |
| Steer | Tilt the controller left / right, like a steering wheel |
| Recenter the tilt | Click the right stick, or **G** |
| Jump | A |

A small yellow bar at the bottom of the screen shows the tilt the game is
reading, with the controller's name and the angle in degrees. Tuning:
`gyro_max_tilt_degrees` (full lock), `gyro_deadzone_degrees`,
`gyro_smoothing`, `gyro_invert`.

**Pairing Joy-Cons on a Mac.** System Settings → Bluetooth; hold the small
round sync button on the Joy-Con's rail until the lights run, then pair.
Pair the right Joy-Con (it has the sensors we read); pairing both is
fine. If macOS shows them as two controllers, the game picks the first
one that reports motion sensors.

**Acceptance criteria (needs a controller; I could only verify the code):**
- With a Joy-Con connected, the control hint at the top changes to the
  tilt scheme and the yellow tilt bar appears at the bottom.
- Hold the controller the way you like and click the right stick (or
  press G): the bar centers.
- Tilt right: the bar's knob moves right and the ball curves right while
  rolling. If it curves left, turn on `gyro_invert` in F1 and tell me.
- Push the left stick forward: the ball accelerates the way it is
  heading. Pull back: it slows to a stop and does not reverse.
- A small wobble of the hand (under 3°) does not steer.
- Unplug / turn off the controller: the hint returns to keyboard text and
  WASD works as before.

**If the tilt axis is wrong** (e.g. tilting forward steers): the sensor
axes of a combined Joy-Con pair may be remapped by the OS. Tell me what
you see and I'll switch the axis; it is one line in `controls.gd`.

## 20. Finishing a level: the ant hill and the wipe to black

**What changed.** The spinning gold ring is gone. Every level (and the test
arena) now ends at an **ant hill**: a cone of fresh-dug dirt with a dark
hole in the top. Roll up the slope, drop into the hole, and the level is
done. `src/objects/goal.*` was deleted; `src/objects/ant_hill.*` replaces it
in all four scenes.

**The sequence** (all timings are constants at the top of
`src/core/level_manager.gd`):

1. The ball enters the catch zone over the crater. The clock stops. The
   ball's speed is cut to a slow roll so it can't skip across the hole, and
   it drops down a 3 m shaft inside the hill. The camera holds still so
   you watch the ball disappear. Input is ignored from here.
2. **0.6 s** later the screen wipes to black over **0.5 s**.
3. On the black: "Level complete!", the world and level name, your time
   (big), and "Under par by …" or "Par … (… over)". In the arena:
   "GOAL!" and the time.
4. **3 s** later the next level loads behind the black and the black lifts
   over 0.5 s. After level 3, level 1. In the arena, the arena reloads.
5. R or a level key at any point in the sequence cancels the rest and cuts
   straight to that level (no fade).

**The hill** (`ant_hill.gd`, built in code, numbers in the Inspector):

| Number | Default | Why |
|---|---|---|
| base_radius | 4.5 m | Footprint; fits every finish area (level 1's crack was shortened 2.5 m so it doesn't run under the hill) |
| height | 1.3 m | Slope ≈ 30°. With `roll_acceleration` 10.5 vs gravity-along-slope 5.0, the ball climbs it from a standstill |
| rim_radius | 2.0 m | The crater's edge; a shallow bowl funnels from here to the hole |
| hole_radius | 1.05 m | Wider than the ball (0.5 m) so it can never sit on the lip |
| shaft_depth | 3.0 m | Where the ball ends up, out of sight |

*Why the catch zone is in the air above the crater, not just in the hole:*
at 8 m/s the ball launches off the rim like a ramp and sails clean over
a 2 m hole (the bot did exactly that on level 1). So the zone is a
cylinder over the bowl; any ball crossing it is caught, slowed, and
dropped. The hill is on collision layers 1 and 2; a caught ball collides
with layer 2 only, so it falls down the shaft but through the dirt bed
the hill stands on. The shaft walls still hold it.

**New dev flags.** `--teleport=x,y,z` puts the ball somewhere right after
the level loads (picture or try one spot). A `--drive` run with
`--screenshot` now saves three pictures: the finish, the ball mid-drop
(`_drop.png`), and the results screen (`_results.png`).

**Acceptance criteria (play):**
- Approach any level's hill slowly: the ball rolls up, tips into the
  crater and falls into the dark hole; the camera stays put.
- Approach it at full speed: same result, no flying over, no bounce out.
- The timer on screen freezes the moment the ball is caught; the same time
  shows on the black results screen.
- The black screen holds about 3 s, then the next level fades in from
  black. Level 3 leads to level 1.
- Press R while the results are up: the current level restarts at once.
- Test arena: the hill on the raised platform does the same but shows
  "GOAL!" and reloads the arena.
- `./run_tests.sh`: 7 physics tests, 11 arena checks, 4 level drives all
  PASS; each drive prints that the next level loaded.

**Known issues**
- The level-complete screen is plain text on black for now (as asked).
  No sound hook fires beyond `Sounds.goal()`.
- The hill is a plain cone; ants, an entrance trail, or grass around the
  base can come with the art pass.

**Q18. The results screen should stay until:** — *Answered: (b), a button press. Done in section 21.*
- (a) 3 seconds pass, then the next level starts (current).
- (b) you press a button (any of A / Space / Enter), with a "Press A"
  hint.
- (c) 3 seconds, but a button skips the wait.

**Q19. When the ball is caught mid-air over the hill (a fast approach),
it is slowed and dropped in. Keep that, or:** — *Answered: (b), the
player must roll in themselves; once over the threshold the ball sinks.
Done in section 21.*
- (a) Keep: any approach finishes the level (current).
- (b) Only a ball that actually rolls into the crater counts; a flyover
  lands past the hill and you come back.
- (c) Keep, but add a visible "tractor" effect (dust ring, the hill
  pulses) so it reads as the hill grabbing the ball.

## 21. Your playtest round: finish, ant walk, bounce bug, sky, title area

**Q18 and Q19 (your answers).** The results screen now waits for you:
"[press any button to continue]" pulses under your time and any key,
controller button or mouse click moves on. It appears 0.6 s after the
results so a button you were still holding can't skip them. The ant hill
no longer grabs the ball out of the air. The threshold is checked against
the ball's center: it must be over the hole (inside the lip) and down at
crater height. Then the ball is taken out of the physics and sunk: it
slides to the middle of the hole and drops out of sight. The hill's
slope is now an S-curve: gentle at the foot, steepest in the middle,
flat at the rim, so a ball arriving at a sensible speed tips into the
crater. Measured: rolling in at 3.5, 6.9 and 8.2 m/s gets caught (center
0.12–0.14 m above the rim, so genuinely in the crater); a full-speed run
off level 1's downhill flies over and is not caught.

**Ant walk.** The old walk cycled 1.6 times per meter, which is 22 steps a
second at top speed, with feet only sliding back and forth. Now it is a
gait (`assets/placeholders/ant_placeholder.gd`, constants at the top):
- each back foot stays planted for 62% of the cycle, then lifts and
  swings forward; knees bend forward
- cadence 1.3–2.6 cycles per second (capped), longer strides when fast
- arms swing opposite the legs; the body dips at each footfall and sways
  toward the planted foot; antennae bob
- standing still: breathing and the odd antenna twitch
- above 9.5 m/s it crouches, shortens its steps and spreads its arms to
  balance, like someone log-rolling
- in the air the legs tuck up

**The random bounce on straight rolls (fixed).** Measured with a new
"pop" detector in the level bot: level 1 had 29 sudden upward kicks per
run (44 at top speed), up to 5 m/s, all on flat sidewalk where angled
slabs overlap on the curves. The physics engine catches the hidden
corner of one slab under its neighbour. Fix (`seam_smoothing` in the
tuning file, on): when the ball has been rolling on the ground and rays
straight down confirm the floor is still the same flat plane, any sudden
velocity away from that plane is removed. Ramps, crests, jumps and
bounce pads are untouched (a jump/bounce pad gives a grace period). After:
0 pops on flat ground in every level; the few left are real geometry
(the foot of the downhill, the round garden hose, ramp crests). New
physics test "angled overlapping slabs do not launch the ball": 2.23 m/s
with smoothing off, 0.05 m/s with it on.

**Objects with no collision (fixed) and the sky.** Those were the
backdrop: the fence/bush/flower ring was centered on each level's
origin, but the courses run 200 m from it, so giant flowers, bushes and
a house ended up right beside the track. Now:
- The sky is painted in code (`levels/garden/garden_sky.gdshader`): blue
  gradient, the sun (lowered so you can see it), puffy clouds, and a hazy
  neighbourhood on the horizon: rolling hills, a row of houses with
  roofs, windows and chimneys, and tree clumps between them. No image
  files, nothing AI-made.
- The far scenery you liked (fence, bushes, giant trees) stays, but the
  ring is centered on the course's collision and kept 70 m clear of
  anything you can touch. The near giant flowers and the 3D house are
  gone.

**Title area ("Title Meadow", the game now opens here).**
`levels/garden/title_meadow.tscn`. Until you touch anything, the camera
slowly circles the ant, pulled back, showing the scenery; "BALLANTS" sits
top-left with "move to play" pulsing at the bottom. First input: the
camera eases back behind the ball, the HUD comes in, the title shrinks
and the subtitle becomes "roll into the giant ant hill to start".
- **The funnel.** The ground is one sculpted surface: a clearing at the
  start, a valley that narrows and slopes gently downhill toward a giant
  ant hill (52 m across, 8 m tall), and a round hollow around it. Grassy
  berms rise on every side, so you drift back toward the middle. A worn
  dirt trail runs down the valley as a hint. No walls, no strict path.
- **Giant ant hill.** Same piece as the level finishes, with
  `enter_level = 0`: drop in and the screen wipes to black and Level 1
  loads (no results screen; there was nothing to time).
- **Thick grass** (`src/objects/garden/thick_grass.gd`), 12 patches. Roll in
  slowly and the blades bend away, push back on the ball and slow it
  down, then spring upright. Hit one faster than 6 m/s and it snaps: the
  broken blade tumbles away, dust puffs up, the ball loses 12% of its
  speed. Blades grow back after 12 s. Measured: at 10 m/s the ball snaps
  a line of 6 blades and comes out at 7.6 m/s; at 2.5 m/s holding forward
  no blades snap, they bend up to 0.65 rad and the ball pushes through.
- **Bugs** (`src/objects/critters/`, all built from shapes in code, at ant
  scale):
  - Ladybugs (5): wander with pattering legs; real physics bodies you can
    bump and shove; roll at one fast and it pops its wing cases and hops
    away.
  - Worms (3): inch around loops in the dirt with a ripple down the body;
    roll into one and it burrows, leaving a dirt mound, and resurfaces
    elsewhere.
  - Spiders (2 on the ground, 1 hanging from a flower on a silk thread):
    eight jointed legs in an alternating gait; ground spiders scuttle
    away when you come near; the hanging one climbs its thread.
  - Flies (5): perch on flower heads rubbing their front legs; take off
    when you approach, zig-zag around buzzing, land again.
  - Bees (3): fly lazy arcs from flower to flower and hover in a little
    figure-eight; jump into one and it spins off dizzy.
- **Other toys:** shove-able pebbles and acorns, a twig ramp, a bounce
  pad, a seesaw, solid giant flowers, static pebbles.
- Placing things in the meadow: pieces stand on the sculpted ground when
  it starts, so a piece's Y in the editor means "height above the
  ground".

**Keys.** **T** (or the controller's **View** button) goes back to the
title area. Correction to what I told you earlier: on your controller,
restart (R) is the **Menu/Start** button, not View.

**Acceptance criteria (play):**
- Launch: the title area, camera circling the ant, "BALLANTS" top-left,
  "move to play" pulsing, no HUD. Leave it for 20 s: it keeps circling
  and the ball stays put.
- Push the stick / a key: the camera swings in behind the ball, the HUD
  appears, the subtitle changes.
- Roll slowly into thick grass: blades bend away, you slow down, they
  spring back after. Ram it at speed: blades snap and fly, dust, you keep
  going. Come back 12 s later: they've regrown.
- Roll at a ladybug fast: it flies off. Into a worm: it burrows. Near a
  ground spider: it runs. Near a flower with a fly: it takes off. Jump
  into a bee: it spins.
- Follow the dirt trail downhill to the giant hill, climb it, drop in:
  black wipe, Level 1.
- In a level, reach its hill at full speed: you fly over and land past
  it. Come back slower and roll into the crater: the ball sinks, black
  wipe, results, "[press any button to continue]". Nothing moves on until
  you press.
- Roll the level 1 curves at full speed: no random hops.
- Look up and around in any level: sun, clouds, houses on the horizon; no
  flowers or bushes next to the track that you can roll through.
- The ant: walking looks like steps (feet lift and land, knees bend), not
  a blur; at top speed it crouches and balances with arms out.
- `./run_tests.sh`: 8 physics tests, 11 arena checks, 5 drives (3 levels,
  the level 2 shortcut, and the title area into level 1) all PASS.

**Known issues**
- The bugs have no sounds yet (sound hooks only, as before).
- Worms, spiders, flies and bees have no physical collision: they react
  to the ball instead of blocking it. Ladybugs are the physical ones.
- In the title area the ball can creep very slightly on the clearing's
  gentle undulations while the camera circles.

**Q20. Finishing level 3 should:**
- (a) Loop to level 1 (current).
- (b) Return to the title meadow.
- (c) A "Backyard Garden complete" screen with all three times, then the
  meadow.

**Q21. The bugs in the meadow:**
- (a) Fine as decoration with reactions (current).
- (b) Make them collectibles (bump all 5 ladybugs, etc.) with a counter.
- (c) Give some real physics (worms you can roll over like speed bumps,
  bees you can knock down).

**Q22. Thick grass resistance when pushing through slowly:**
- (a) As is (bends, slows you a little).
- (b) Stiffer: you really have to push, slow balls get turned aside.
- (c) Softer: mostly visual.
