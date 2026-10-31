# Ballants – Game Design Document

Status: prototype. Last updated 2026-10-31.

Technical terms are defined the first time they appear, in *italics*.

---

## 1. Concept

**Ballants** (balance + ants) is a 3D physics platformer about an ant
balancing on top of a rolling ball. You steer the ball; the ant rides it.
The ball is heavy and keeps its momentum, so every turn has to be planned
and every obstacle is a chance to be thrown off course. The ant's body is
your speedometer and your warning light: it leans into where you're
pushing and gets flung against every sudden change, so you can *see*
momentum before it bites you.

One-line pitch: *Super Monkey Ball's weight and momentum, with a character
on top of the ball who shows you exactly how out of control you are.*

## 2. Core mechanic

**Roll a heavy ball with momentum, read it through the ant.**

- Holding a direction pushes the ball. It takes about a second to reach
  top speed and several seconds to coast to a stop. Turning at speed makes
  a wide arc, not a corner.
- The ant on top is purely visual (it has no *collision*, the invisible
  shape the *physics engine*, the part of the game engine that simulates
  movement, gravity and collisions, uses to decide what touches what). It
  leans toward your input immediately and is thrown against acceleration,
  braking and turns on a springy, wobbly lean.
- Levels are built from momentum tests: banked curves that reward
  committing, narrow paths that punish oversteer, ramps into gaps, and
  piles of light objects to send flying.

The ant falling off the ball as a fail state is **deliberately not built
yet** (see open questions). Today you lose only by falling off the level.

## 3. Controls

| Action | Keyboard / mouse | Controller |
|---|---|---|
| Roll | W A S D | Left stick |
| Jump | Space | A (bottom face button) |
| Look around | Mouse (or arrow keys) | Right stick |
| Restart level | R | Start |
| Free / grab the mouse | Esc / click | — |
| Tuning panel (dev) | F1 | — |
| Debug overlay (dev) | F2 | — |

Movement is **camera-relative**: "forward" is wherever the camera faces.
The camera swings behind your direction of travel by itself; looking
around with the mouse or stick holds for about a second, then it eases
back. Holding **S** reverses you *without* flipping the controls mid-swing:
the control direction is frozen while you hold back, the camera swings
around, and when you let go "forward" is simply the way you're now going.

## 4. Goals

- **Per level:** reach the ant hill and drop into its hole. Later: within a time, collecting
  things, or without the ant falling off (see questions).
- **Per session:** master momentum. The learning curve is "I keep
  overshooting" → "I can feel how far I'll slide" → "I'm using momentum on
  purpose" (banked curves, jumps off ramps, chain reactions).

## 5. Game feel principles, as they apply to Ballants

Each principle below names where it lives in the code so it can be tuned
(press F1 in game, or edit `ballants-game/config/physics_tuning.gd`).

**1. Responsive input.** The push is applied the same *physics step* (one
tick of the physics engine; the game runs 60 per second) the key is read,
so the ball's speed changes within 1–2 steps (verified by an automated
test). The sideways part of a push gets a boost (`turn_assist`) so a turn
*begins* at once even though the ball's momentum still carries it. The ant
leans toward the input the instant it's pressed (`ant_input_lean`), before
the ball has visibly moved. These are small cheats on top of real physics,
exactly as Super Monkey Ball fakes it.

**2. Weight and momentum.** Weight is felt through acceleration, not the
mass number: `roll_acceleration` is modest compared with `max_speed`, and
`rolling_resistance` is low, so the ball is slow to start and slow to
stop. Turning is physics: the sideways push has to overcome forward
momentum, so turns are arcs. Props are much lighter than the ball
(`crate_mass`, `light_box_mass` vs `ball_mass`) so they go flying while
the boulder (`boulder_mass`) shoves the ball around.

**3. Exaggerated feedback ("juice").** The ant's lean is a damped spring
driven by minus-acceleration, so it's thrown back when you accelerate,
forward when you brake, outward in turns, and wobbles afterwards
(`ant_lean_stiffness`, `ant_lean_damping`). Any sudden speed change above
`impact_small` makes dust and squashes the ball along the impact axis;
above `impact_big` it also shakes the screen (`shake_strength`) and
freezes the game for a few frames (`hit_pause`). The ant squashes on
landing and stretches on take-off. Field of view widens with speed. Sound
is out of scope, but every event already calls an empty hook in
`src/core/sound_hooks.gd`.

**4. Predictability.** Fixed 60 Hz physics step. No randomness in movement.
Floor tiles are merged into one physics body at level start so the ball
can't catch on the seams between them (`StaticMerger`; this fixed a real
0.4 m pop found by the tests). A speed-scaled `ground_stick` pulls the
ball onto ramp crests so it doesn't pop off small bumps. The automated
tests check seams and crests every run.

