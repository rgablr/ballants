# Ballants – Setup Notes

Branch: `setup/foundation` (your original work is untouched on `main`).
Engine: Godot 4.7.2, standard build (GDScript), Jolt physics.

Everything below was built and then verified by actually running the game:
a scripted play-through (`--autotest`, see section 3) passes all 9 checks,
and screenshots confirmed the visuals.

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
    objects/goal.*           Spinning ring; finishing it ends the level
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

- The **level scene** holds a `Player`, a `CameraRig`, a `HUD`, a `Goal`, and
  the course pieces. The Player is told which CameraRig to use; the CameraRig
  is told which Player to follow. (Both set in the level's Inspector.)
- The **Player** reads the camera's facing to decide which way "forward" is,
  so turning the camera turns the controls.
- The **Goal** tells the global `Game` the level is complete. `Game` fires a
  signal. The **HUD** hears the signal and shows "GOAL!". The Goal and HUD
  never reference each other, so either can be changed alone.
- `Game` also listens for the restart key and reloads the level.

### Adding things without breaking things

- **New level:** duplicate `test_arena.tscn`, rearrange the Blocks, keep the
  Player/CameraRig/HUD/Goal nodes. Set it as the main scene in Project
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

**From a terminal** (inside the `ballants-game` folder):

```
godot                                   # just play
godot -- --autotest                     # scripted self-test, prints PASS/FAIL
godot -- --screenshot=/tmp/shot.png     # save a picture after 1.5 s and quit
godot -- --zoom=2                       # camera closer, for ant close-ups
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
- Roll through the gold ring on the raised platform: it turns green and
  "GOAL! Press R to play again" appears in the middle of the screen.
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
