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

**Q20. Finishing level 3 should:** — *Answered: back to the title with a world-complete message. Done in section 22.*
- (a) Loop to level 1 (current).
- (b) Return to the title meadow.
- (c) A "Backyard Garden complete" screen with all three times, then the
  meadow.

**Q21. The bugs in the meadow:** — *Answered: they stay friendly; add ant predators as enemies. Done in section 22.*
- (a) Fine as decoration with reactions (current).
- (b) Make them collectibles (bump all 5 ladybugs, etc.) with a counter.
- (c) Give some real physics (worms you can roll over like speed bumps,
  bees you can knock down).

**Q22. Thick grass resistance when pushing through slowly:** — *Answered: stiff, slows you, never bounces you aside. Done in section 22.*
- (a) As is (bends, slows you a little).
- (b) Stiffer: you really have to push, slow balls get turned aside.
- (c) Softer: mostly visual.

## 22. World complete, enemies, stiffer grass (your Q20–Q22 answers)

**Q20 – after level 3.** Level 3's results, then a second card:
"Backyard Garden complete!", this session's time for each of the three
levels and the total, "[press any button to continue]", then the title
meadow. (A level you didn't play this session shows a dash.)

**Q22 – thick grass.** The grass now holds you back straight against the
way you're rolling and never shoves you sideways. Measured, holding
forward from 2.5 m/s: you come out of a patch at 4.0 m/s, against 7.6 m/s
across open ground. Ramming at 6 m/s or more still snaps blades.

**Q21 – enemies (ant predators).** The friendly bugs stay friendly. Four
predators from your list, all built from shapes in code
(`src/objects/enemies/`):
- **Ground beetle** (2): a big glossy black beetle on long legs with
  curved jaws. Patrols its patch; when it spots you (8 m) it **rears up
  and opens its jaws** for 0.7 s, then charges in a straight line at
  6 m/s. It can barely turn mid-charge, so sidestep. Then it rests.
- **Tiger beetle** (1): metallic green, copper legs, huge eyes. Like the
  real thing it sprints and stops: **crouch** 0.4 s, sprint 0.55 s at
  9 m/s, stop and look 0.6 s, repeat. Change direction while it's
  stopped. You can outrun it (top speed 14 m/s).
- **Antlion pit** (2): a sand ring with a funnel; the antlion's head and
  big jaws stick out at the bottom. Inside the funnel the sand slides you
  toward the middle and it flicks sand at you; its **jaws open wide** the
  moment you're over the rim. Reach the bottom and they snap. Roll back
  out (a slog) or jump out; a fast ball can cross without stopping.
- **Dragonfly** (1): a 2 m blue dragonfly patrolling a loop 6 m up. When
  it spots you (12 m) it **stops, hovers and points its nose at you** for
  a full second, then dives in a straight line at where you were. Move or
  jump during the hover and it misses, pulls up and climbs back.

Fairness rules every enemy follows: it has a home patch and never chases
far out of it (you can always escape by leaving); it warns before
attacking; it rests after an attack. They're all off to the sides of the
meadow, away from the dirt trail: you can go straight to the giant hill
without meeting one (the title drive test proves that path stays clear).

**Getting knocked off.** Touching an enemy throws the ant off the ball:
it flips through the air away from the enemy, lands on its back with its
legs kicking, and "Knocked off!" shows. In a level, the level restarts
from the start (like falling out). In the title meadow (and test arena)
the screen dips to black and you're back at the spawn.

Measured (each enemy with the ball parked in its patch): antlion pit
1.2 s, ground beetle 0.3–1.5 s, tiger beetle 0.9–1.0 s, dragonfly 1.6–1.7 s
to knock the ant off; the ball was back at the spawn every time. In
level 1, a knock-off showed "Knocked off!" and restarted the level.

Not built yet from your list: assassin bugs, phorid flies, eucharitid
wasps, robber flies, bombardier beetles. Robber flies would be a variant
of the dragonfly (perch, dart); bombardier beetles a beetle that sprays a
hot cloud behind it. Say the word.

**Acceptance criteria (play):**
- Finish level 3: results, press, then "Backyard Garden complete!" with
  times, press, and you're in the title meadow.
- Thick grass: rolling in slowly, you plough through slowly and come out
  straight; nothing bats you sideways.
- Walk up to a ground beetle: it rears up with jaws open, then charges.
  Sidestep: it runs past. Get hit: the ant flips off, lands on its back,
  "Knocked off!", black dip, back at the spawn.
- Tiger beetle: crouch, dash, stop, crouch, dash. Out-run it.
- Antlion pit: over the rim the jaws open and you slide inward; push out
  or jump out before the bottom.
- Dragonfly: it stops overhead and points at you; move and it misses.
- No enemy bothers you on the trail straight to the giant hill.
- `./run_tests.sh`: all PASS (level 3's drive now ends in the title area).

**Q23. Enemies in the three levels:**
- (a) Only in the meadow for now (current).
- (b) Add a few to each level now (a beetle on level 1's goal plateau, an
  antlion pit in a wide part of level 2, a dragonfly over level 3's banks).
- (c) Save them for World 2 and keep World 1 enemy-free as the tutorial.

**Q24. Next predators from your list:**
- (a) Bombardier beetle (sprays a cloud behind it; the cloud knocks you off).
- (b) Robber fly (perches, darts at you fast in short hops).
- (c) Assassin bug (slow stalker that ambushes from thick grass).

## 23. Big title, hit feedback, void holes, ant moves, customize menu

- **Title.** "BALL" over "ANTS", sized from the window to fill the
  top-left quarter of the screen. When you start it shrinks into the
  corner (0.7 s). The prompt also says "C / Y: customize your ant".
- **Getting hit.** A red glow around the screen edges that fades out
  over 1.6 s, and "A ground beetle attacked you!" (or tiger beetle,
  antlion, dragonfly) in the middle.
- **Ant hill holes.** The inside of every hole is unlit and fades to pure
  black just under the lip, so it reads as a bottomless void.
- **Ant: jumping.** In the air the legs kick and the arms wave over its
  head (and the antennae thrash).
- **Ant: crawling.** At 75% of top speed and up it drops onto all six
  legs: body flat along the top of the ball, front and middle legs
  stepping in a tripod gait with the back legs, knees up like an insect.
  It stands back up below 68% (the gap stops it flickering between the
  two at one speed).
- **Ant: sharp turns.** The harder you turn (sideways acceleration from
  7 m/s², full at 16), the more it rocks side to side over the ball and
  windmills its arms, like it's about to fall off. Comes on fast, fades
  slowly.
- **Customize menu.** C (keyboard) or Y (controller), anywhere; the game
  pauses. Your ant appears big in the middle of the screen, standing on
  its ball and slowly turning. Beside each part, at that part's height, a
  row with arrows: Antennae, Eyes, Head, Thorax, Abdomen, Legs; under the
  ball, Ball. The selected part glows on the ant.
  - Up/Down choose, Left/Right change, B / Esc / C close. Mouse clicks on
    the arrows work too.
  - Body parts: 13 colors. Antennae and legs: 9. Eyes: 7.
  - Balls (all perfect spheres, so physics is unchanged): soccer ball,
    basketball, volleyball, beach ball, tennis ball, baseball, bowling
    ball, 8-ball, golf ball, playground ball. All drawn in code.
  - Changes apply instantly to your ant and ball in the game, and are
    saved on your computer (kept next time you play).

**Acceptance criteria (play):**
- Launch: the title fills the top-left quarter; move and it shrinks away.
- Get hit by any enemy: red edges fading out, "A <insect> attacked you!".
- Look into an ant hill hole: black void.
- Jump: legs kicking, arms waving. Roll at near top speed: the ant drops
  onto six legs and scuttles; slow down and it stands up. Turn hard at
  speed: it wobbles and windmills.
- Press C / Y: the customize screen; change every part and the ball;
  close; your ant and ball look like that in the game. Quit and relaunch:
  still the same.
- `./run_tests.sh`: all PASS.

## 24. Sound and music

The game had no sound before this. Now it does.

**Sound effects** (all Kenney CC0 packs, listed in ASSET_CREDITS.md):
- Rolling: a soft rumble that gets louder and higher the faster you roll, and goes quiet in the air.
- Jump "boing", grassy landing (a heavy thud after a big fall), bumps and thuds when you hit things.
- Thick grass makes a snap when you break a blade.
- Bees buzz quietly when you're close.
- Enemies make a scratchy chitter when they spot you and wind up (the ground beetle rearing, the tiger beetle crouching, the dragonfly aiming, the antlion's jaws opening). It's a sound warning on top of the visual one.
- Getting hit: a punch and a sad falling tone. A little pop when you're put back at the spawn.
- Rolling into an ant hill's hole: a falling whistle.
- Results: a short jingle for level complete and another for world complete. The music dips out of the way for them.
- Menus: clicks for open, close, moving between rows and changing a value, plus a confirm sound for "press any button" and for starting from the title.

The rolling rumble and the bee buzz are made in code (filtered noise and a hum), like the placeholder models. They can be swapped for recordings later.

**Music:** four CC0 songs from OpenGameArt by human composers, all uploaded 2016–2021 (before AI music tools were common): "Green Hills", "Sunflower Valley", "Summer Sunday" and "Napping on a Cloud". They play in a shuffled loop at a faint volume (about -18 dB) under the sound effects.

**Music on/off:** in the customize menu (C / Y), bottom left, next to the Ball row. Left/right switches it. It's saved to `user://settings.cfg`.

How it's built: `src/core/sound_hooks.gd` (global `Sounds`) plays effects by nickname from the asset manifest's SOUNDS table. `src/core/music.gd` (global `Music`) plays the songs. Effects and music are on separate mixer channels ("SFX" and "Music"), so either can get its own volume slider later. The music stays silent during the headless automated tests.

Known limits: I can't hear the game, so the volumes come from the numbers. If anything is too loud or too quiet, tell me which sound. Each one has a single volume number in `sound_hooks.gd`, and the music level is `VOLUME_DB` in `music.gd`.

**Questions:**
- **Q25.** Volume sliders? (a) a Music volume and an Effects volume slider in the menu, (b) on/off is enough for now
- **Q26.** Different music per area? (a) one calm song for the title meadow and the other songs in the levels, (b) keep shuffling all of them everywhere

## 25. Crawl on top of the ball, quieter fast rolling, bug bumps, enemy drone

- **Crawling ant stays on top.** At full speed, the ant's lean toward where you're pushing (up to about 47°) slid it round the front of the ball. While crawling, the lean is now cut to 20%, so it runs along the top, within about 4° of upright at full speed. The crawl pose also sits a little higher so the running legs show.
- **Quieter at speed.** The rolling rumble is loudest at a medium roll and eases off toward top speed. It's also quieter overall (about -24 dB at its loudest, -29 dB at top speed). This also fixes a bug where, on screens faster than 60 fps, the rumble kept dipping toward silence.
- **Bumping friendly bugs** (ladybug, spider, fly, bee, worm) makes a bouncy pluck from where the bug is, at most once a second per bug.
- **Enemy drone.** A low, uneasy hum (two slowly beating tones a tritone apart) fades in from about 13 m from the nearest enemy and is strongest within 3 m. It's made in code, so it isn't beeping. Measured: silent at 19 m, -36 dB at 8.5 m, -18 dB up close.

## 26. No more flailing after landing; a landing somersault

- **The bug:** after a jump, the ball bounces about 25 cm on landing (ball bounce 0.47 in the tuning file), and on the bumpy meadow it also loses ground contact for a moment. The ant's "in the air" pose followed the ball's ground contact exactly, so it kept flailing and looked like it was hovering for up to half a second while the ball rolled on.
- **The fix:** a jump puts the ant in the air straight away. Otherwise the ant only counts as airborne when there's more than 0.5 m of gap under the ball, and as landed again at 0.12 m. Landing bounces and bumps stay under that, so they no longer set off the flailing. The ball's own bounce is unchanged.
- **The somersault:** after more than 0.35 s in the air (any real jump or drop), the ant does one quick forward roll over its middle with a little spring up (0.45 s), then is back standing and running. Short hops and bumps don't trigger it.

## 27. Lazy camera, mouse-only tuning panel, ant gap fix, stronger turn sway

- **Lazy camera (new default).** The camera keeps its spot in the world and turns to keep the ball in view. It's dragged along only when the ball gets farther than `camera_distance + camera_lazy_slack` (2.14 + 2.5 m), and backs off only when the ball comes closer than `camera_distance`. Rolling in small circles, you watch the circle. Rolling toward the camera pushes it back, so reversing never needs a camera turn. Mouse or right stick still turns it, and it stays where you put it (only the up/down tilt eases back). In the F1 panel:
  - `camera lazy`: off = the old chase camera.
  - `camera lazy slack`: how far the ball can get before the camera follows.
  - `camera lazy swing`: an optional very slow drift round behind you; 0 = none.
- **F1 panel is mouse-only.** Sliders, checkboxes and buttons never take keyboard or controller focus, so you can drive and tune at the same time. The mouse wheel scrolls the list instead of nudging the slider under the pointer.
- **Ant floating above the ball, fixed.** A hard bounce (or a jump) during the landing somersault cut it off partway without putting the ant back down. Ending a somersault early now always resets the ant onto the ball (also when knocked off).
- **Turn sway (teetering) is easier to see.** It was there before but only kicked in on very sharp turns (sideways acceleration over 7 m/s², full at 16). A hard turn only reached about 38%. It now starts at 4 m/s² and is full at 10, and the ant rocks further (0.42 rad) and windmills its arms more. A hard turn now reaches full sway.

## 28. Lazy camera: stick always relative to the camera

- **The problem:** holding down (toward the camera) eventually sent the ball past the camera, then rolling away from it while you still held down. Two causes:
  1. An old chase-camera rule froze the control direction while you held back.
  2. When the camera was pushed back it also turned to face the ball. Each turn rotated the controls a little, and the ball curled round the camera.
- **The fix:**
  1. With the lazy camera on, the stick is always simply relative to the camera (the freeze still applies to the chase camera).
  2. When you roll at the camera, it backs straight up along its view without turning. It only turns when you're inside its comfortable range or pulling it along.
  3. Distances are measured from the ball's real position, not the slightly trailing camera rig, so it can't be caught.
- **Result:** holding down for 5 s (with a sideways wiggle) keeps the ball heading straight at the camera the whole time, with the camera a steady 2 m ahead.

---
---

# Part D – The anthill hub and its opening cutscene (2026-10-31, overnight)

Branch: `anthill-hub` (made from `garden-world`; its first commit is the
F1 tuning you had saved but not committed). Four commits: the hub cave,
the arrival and cutscene, then tests and these notes.

## 29. What was built, in plain words

**The story loop now goes:** title meadow → roll into the giant ant hill →
you drop through its top into **the anthill hub** (a cave) → the Queen
asks for help (first time only) → five tunnels lead to the levels →
finishing a level puts you back in the cave in front of that tunnel.

**The cave** (`levels/hub/anthill_hub.tscn`, everything built by code in
`src/objects/hub/`):
- A round cave 52 m across and 21 m tall: flat floor (gently bumpy away
  from the middle and the tunnels), walls leaning outward, a dome, and a
  hole at the very top with daylight pouring through it as a visible
  shaft. Warm browns and oranges, dim, with glowing fungus clusters low on
  the walls and amber crystal clusters higher up, each with its own small
  light. One mesh, one collision shape; the ball can never leave.
- About 46 **small holes** on the walls and ceiling: a dirt lip with a pure
  black, unlit disc set just inside it, and a collision plug behind the
  disc. Too small for the ball (0.9 m across vs the 1 m ball) and blocked
  anyway.
- 14 **worker ants** (code-built, six legs, no collision) live in the holes:
  they wait, poke their head out and look around, then duck back, or
  crawl across the wall and ceiling to another hole and disappear into it.
- **5 tunnel mouths** around the floor, each a dirt collar around an arched
  passage that fades to black 11 m in. The level's name arches over the
  mouth in chunky 3D letters sunk into the collar. Tunnel N is entry N of
  `levels/level_list.gd`: 1–3 are the garden levels, 4–5 are empty
  placeholder strips (`levels/nest/`). Rolling ~5 m into an open tunnel
  loads the level. A **locked** tunnel is choked with rubble (solid), with
  the number of crystals still needed standing on it and a glowing,
  turning sugar crystal hovering above the number. Unlock costs live in
  the level list too (`crystals_required`: 0, 0, 0, 2, 4 for now).
- A **jail cell** between tunnels 1 and 5: a smaller alcove closed by an
  arched door of bars (the same shape as the opening) that swings out on
  a hinge and slams shut.
- The **Queen's hole**, low on the wall between tunnels 1 and 2.

**Progress** (`src/core/progress.gd`, a global): crystals, which levels
have paid out, the Queen's gift, whether the intro has played. A level's
first finish at or under par earns one crystal. **Nothing is saved to
disk yet**: it all resets when the game closes. When saving is built,
`Progress` is the one object to serialize. The HUD shows your crystal
count top-right (always in the hub, elsewhere once you have one).

**Arrival.** Coming from the meadow (or `--hub`, or key H) the hero
appears 17.5 m up under the top hole and falls. A camera on the cave floor
tracks the fall up the light shaft. Landing: dust, the ball squashes, the
camera shakes, the ant somersaults. Control is locked during the fall. Coming
back from a level you appear in front of that level's tunnel, looking into
the cave, no fall.

**Opening cutscene** (first arrival per session): the camera glides in on
the hero's face, cuts to the Queen's hole, the Queen (twice a worker's
size, a gold crown of spikes, a big banded abdomen) crawls out, down the
wall and across the floor with the camera following, settles 3 m from the
hero facing it, and the dialogue runs exactly as you wrote it, with the
camera on whoever each line names. Hero lines show "..." under "You" with
a head tilt / a double blink. The question shows "Yes (Space) / No (N)" or
"Yes (A) / No (B)" depending on what you touched last.
- **Yes:** her last line, then a small glowing orb floats from her to the
  hero, "Received: the Queen's gift (placeholder)", the camera glides back
  behind the hero, and the hub is yours.
- **No:** she gets furious (eyes glow red, black brows scowl, steam puffs
  out of her head, her head shakes), says her banishment line, the jail
  door swings open, she stomps round behind your ball and swings her
  thorax into it: the ball flies across the cave, through the doorway,
  smacks the back of the cell and bounces back to the middle, and the door
  slams shut. Then a black circle closes in on the hero, "Game Over" for
  two seconds, and the title meadow fades in. **The title meadow is the main menu** for now
  (see Q29).
- **Skip:** hold Esc / Start for 1 s (a small bar fills top-left). Jumps to
  the end as if you'd said Yes (gift given, no popup).

**The cutscene system** (reusable; `src/cutscene/`):
- `cutscenes/hub_intro.json` – the script: sections of steps (camera,
  wait, line, choice, actor action, scene action, give_item, game_over,
  goto, end). Lines carry speaker, text, camera target and an optional
  gesture. Edit wording there; nothing in code knows the words.
- `cutscenes/characters.json` – per character: display name, typing speed,
  voice (pitch, blips per letters, variation, length, wave, loudness) and
  named camera framings (face / wide / walk / fall).
- `src/cutscene/cutscene_style.gd` – the one place for the text box's
  look, default typing speed and pauses, voice defaults, camera defaults
  and the skip hold time.
- `cutscene_player.gd` runs a file, owns the cutscene camera and the
  text box, locks the player (`Game.control_locked`) and the dev keys
  (`Game.cutscene_active`), and hands the camera back with a glide.
- `dialogue_box.gd` – the transparent black box to the right, name above,
  letter-by-letter typing, ▼ when done, the two-way choice, the popup.
- `voice_synth.gd` – the babble: short pitched tones computed in code (no
  recordings, no AI), one every 2–3 letters, pitch per letter (vowels
  higher) with a random nudge. The Queen's is low, buzzy and slow.
- Any node can be a cutscene actor by having
  `cutscene_action(action, step, player)`; the Queen (`CaveAnt`) does
  emerge / walk_to / face / nod, the hub does `jail`.

**Keys added:** 4, 5 (levels), **H** (hub), **U** (debug: all tunnels count
as open; the HUD says so), Esc/Start held (skip a cutscene), N / B (the
"No" answer). Dev flags: `--hub`, `--hubtest=yes|no|skip`,
`--shots=1,3.5,8` (timed screenshots with `--screenshot`),
`--press=jump@3,dialogue_no@6.5`.

## 30. Files

```
ballants-game/
  levels/level_list.gd              + crystals_required, HUB, two nest entries, is_last_of_world()
  levels/hub/anthill_hub.tscn/.gd   the hub: builds the cave, arrival, cutscene hookup, jail sequence
  levels/nest/level_4_placeholder.tscn, level_5_placeholder.tscn
  src/core/progress.gd              global Progress (crystals, unlocks, flags)  ★ to be saved later
  src/objects/hub/cave_shell.gd     cave mesh + collision, cuts, small holes, wall parametrization
  src/objects/hub/arch_builder.gd   arch collar mesh + collision (tunnels, jail)
  src/objects/hub/tunnel_entrance.gd  mouth, letters, rubble + number + crystal, trigger
  src/objects/hub/block_letters.gd  the 5x7 block font
  src/objects/hub/jail_cell.gd      the barred alcove
  src/objects/hub/cave_ant.gd       worker ants and the Queen
  src/objects/hub/cave_decor.gd     fungus, crystals, daylight shaft
  src/cutscene/cutscene_player.gd, dialogue_box.gd, voice_synth.gd, cutscene_style.gd
  cutscenes/characters.json, cutscenes/hub_intro.json
  src/ui/transition.gd              + game_over(center): iris wipe + "Game Over"
  src/core/level_manager.gd         + load_hub, enter_level_from_hub, enter_hub_through_hill, hub return
  src/core/controls.gd              + last_device (keyboard / controller)
  src/player/player_ball.gd         + control lock, set_spawn, teleport
  assets/placeholders/ant_placeholder.gd  + neck pivot, play_gesture
  src/core/dev_tools.gd             + --hub, --hubtest, --shots, --press@time
```

## 31. Acceptance criteria (test by playing)

**Getting there**
- Title meadow → drop into the giant hill: black wipe, then you are
  falling inside a cave, seen from below, down a shaft of daylight.
  You cannot steer or jump while falling.
- The landing: a burst of dust, the ball flattens and springs back, the
  picture shakes, the ant does a somersault. No big bounce back up.
- Press **H** anywhere: the hub loads with the same fall. Press **R** in
  the hub: it reloads with the fall (no cutscene the second time).

**The cave**
- Roll around freely with the normal controls; the ball never leaves the
  cave; the walls stop you; the floor is flat in the middle and gently
  uneven toward the edges (no hops on it).
- It is dim but readable: warm brown walls, orange glowing fungus near the
  floor, amber crystal clusters higher up, a bright shaft of daylight in
  the middle, a disc of sky when you look up through the top hole.
- Dozens of small holes on the walls and ceiling, each with a lip and a
  pitch-black inside (no light ever shows anything inside, from any
  angle). Ants poke their heads out and look around, crawl between holes
  along the walls and ceiling, and vanish into them.
- Roll at a low hole on the wall: you bump off the wall; you can never get
  into a hole.
- Five tunnel mouths around the floor with the level names arched over
  them in block letters: SIDEWALK CRACK (straight ahead when you land),
  FLOWERBED SLALOM, GARDEN HOSE BRIDGE, PLACEHOLDER 4, PLACEHOLDER 5.
- Tunnels 1–3 are open: roll in, it gets dark, the screen wipes to black,
  that level starts. Tunnels 4 and 5 are choked with rubble with a glowing
  turning crystal over a "2" and a "4". Roll into the rubble: solid.
- Press **U**: the rubble tumbles away and both tunnels open (the HUD
  says "debug: all tunnels open"). Press U again: rubble is back.
- Finish any level: results card as before, then the hub fades in with
  you in front of that level's tunnel, facing the cave. No fall, no
  cutscene. Finish level 3: the "Backyard Garden complete" card first.
- Finish a level under par for the first time: the crystal count top-right
  goes up by one. With 2 crystals, tunnel 4's rubble clears by itself the
  next time you are in the hub (or at once if you are there).

**Opening cutscene (first arrival per session)**
- About a second after landing the camera glides in on your ant's face
  (its antennae and arms sway a little), then glides to a spot on the
  floor halfway between you and the Queen's hole (off to the side) and
  looks up at the hole. The camera never goes into a wall.
- The Queen crawls out of the hole (the only ant that ever comes fully
  out), down the wall and across the floor; the camera stays put and pans
  to follow her all the way to you. She turns to face you. She is clearly bigger than the workers, with a
  crown and a big striped abdomen.
- Each line: the speaker's name above a see-through black box on the
  right, text typing letter by letter with babbly blips (hers low and
  slow, yours higher and quicker). The camera is on whoever the line
  belongs to; between lines it pans. Hero lines show "..." with a head
  tilt (first) and a double blink (second).
- Press Space/A while typing: the whole line appears. Press again: the
  next line. A ▼ pulses when a line is waiting.
- "Can you help us?" → "Yes (Space)   No (N)" with the keyboard, or
  "Yes (A)   No (B)" if you last touched the controller. Touch the other
  device and the labels swap live.
- You cannot move, jump, restart or switch levels during the cutscene.
- **Yes:** "Oh, thank goodness…", a glowing orb floats from her to you,
  "Received: the Queen's gift (placeholder)". Then she's delighted: happy
  squinting eyes and rosy cheeks, she rears up on her back legs, hops
  twice and claps her two front legs together six times (a little click
  each clap). She turns and crawls back across the floor, up the wall and
  into her hole; about a second and a half into that walk the camera
  glides back behind you, the HUD returns and you can move while she
  finishes going home.
- **No:** the Queen's eyes turn glowing red, black brows scowl, steam
  puffs from both sides of her head and she shakes it; then "In that
  case…". The jail door swings open on its hinge (out into the cave, never
  through the dirt), she walks behind your ball, winds up and swings her
  thorax: dust, a thud, the ball flies in an arc across the cave and
  through the doorway, smacks the back wall of the cell (dust, squash,
  shake), bounces back to the middle. The door slams shut and rattles. A
  black circle closes in on you, "Game Over", the title meadow fades in.
- Hold Esc (or Start) for a second at any point in the cutscene: a
  "skipping..." bar fills top-left, the scene ends at once as if you'd
  said Yes, you can play. Tapping Esc does not skip (it only frees the
  mouse as before).
- Quit and relaunch: the cutscene plays again (no saving yet).

**Terminal:** `./run_tests.sh` ends with `RESULT: all checks passed`:
8 physics tests, 11 arena checks, 5 level drives (each now reporting it
came back to the hub by its own tunnel, e.g. "0.1 m from tunnel 1's
mouth"), and three hub runs (`--hubtest=yes`, `no`, `skip`) that check
the fall, the landing, the cutscene, both answers, the skip, the locked
tunnel, a small hole, tunnel 1 loading level 1, and the return.

## 32. Known issues and notes

- **Nothing is saved yet.** Crystals, the gift and "intro seen" live in
  `Progress` for one session. The intro replays every launch. Saving
  needs to be built (Q17c is the natural place).
- Crystals are earned only by a first finish under par; the hidden bonus
  crystals and the per-level time limit from your story notes are not
  built (see Q28).
- Pressing **R** in the hub reloads it with the fall (the hub has no
  other "start"). Fine for testing; say if the fall should be once only.
- The title meadow is standing in as the main menu (game over goes
  there). A proper menu screen is Q29.
- During a camera pan between the Queen and the hero the view sweeps
  across the wall for a moment; a cut (`"move": 0`) on those lines would
  avoid it if you prefer cuts.
- The Queen stays where she stopped after the scene (no idle wander).
- The worker ants walk straight between holes in wall coordinates, so a
  path can cross a tunnel's letters or a fungus cluster; they have no
  collision so nothing breaks, it just looks odd up close now and then.
- The hero's "face" shot shows the ant from in front and a little to the
  side; the ant doesn't turn to look at the Queen while she talks.
- Pre-existing: with your saved tuning the arena's seesaw check could not
  tip the plank with a 0.087 kg crate; the check now drops the boulder.
- Pre-existing engine noise in headless runs ("Leaked instance
  dependency", "get_nodes_in_group on a null value" during the physics
  tests) is unchanged.
- Letters use a code-built block font: Godot's TextMesh can't cut the
  Nunito font (overlapping outlines) and Kenney's font pack needs a
  browser download.

## 33. Questions for you

**Q27. The Queen's gift. What is it and what does it do?**
- (a) A sugar crystal pouch: a counter / the thing crystals go into
  (cosmetic, explains the HUD count).
- (b) An ability: e.g. a short speed burst or a double jump, used with a
  button, for the levels ahead.
- (c) A map / compass: in a level, points toward the hidden bonus crystal.
- (d) A key or token that opens tunnel 1 (so the first tunnel is locked
  until you've said yes).
- (e) Something else — tell me what it looks like and what it does.

**Q28. Crystals per tunnel (now 0 / 0 / 0 / 2 / 4) and how they're earned
(now: first finish under par = 1 crystal):**
- (a) Keep: garden tunnels open, nest tunnels cost 2 and 4.
- (b) Only tunnel 1 open at the start; 1 / 2 / 3 / 4 crystals for the
  rest (one new tunnel per under-par finish).
- (c) Build the full story rule now: each level has a time limit (fail
  but keep playing), a par crystal, and a hidden bonus crystal placed in a
  tricky spot; tunnels cost more (e.g. 0 / 1 / 2 / 4 / 6). I'd place the
  bonus crystals; you'd tell me if they're too easy/hard.
- (d) Your own numbers: ____ / ____ / ____ / ____ / ____.

**Q29. The main menu. "Game Over" now returns to the title meadow.**
- (a) Keep the meadow as the menu (it already has the title, the start
  and customize).
- (b) Add a real menu screen (Start / Customize / Quit, maybe Continue
  once saving exists) before the meadow.
- (c) A menu screen that replaces the meadow entirely; the hub is the
  first thing you play.

**Q30. Levels 4 and 5 are placeholders named "Placeholder 4/5" in the world
"Inside the Nest". When you're ready: what are they?** Give me a name and a
one-paragraph description each (setting, the momentum test, the hazard)
and I'll build them like the garden ones.

**Q31. Saving (needed for crystals, the gift, "intro seen", best times):**
- (a) Build it now: one save file, autosave on every level finish and
  hub arrival, a "New game" option that wipes it.
- (b) Later, after more levels exist.

**Q32. The arrival fall plays every time you enter the hub from the meadow
or press H / R there.**
- (a) Keep.
- (b) Fall only the very first time; afterwards you roll in through
  tunnel 1's mouth (or appear in the middle).

**Q33. Cutscene camera between lines:**
- (a) Smooth pans (as built, 0.9 s).
- (b) Hard cuts.
- (c) Pans between the same speaker's lines, cuts when the speaker changes.

## 34. Fixes from your first look (2026-11-01)

- **Queen's entrance camera** no longer goes through the wall. It stands
  on the floor halfway between the hero and her hole (4 m off to the
  side, 2.4 m up), looks at the hole, and pans to follow her down the wall
  and across to the hero. New framing option for cutscene files:
  `"between": ["actor", "actor"]` with `fraction`, `side`, `height`/`y`.
- **Angry Queen on "No":** red glowing eyes, scowling black brows, steam
  puffing from both sides of her head, a furious head shake (new actor
  action `{"do": "actor", "actor": "queen", "action": "mood", "mood":
  "angry"}`). Then she bats the ball into the cell with a thorax swing
  instead of the ball rolling in by itself; it bounces off the back wall.
- **Jail door** is now an arched door of bars the same shape as the
  opening, hinged on its left edge; it swings out into the cave to open
  and slams shut with a rattle. It never passes through the dirt.
- **Watermark** "made by rgablr" in the bottom-left corner of every screen
  (title, levels, hub, black screens). The speed readout moved up to make
  room. Text and look: `WATERMARK` at the top of `src/ui/transition.gd`.
- Dev flag `--autoplay=yes|no` presses through cutscene dialogue with that
  answer (pair with `--shots`).

Acceptance criteria:
- Fresh hub arrival: when the camera leaves the hero it ends up on the
  cave floor looking up at a hole; you never see the inside of a wall.
  The Queen crawls out and the view turns to follow her down and across.
- Answer No: her eyes glow red, brows scowl, steam puffs, then the line.
  The jail door swings open sideways (not up). She walks behind the ball,
  rears back and swings into it; the ball flies into the cell, hits the
  back wall, bounces, and the door slams shut. Game Over, title.
- "made by rgablr" sits in the bottom-left corner on every screen,
  including the black results and Game Over screens, and doesn't overlap
  the speed readout.

## 35. The Queen celebrates and goes home (2026-11-01)

After you accept and get her gift, the Queen celebrates (happy eyes, rosy
cheeks, rears up, two hops, six claps of her front legs), then crawls back
to her hole. Control returns while she is on her way, so you don't wait
for the whole walk; she disappears into her hole on her own a few seconds
later. Skipping the cutscene puts her straight back in her hole.

New actor actions in cutscene files: `celebrate` (`claps`), `go_home`
(`speed`, `await: false` to let the scene carry on, `instant: true`), and
`mood` now also takes `"happy"`.

Acceptance criteria:
- Answer Yes: after "Received…", the camera is in front of her; she
  rears up, hops and claps her two front legs together in front of her
  face, looking happy (squinting eyes, pink cheeks). Then she turns and
  walks off toward her hole, the camera turning to follow.
- Shortly after she sets off you can roll again; she climbs the wall and
  vanishes into her hole.
- Hold Esc/Start to skip: she's gone (back in her hole) when you get
  control.
- `./run_tests.sh` passes; the Yes run checks she ends up in her hole.


---

# Part E – Sugar crystals and the five nest levels (2026-11-01)

Branch: `anthill-levels` (made from `anthill-hub`). First commit: the
Queen's legs now stay on her body while she rears up, claps and sits
down (the legs hung off the ant node while the body was its own node;
hips now follow the body). Then the crystal system and nest theme, level
1, and the four levels built by subagents on branches
`level/egg-chamber`, `level/fungus-farm`, `level/worker-rush`,
`level/collapsing-gallery`, merged back here.

## 36. The crystal system

**Four sugar crystals per level** (`src/core/progress.gd`):
1. **Finished** – reach the ant hill.
2. **Target time** – finish at or under the level's target (`par_time` in
   `levels/level_list.gd`; the HUD now says "target").
3. **Hidden 1** and 4. **Hidden 2** – two `HiddenCrystal` pickups placed
   in the level (`src/objects/hidden_crystal.tscn`, `which` = 0 or 1).

Each counts **once**: replaying keeps your best. A hidden crystal is
yours the moment you roll through it (a restart or a fall afterwards does
not take it back; see Q34). Once owned it shows as a faded **ghost**
(no glow, no light, slower spin) you can still roll through; nothing
happens. Finishing and the target time are checked at the goal.

**The pickup**: a glowing six-sided crystal (the same one that hovers
over locked tunnels), slowly turning and bobbing, with its own light; a
sphere pickup zone a little wider than the crystal. Rolling through it:
a rising three-note chime made in code (`Sounds.crystal`, no
recording), a burst of glowing shards, a flash, and the crystal shrinks
away.

**The results card** (`src/ui/transition.gd`) now shows the time, the
target ("Target 1:25.00 – beaten by 0:11.53" / "– 0:04.10 over") and a
row of four crystal icons with names: bright with a sparkle and "NEW!"
when earned on this run, plain "(earned before)" when you already had it,
a dim outline "–" when not. A line under them: "+3 sugar crystals (3 of 4
from this level, 7 in the pouch)".

**The Crystal Pouch** is the Queen's gift (Q27 answered as (a)): the
cutscene now floats a small leather pouch with a crystal in its mouth
from her to you, "Received: the Crystal Pouch". The HUD's top-right
counter reads "Crystal Pouch  N / 20" with a crystal icon: always in the
hub, elsewhere once you have the pouch or any crystal; in a level a
second line "this level ◇ ◇ ◆ ◇" shows that level's four. 20 = four
crystals in each of the five tunnel levels (the unassigned garden
levels' crystals count in N but not in the 20).

**Unlocks** (`crystals_required` in the level list): tunnels 1–3 open,
tunnel 4 needs **5**, tunnel 5 needs **8**. The rubble clears by itself
when you reach the count (animated if you are in the hub).

**Dev / test:** `--drive` files may carry `"expect_hidden": [0, 1]`; the
drive FAILS unless those hidden crystals were collected, and every drive
prints which crystals the run earned. `Progress.debug_set_crystals(n)`
fills slots in level order (the hub test uses it to check 4 → 5 → 7 → 8).
Key **U** still opens everything.

## 37. The tunnels and the garden levels

`levels/level_list.gd` is now: 1 Tunnel Drop, 2 Egg Chamber, 3 Fungus
Farm, 4 Worker Rush, 5 Collapsing Gallery (world "Inside the Nest"), then
the three Backyard Garden levels marked `"unassigned": true`. The hub's
tunnels are the first five entries (`LevelList.TUNNEL_COUNT`). Nothing of
the garden was deleted: keys **6 / 7 / 8** load Sidewalk Crack, Flowerbed
Slalom and Garden Hose Bridge; finishing one returns you to the middle of
the hub (no tunnel to stand in front of). Their drive files are now
`tests/levels/level_6_sidewalk_crack.json`, `level_7_flowerbed_*.json`,
`level_8_garden_hose_bridge.json`.

## 38. The anthill theme and the nest kit

`levels/nest/anthill_theme.tscn` (drop it in a level like the garden
theme): pitch-dark background, warm brown fog, a faint fill light, glow;
colors in `AnthillTheme.COLORS`, shared materials via
`AnthillTheme.material("dirt")`. There is no sun: every path is lit by
glowing fungus or amber crystals (`GlowFungus`, `WallCrystal`), and the
track piece plants fungus along its walls by itself.

Pieces in `src/objects/nest/` (all code-built, collision separate):
- **DirtTrack** – the workhorse: a smooth ribbon of packed dirt through a
  list of points (up and down hill), with walls on either side per
  point, an optional ceiling (a tunnel), banking, a visible thickness,
  and fungus every N meters. One triangle-mesh collision of exactly the
  surface, folded into the level's single static body (the merger now
  takes any body with `merge_collision`), so there are no seams to
  catch on. `frame_at(distance)` places things on it.
- **DirtWall** (lumpy straight wall, box collider), **FalseWall** (looks
  like a wall, no collision: hides a shortcut; `subtlety` 0–1), **Root**
  (a bent root through points, solid or not, with rootlets), **GlowFungus**
  (amber or blue-white, with light), **WallCrystal**, **DirtSlab** (a box).

## 39. Level 1 – Tunnel Drop (teaches speed control)

Full notes and the measurements table: `levels/nest/level_1_notes.md`.
The scene is generated from a cursor walk (`tools/make_tunnel_drop.py`),
one 114-point DirtTrack 477 m long dropping 70 m, plus the shortcut
tunnel. Target time **1:25**; the bot's clean run 1:07, the shortcut run
1:06 (narrow and steep, it saves little), a careful first run 3–4 min.

1. **Gentle slope** – 100 m, 10 m wide, walls both sides, soft bends.
2. **First open edges** – 7 m wide; two 9 m-radius bends with no outer
   wall (an amber crystal cluster marks each edge). Full speed slides off.
3. **Switchbacks** – four 5 m-radius hairpins down a 12° slope, walls both
   sides. Brake to ~6 m/s before each or hit the wall.
4. **The plunge** – a crest, then 50 m at 31° (the ball passes its push
   cap, ~11 m/s), a 30 m flat landing, a walled right curve and the ant
   hill on a plateau.

Hidden crystals:
- **Shortcut** – at the apex of hairpin 1 a 4.6 m section of the outer
  wall is a FalseWall (same shape and lean, looser dirt, loose clods, two
  thin cracks). Behind it a 2.8 m tunnel with a ceiling and blue fungus
  drops at 14°, hairpins, and comes back through the outer wall at
  hairpin 3's apex (you pop out sideways; brake). The crystal floats at
  the tunnel's far bend. Skips two turns and two legs.
- **Ledge** – at the crest before the plunge, a pocket in the right wall
  behind a thick root arching over the uphill half of the opening. From
  the approach you see the root and nothing behind it; the crystal sits
  in the pocket's uphill-back corner. Stop at the crest and look back and
  it is plain.

## 40. Acceptance criteria – crystals, tunnels, theme, level 1

**Crystals**
- Finish any nest level for the first time: the results card shows four
  icons; "Finished" is bright with NEW!, "Under m:ss" bright if you beat
  the target, the hidden ones bright only if you rolled through them;
  the others dim outlines. The line under them counts them and the pouch.
- Finish the same level again: everything you already had reads "(earned
  before)" in plain icons; only new ones say NEW!. The pouch total never
  counts a crystal twice.
- Roll through a hidden crystal: chime, burst of shards, a flash, it
  shrinks away; the HUD's "this level" line gains a ◆ at once. Press R:
  it is still yours; the crystal is now a faded ghost you roll through
  with no effect.
- The HUD top-right reads "Crystal Pouch N / 20" in the hub, and in
  levels once you have the pouch; the cutscene's gift is a small pouch
  and the popup says "Received: the Crystal Pouch".
- Tunnels 4 and 5 are choked until the pouch holds 5 and 8; press U to
  open them for testing. With exactly 4 crystals tunnel 4 stays shut;
  the fifth clears its rubble (animated if you are in the hub).
- Keys 6, 7, 8 load the three garden levels; they still play as before
  and their finish returns you to the hub's middle. 1–5 load the nest.

**Level 1 – Tunnel Drop**
- From the start, hold forward: the wide walled slope keeps you on
  whatever you do; the fungus lights make the next bend visible.
- Section 2: enter the first open bend at full speed without braking and
  you slide off the open outside ("Fell out!", restart); at ~8 m/s or
  with an early turn you make it.
- Hairpins: arriving above ~6.5 m/s you bump the outer wall and lose
  speed; a tap of brake before each one gets round cleanly.
- The plunge: the ball runs away past its usual top speed; the flat
  landing gives room to brake for the final curve; overshoot the curve
  and the wall stops you.
- Shortcut: at hairpin 1's apex the outer wall has a slightly looser,
  cracked section; rolling at it goes straight through into a narrow lit
  tunnel that drops, bends and pops you out sideways into hairpin 3; the
  crystal is in the tunnel's bend. From hairpin 3 you can also roll INTO
  the tunnel's exit and climb it backwards.
- Ledge: at the crest a big root arches across a gap in the right wall;
  turn in behind it (downhill side of the root) and the crystal is in the
  pocket's back corner. Rolling over the crest at speed you never see it.
- Target: a clean run with good braking finishes under 1:25 without the
  shortcut.
- `./run_tests.sh`: three level-1 drives PASS (main, shortcut with hidden
  crystal 0 collected, ledge with hidden crystal 1 collected).

## 41. Levels 2–5 (built by four Opus subagents in parallel, then merged)

Each level has its own notes next to its scene
(`ballants-game/levels/nest/level_N_notes.md`) with the full table of
measurements and the physics values they depend on, the builder's
acceptance criteria and its questions. Each scene is generated by a
script in `ballants-game/tools/` (edit the script, re-run it). Each has
three bot drives in `tests/levels/` (main route, hidden 0, hidden 1).
Target times below are what each builder recommended; I set them in the
level list. The highlights:

**Level 2 – Egg Chamber** (teaches turning; bot 0:55; target **1:02**).
One round nursery chamber 48 m across, floor at y = 4, a dome overhead;
it is closed, so nothing can fall out. (1) **Egg rows**: an 88 m lane
fenced by rows of pale eggs 1.85–2.1 m tall (too tall to jump), a soft S,
a wide U-turn and a left bend, all makeable at full speed. Clip a row and
the eggs squash and nudge you back out at 2.5 m/s plus 15% of your hit
speed; the speed along the row is kept (`egg_knock_speed`,
`egg_knock_bounce`, `egg_squash` in F1). (2) **The bowl**: a U-shaped
skate bowl, floor 10 m wide, legs 14 m, the wall curving from flat to 85°
with the rim 9 m up; an egg row splits the legs and ends in a heap that
leaves only a 1.2 m groove on the floor (good for ~5.6 m/s), so the fast
way round is up on the wall. (3) **Spiral ramp**: a 6.5 m shelf hugging
the outer wall, 200° round, 166 m long, rising 10 m, wall outside, open
drop inside. (4) **Nursery bridge**: 104 m, 3.8 m wide, no walls, 10 m
above the egg lane, ending on a central egg mound with the ant hill.
Hidden 0: 7.6 m up the bowl's round end, straight ahead of the west leg:
9.7 m/s at the foot of the wall collects it, 9.2 m/s falls 0.3 m short.
Hidden 1: a corner nook behind three egg heaps at the last bend, 9 m
off the fast line. New pieces: `nursery_chamber.gd`, `egg_bowl.gd`,
`egg_pile.gd`, `egg_mound.gd`. A fall off the bridge or spiral lands you
on the floor; you roll back to the spiral's foot (about 35 s lost).

**Level 3 – Fungus Farm** (teaches jumping; bot 0:49; target **1:10**).
About 230 m, floors at y = 8–31. (1) **Small hops**: six raised dirt beds
with furrows of 3, 3.5, 4, 4.5 and 5 m between them; the furrows are
1.2 m deep with a floor, so a missed jump costs a jump back out, not a
restart. (2) **Bounce patches**: glowing caps set into the floor throw you
up a 4 m ledge; then a 21 m pit with three stepping mushrooms zig-zagging
7.5 m apart (each bounce lasts ~2 s, so your speed sets how far you fly;
the pit has a floor and caps that throw you back up). (3) **Spore floors**:
pale slick floors (`spore_grip` 0.3) right before gaps over the void: 6 m
onto a bed 0.5 m higher, 4 m onto an 8 m island (too much speed
overshoots), 4.5 m rising 1 m, then 8 m of spores into a 6.5 m gap onto
the tower plaza. (4) **Mushroom tower**: a floor cap, then three caps in
a left-turning spiral each 4.5 m higher; the exit ledge with the ant hill
is 17.5 m above the plaza; a miss drops you to the plaza. Hidden 0: a
blue-white launcher cap (`mushroom_tall_bounce_height` 12.5) throws you
onto a tall solid amber mushroom with the crystal; rolling off it lands
on tower cap 3 (slower than the clean tower for the bot). Hidden 1: a
4 m opening in the right wall of the long spore run leads to a spur of
spores, 3.5 m of dirt and an open edge; the crystal is round the corner
in a walled nook; come in fast and you slide off the end. New pieces:
`bounce_mushroom.gd` (bounce height `mushroom_bounce_height` 6.5; the
launch speed corrects for the engine's air damping so the peak is
within 0.3 m), `spore_patch.gd`, `spore_cloud.gd`, `dirt_bed.gd`.

**Level 4 – Worker Rush** (speed control and timing; bot 1:04; target
**1:15**). 341 m of flat corridor at y = 4, walls everywhere, no open
edges. Worker ants (CaveAnt at 2.8× scale, ~1.4 m long, carrying chunky
pale crumbs) march on fixed loops keyed to a clock that starts when the
scene loads (not the run timer) and restarts with it, so every run is
identical. (1) **Single line**: 7 workers cross the path at 1.5 m/s,
4.5 m apart: one every 3 s, the gap open ~1.2 s of each beat. (2)
**Crossing lines**: two lanes 4 m apart in opposite directions (1.8 m/s,
5 m apart); the gaps line up ~0.8 s of each 2.8 s beat. (3) **Crumb
highway**: 97 m, an oncoming lane left (2 m/s, 10 m apart) and a lane
going your way right (1.4 m/s, 7 m apart), crumb piles forcing four lane
changes. (4) **Storage gate**: a 4 m sliding dirt door on a 4 s cycle,
open 1.8 s, lamps flicker the second before it opens, one worker walks
through every opening; the ant hill in a 22 m chamber behind it. A bump
throws you straight out from the ant (`worker_knock_speed` 6 m/s,
`worker_knock_lift`, `worker_knock_keep`, `worker_bump_grace`; speed and
spacing per line in F1). Hidden 0: one highway worker carries a glowing,
twinkling crystal on its crumb; bump it and it drops a real pickup 1.6 m
behind the ant, once per run. Hidden 1: at the end of section 2's long
workers' tunnel, round a bend, reached by rolling up the middle between
the two lanes. New pieces: `worker_line.gd`, `storage_gate.gd`,
`crumb_pile.gd`.

**Level 5 – Collapsing Gallery** (combines everything; bot 0:52; target
**1:05**). About 400 m and 421 collapsing tiles, floors from y = 12 down
to 4.9, a near-black plane underneath so every hole reads as a pit. A
tile (`collapsing_tile.gd`) notices the ball over its top, waits, cracks
(fresh cracks, a rattle that grows, dust, a crunch), then its collision
goes off and it tumbles away; timers count physics steps, so it is the
same every run, and a restart brings every tile back. Normal tiles are
gone 1.3 s after the touch (`tile_crack_delay` 0.55 + `tile_fall_delay`
0.75; per-area scales `gallery_*` in F1). (1) **Warning floor**: three
tile patches at 2.6× slower (gone 3.4 s after the touch); touching the
first also makes three tiles of the next patch fall ahead of you as a
demo. (2) **Crumbling corridor**: normal tiles on straights, a right arc
and an S-bend, with solid dirt islands as the only safe places to stop.
(3) **Collapsing curves**: three curves on wedge tiles in 3 lanes
(centerline radius 9.6 m, outer wall only); the row before each curve
triggers the whole inside lane, gone 0.39 s later, forcing the
middle/outer line. (4) **Final sprint**: a 31 m collapsing slope
(5°–12°, tiles gone 0.65 s after the touch) into a 6 m jump onto a walled
goal plateau 1 m lower. Hidden 0: a 2 m tile bridge off the right wall
across a 4 m void to a ledge; its countdown starts on the row before it,
so you must turn onto it at once; a fast bridge leads back. Hidden 1: a
2.4 m opening half hidden by roots into a one-tile-wide 9.6 m dead end;
entering starts every tile's clock and the entrance is gone 3.8 s later:
roll in, bounce off the end wall, roll straight out. Ceiling dust is
`falling_dust.gd`.

## 42. Acceptance criteria – levels 2–5

**Level 2 – Egg Chamber**
- Every lane bend fits at full speed on the centerline; brushing an egg
  row gives a soft bump and a slide along it, never a dead stop, and a
  row cannot be jumped.
- The bowl: carving its round end up on the wall keeps your speed; on
  the floor it only fits slowly through the groove.
- A full-speed run straight up the west leg collects the high crystal;
  slightly slower falls short.
- The pocket behind the egg heaps at the last bend before the bowl holds
  the second crystal; the fast line never sees it.
- The spiral climbs the outer wall to a ledge; the bridge has no walls
  and ends on the mound. Falling off either lands you on the floor and
  you can always roll back to the spiral's foot.
- A clean run with the carve finishes under 1:02.

**Level 3 – Fungus Farm**
- Each furrow clears with a jump at the lip at moderate speed; you can
  jump back out of one.
- Rolling onto any floor cap throws you up the 4 m ledge. On the stepping
  mushrooms, arriving at 3–4 m/s and steering toward the next cap lands
  on it; full speed overshoots. A pit floor cap returns you to the ledge.
- Spore floors look different (pale, puffballs, drifting spores) and
  feel slick: no real braking or sharp steering on them. The 6 m and
  6.5 m gaps need near top speed set on the dirt before the spores.
- Each tower bounce reaches above the next cap, the last lands on the
  exit ledge, a miss drops to the plaza.
- The blue cap throws you onto the tall mushroom's cap (crystal); rolling
  off west continues the climb. Entering the spore spur slowly lets you
  reach the nook; fast slides you off the end.
- A clean run finishes under 1:10 without the tall-mushroom shortcut.

**Level 4 – Worker Rush**
- Section 1: the line crosses in an even beat; rolling flat out without
  looking you get bumped about half the time; after watching one beat
  you get through every time.
- A bump throws you back 2–3 m with dust, a shake and a plip; you are
  never pushed off the course and never bumped twice by one touch.
- Press R at any moment: the ants are exactly where they were at the
  same time after load on the previous attempt.
- Crossing lanes: once per beat both can be crossed at speed. Highway:
  four forced lane changes; the oncoming lane can be crossed by moving
  sideways through a gap.
- The glinting worker is visible in the right-hand highway lane, drops
  its crystal once when bumped, and the crystal can be picked up.
- Gate: lamps flicker before it opens, one worker goes through every
  opening, the shut door is solid.
- The workers' tunnel crystal is not visible from the main route.
- A clean run under 1:15 needs you to read every rhythm; lucky gaps and
  bumps (1.5–3 s each) do not.

**Level 5 – Collapsing Gallery**
- First patch: nothing for about 1.4 s, then it rattles, cracks and
  puffs dust, and drops about 3.4 s after the touch. R brings every slab
  back. From the first patch, three slabs of the next patch fall by
  themselves ahead of you.
- Stopping on a section 2 tile drops you about 1.3 s later; the plain
  dirt islands are safe.
- In each tight curve the inside lane crumbles ahead of you as you enter.
- The slope crumbles right behind you; jumping off the last row lands on
  the plateau; rolling off without a jump drops short.
- Ledge: turn onto the bridge at once and you make it; brake first and
  the bridge is already falling. Dead end: grab the crystal and come
  straight back and you get out as the entrance cracks.
- Two runs of the same inputs give the same collapses; a clean run beats
  1:05.

## 43. Merge and the step-6 checks

Branches `level/egg-chamber`, `level/fungus-farm`, `level/worker-rush`,
`level/collapsing-gallery` were merged into `anthill-levels` (kept as
branches; their worktrees removed). The only conflicts were in the two
shared files every builder appended to, `config/physics_tuning.gd` (a
section of tunables per level plus their slider ranges) and
`ASSET_CREDITS.md` (one code-built row per level); both sides were kept.
After the merge I set the four target times the builders recommended,
and fixed the F1 panel's section-heading pattern so the new "LEVEL N:
NAME" groups show under their own heading (it did not accept digits or
colons; every level's sliders were landing under "Interactive Objects").
The F1 Save round-trip still writes the file back unchanged.

Checked after the merge: `./run_tests.sh` ends with `RESULT: all checks
passed` (8 physics tests, the arena, 20 level drives, 3 hub runs):
- Tunnels 1–5 load Tunnel Drop, Egg Chamber, Fungus Farm, Worker Rush,
  Collapsing Gallery (the hub test rolls into tunnel 1 and finishes that
  level; the drives load each by index). Keys 6/7/8 load the garden
  levels and their drives still pass.
- Tunnel 4 stays locked at 4 crystals and opens at 5; tunnel 5 stays
  locked at 7 and opens at 8; at 0 the rubble is back (hub test).
- Every level completes by bot; every hidden crystal is reached by a
  drive that expects it (3 drives per nest level, 4 for the garden, the
  title); the crystals earned print on every drive and are awarded once
  (a second finish shows them as "earned before").
- Worker timing and collapse timing: both builders checked two runs of
  the same drive (identical worker positions at a fixed clock; finish
  times within a few hundredths, which is the HUD's frame timing, not
  the ants or tiles).

## 44. Known issues after Part E

- **Nothing is saved to disk**: crystals, the pouch, "intro seen" all
  reset when the game closes (Q31 again, now more pressing).
- **Hidden crystals are kept the moment you touch them**, even if you
  fall right after (the dead end in level 5, the bowl in level 2). See
  Q34.
- **Bot "pops"**: the level bot reports an upward kick wherever the ball
  leaves the ground: every mushroom bounce, every jump it makes itself,
  and climbing the bowl wall all count. They do not fail a drive; the
  pop list is only useful on flat courses (level 1 and 4 report none).
- **Level 1**: the false wall is a straight slab in a curved wall gap, so
  up close the real wall's ends show either side of it; the shortcut's
  exit mouth in hairpin 3 is plainly visible (Q37).
- **Level 2**: on the bowl wall the ball counts as airborne above
  2 m/s of climb or past 60°, so steering there is weaker; about 60
  small lights, not checked on a slow machine; the hidden-0 drive
  depends on a measured 7.17 m climb and needs re-measuring if physics
  change (if `max_speed` drops below ~9.5 the crystal is out of reach).
- **Level 3**: at 0:49 for the bot the level is at the short end of the
  60–90 s range; landing just outside a cap's rim bounces you up but
  kills sideways speed; the mushroom sets the ball's private
  `_time_since_grounded` so a jump pressed on landing cannot replace the
  bounce.
- **Level 4**: workers have no solid body, so the ball overlaps their
  legs for an instant before the knock; workers walk through the dropped
  crystal and the fungus; a worker can be seen popping in or out of a
  hole if you look straight into it from inside a side tunnel; the
  closing gate shoves a trapped ball sideways; changing a line's spacing
  in F1 rebuilds the line (its workers jump); a bump is big enough to
  trigger the ball's own big-impact shake and freeze. The drives are
  timed to the current rhythms: change a line's speed/spacing or the
  gate period and they need re-timing.
- **Level 5**: tile coordinates must be written to 5 decimals (a 1 mm
  mismatch popped the ball 3 m/s); about 420 tiles each run a cheap
  check every physics step, not profiled on weaker machines; the ledge
  drive logs one 1.2 m/s pop where the angled bridge overlaps the
  corridor.
- Pre-existing: headless runs print "Leaked instance dependency" and a
  few `get_nodes_in_group` error lines from the physics test runner.
- The results card's crystal row is about 100 px taller than before; on
  a 720p window everything still fits.

## 45. Questions for you

**Q34. A hidden crystal is yours the instant you roll through it, even
if you fall or restart right after.**
- (a) Keep: grabbing it is the achievement.
- (b) Only count it if you then finish the level (dropped on a fall or
  R). The results card would show it as NEW! at the finish.
- (c) Keep it on R, lose it on a fall.

**Q35. Target times (now 1:25 / 1:02 / 1:10 / 1:15 / 1:05, each about
1.2–1.4× the bot's clean run).**
- (a) Keep.
- (b) Looser for a first release: 1:40 / 1:15 / 1:25 / 1:30 / 1:20.
- (c) Add a third tier later (gold = bot + 10%) and keep these as the
  crystal line.

**Q36. The three garden levels are unassigned (keys 6/7/8). Where should
they go?**
- (a) A second world after the nest, with three more tunnels in a new
  cave (I'd add a second hub room or a passage).
- (b) Three more tunnels in the same hub (eight mouths; the cave would
  need widening).
- (c) Keep them as a bonus reachable from the title meadow's giant hill
  area or a menu.
- (d) Leave them unassigned for now.

**Q37. Level 1's shortcut exit is an open tunnel mouth in hairpin 3's
outer wall.**
- (a) Keep: it hints that a shortcut exists and lets curious players
  climb in backwards.
- (b) Hide it with a second false wall (you'd burst out through it).

**Q38. Falling off level 2's bridge or spiral lands you on the chamber
floor and costs about 35 s of climbing.**
- (a) Fine: no restart, it's the punishment.
- (b) Fail and restart, like every other level.
- (c) An egg cushion with a ramp back to the ledge.

**Q39. Level 4's worker bump (6 m/s, with the ball's big-impact shake and
freeze).**
- (a) Keep.
- (b) Softer (4 m/s) and only dust and the plip, no shake.
- (c) Harder (9 m/s).

**Q40. Level 5's normal tile: gone 1.3 s after the touch.**
- (a) Keep.
- (b) Faster (0.9 s): stopping anywhere is death.
- (c) Slower (1.8 s): kinder for a first world.

**Q41. Level 3's safety nets (furrows with floors, a pit floor, a miss
on the tower dropping to the plaza).**
- (a) Keep them: it's the jumping tutorial.
- (b) Make the later gaps real (the void) once the furrows are learned.

**Q42. The pouch total reads "N / 20" (four per tunnel level). When the
garden levels get tunnels their crystals would join the total.**
- (a) Fine.
- (b) Show only N (no total).
- (c) Show the per-world total in the hub instead.

Each level's notes file carries its builder's own questions too (bounce
height, spore grip, gate rhythm, which worker carries the crystal, the
warning demo, tile look); say the word and I'll pull them up here.