**5. Emergent play.** Crates, light boxes, dominoes, a boulder, a seesaw
and bounce pads are all real physics objects that affect each other. The
test arena has a domino run, a box pyramid, boxes on a tilted ramp and a
field of boxes to plough through. Props are spawned by a reusable
`PropSpawner`, so a new chain-reaction setup is one node.

**6. Tuned, not realistic.** Gravity is 18 (Earth is 9.8) so jumps and
falls are snappy; `air_control` lets you steer in the air; `coyote_time`
lets you jump for a moment after rolling off an edge; `jump_buffer_time`
counts a jump pressed just before landing. Jump height is set directly in
meters (`jump_height`) and the launch speed is computed from it, so every
jump is the same height regardless of what the ball was doing.

**7. Stable simulation.** Jolt physics, fixed step, *continuous collision
detection* on the ball (the engine sweeps the ball along its whole path
each step instead of checking only its end position, so it can't skip
through thin walls), enhanced internal-edge handling, and tests that
drive the ball through a 10 cm wall at twice top speed, drop it on a
10 cm platform, and leave a crate stack alone for seconds to confirm it
doesn't jitter.

## 6. Level structure

**Undecided: platform levels vs. open world.** The prototype supports
both: the test arena is an open field with courses in it, and the first
world (Backyard Garden) is three linear courses with a start, a goal, a
run timer and a par time, chained in order by the level system. See Q5
in SETUP_NOTES.md. The level kit (Blocks, CurvedTrack, PropSpawner, the
garden pieces, Goal, FallZone, SlickPatch, BouncePad, Seesaw) works
either way.

**World 1: Backyard Garden.** Seen from an ant's size: grass blades taller
than the ball, flower stems like tree trunks, pebbles like boulders, a
sidewalk like a highway, a hose like a bridge. Level 1 *Sidewalk Crack*
teaches speed and steering, level 2 *Flowerbed Slalom* teaches turning
with momentum, level 3 *Garden Hose Bridge* teaches balance and careful
speed. Each level's design notes live next to its scene in
`ballants-game/levels/garden/`.

### The title area

The game opens in the **Title Meadow**: the title over a playable garden
clearing. The camera circles the ant until the player moves; a sculpted
funnel (berms, a gentle downhill, a dirt trail, never a wall) leads to a
giant ant hill that starts Level 1. Around it: thick grass to bash
through, bugs that react (ladybugs, worms, spiders, flies, bees), and
loose pebbles and acorns. It teaches rolling, braking and jumping before
any clock is running, the way the old test arena did, themed.

## 7. Art direction

Low-poly, simple and consistent. Flat colors, soft sky, strong readable
silhouettes. The ball is a soccer ball for now (customizable later). The
ant is the star: it must read at a glance from behind and above, which is
why it stands upright on its back legs rather than crawling. Everything
on screen must be human-made or properly licensed (no AI-generated
assets), so the game won't need Steam's AI-content disclosure.

## 8. Roadmap: prototype to Steam

Each milestone ends with something playable and a decision.

**M0 — Foundation (done).** Ball, ant, camera, test arena, tuning panel,
debug overlay, automated tests, feel pass.

**M1 — Feel lock (1–2 weeks).** Play, tune with F1, decide the balance
fail state (Q1), the camera behavior, and jump rules. Exit: the ball
feels right and the ant's lean is readable to a new player.

**M2 — First real level (2 weeks).** One hand-built course, 1–3 minutes,
start → three momentum tests → goal. Checkpoints and a fall-reset.
Decide platform vs. open world after playing it. Exit: a stranger can
finish it and wants to retry for a better run.

**M3 — Vertical slice (4–6 weeks).** 3–5 levels in one visual theme,
placeholder-but-consistent art, real ant and ball models, first audio
(roll, jump, land, impacts, goal), a main menu, pause, level select,
basic save. Exit: a 10-minute demo that shows the whole loop.

**M4 — Content (8–12 weeks).** 20–30 levels across 3–4 themes, the full
obstacle kit (moving platforms, tilting floors, wind, ice, breakables),
medals/times, ant customization. Steam page goes up; a demo for Next Fest.

**M5 — Polish and ship (6–8 weeks).** Controller remapping, settings,
accessibility (camera options, assist modes), localization of UI text,
achievements, performance pass, trailer, launch.

## 9. Open questions

Collected in SETUP_NOTES.md as multiple-choice questions. The biggest
one: **what does the ant losing its balance mean for the player?**
