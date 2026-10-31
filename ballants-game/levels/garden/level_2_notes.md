# Level 2 -- Flowerbed Slalom: design notes

**Skill taught:** turning with momentum. The ball carries its speed, so a
turn has to be started *before* the gap, and the tighter the gaps come,
the slower you must arrive. Hitting a stem bounces you back at about half
speed; falling into the water furrow restarts the run.

**Target time:** 30-90 s for a first-time player. The waypoint bot does the
normal line in about 30 s at 7 m/s (`tests/levels/level_2.json`); a fast
bot run (9-11 m/s) takes 26 s, a slow one (5 m/s) 44 s. The shortcut line
takes the bot about 26.5 s (`tests/levels/level_2_shortcut.json`). Par in
the level list is 60 s.

The course runs from the start at z = +3 toward -Z and ends at z = -186.
The raised dirt bed has its top at y = 0; water furrows (Puddle pieces =
water sheet + FallZone) lie on both sides at y = -1.5 over a dark soil
block, with a lawn far below. A single big FallZone at y = -8 catches
anything else.

## Course, section by section

Every "row" is three stems (radius 1.1 m, 2.8 m centre to centre, so the
0.6 m gaps between them are closed to the 1 m ball) that reach from one
edge of the bed across the middle, leaving one opening on the other side.
Openings alternate right / left / right..., so the ball has to swing
about 7 m sideways between rows: that is the slalom.

| Section | z range | Rows (z) | Row spacing | Edges | What it teaches |
|---|---|---|---|---|---|
| Start pad | +10 .. -6 | - | - | turf walls all round | get rolling |
| 1 "Wide weave" | -6 .. -66 | -16 (R), -36 (L), -56 (R) | 20 m | turf walls both sides (forgiving) | big lazy turns are enough; a leaf on the straight (z -26) shows what "slick" feels like with nothing at stake |
| 2 "Tighter" | -66 .. -120 | -74 (L), -87 (R), -100 (L), -113 (R) | 13 m | wall on the left, water on the right | the right-hand openings are next to the water: a late or too-fast swing goes in. Leaf at (-1.5, -94) sits on the diagonal of a left swing, so the turn has to be set up before it |
| 3 "Slalom proper" | -120 .. -176 | -126 (L), -137 (R*), -148 (L), -159 (R*), -170 (L) | 11 m | water both sides | the small end challenge: five swings at 11 m spacing with leaves at (2, -142), (-1.2, -153) and (3, -165). Rows marked * carry the shortcut gap |
| Finish nook | -176 .. -192 | - | - | walls on three sides | the ant hill (the finish) at (0, 0, -186), pebbles and grass as a safe pocket |

"R" = opening on the right (+x), "L" = opening on the left (-x).
Stem count: 36 slalom stems (12 rows x 3) plus 6 decorative stems on the
far banks; 5 leaf patches; 7 turf walls; 2 water furrows.

### Row layouts (x positions of the stem centres, stem radius 1.1)

| Row type | Stems at x | Ball centre may pass at x |
|---|---|---|
| opening right (R) | -5.4, -2.6, +0.2 | 1.8 .. 6.0 (4.2 m wide) |
| opening left (L) | +5.4, +2.6, -0.2 | -6.0 .. -1.8 |
| shortcut row (R*) | -5.4, -2.8, +1.2 | normal opening 2.8 .. 6.0; shortcut gap -1.2 .. -0.4 |

### The shortcut

Rows 9 (z -137) and 11 (z -159) have a 1.8 m gap between their middle and
inner stems (surfaces at x = -1.7 and x = +0.1, centred on x = -0.8). The
two stems flanking the gap are white; a strip of lighter trodden dirt
(visual only, no collision) runs along the shortcut line from z -131 to
z -170. Taking it means staying on the left: through the gap at x = -0.8,
a 1.5 m wiggle left to clear the inner stem of the next left-opening row
(ball centre at most -1.8), and back. It skips three 7 m swings; the bot
saves about 3.5 s with it, and because the line is almost straight a
precise player can take it at 10+ m/s (the bot passed at 12 m/s). The
normal line needs ~6.5 m/s at those rows.

## Layout measurements and the physics values they depend on

| Measurement | Value | Depends on | Why |
|---|---|---|---|
| Closed gap between stems in a row | 0.6 m (pitch 2.8, radius 1.1) | ball radius 0.5 (1 m ball) | must be clearly smaller than the ball so a row cannot be passed anywhere but its opening; 0.6 leaves no chance of wedging through |
| Stem radius | 1.1 m | ball_bounce 0.47 | thick stems give a flat enough contact that a hit reads as a clean knock-back (about half speed back) rather than a glancing deflection |
| Row opening width | 4.2 m (ball centre has 4.2 m of room) | turn_assist 0.72, max_speed 14.2 | wide enough that a player arriving a bit fast can still make it through; narrow enough that a straight line is impossible |
| Sideways swing between rows | ~7 m (ball centre from about +3.5 to -3.5) | turn_assist 0.72 (sideways push ~12.6 m/s^2) | the swing amplitude A and row spacing L set the needed turn radius r = L^2 / (A pi^2); comfortable speed is sqrt(12.6 r) |
| Row spacing, section 1 | 20 m | same | r ~ 11.6 m -> fine up to ~12 m/s (near max_speed; "easy") |
| Row spacing, section 2 | 13 m | same | r ~ 4.9 m -> ~7.9 m/s; a player must lift off or brake |
| Row spacing, section 3 | 11 m | same | r ~ 3.5 m (lazy line) to 5.3 m (hugging the stems) -> 6.6-8.2 m/s; the "small challenge" |
| Shortcut gap | 1.8 m between stem surfaces (0.8 m of tolerance for the ball centre) | ball diameter 1.0 m; brief asks for 1.6-2.0 m | wider than the ball by a small margin: precise but passable at speed |
| Shortcut wiggle | 1.5 m sideways per 11 m | turn_assist | r ~ 80 m, so the line can be taken at full speed if aimed right |
| Leaf patches | 5 x 3 m, grip 0.2 | leaf grip 0.2, rolling_resistance 0.26 | on a leaf the sideways push drops to ~2.5 m/s^2, so a turn has to be started before the leaf; crossing 5 m at 7 m/s takes 0.7 s |
| Leaf 1 placement (0, -26) on the straight | - | - | first contact with a leaf where no turn is needed |
| Leaf 2 (-1.5, -94) and leaf 5 (3, -165) on the diagonals | - | leaf grip, turn_assist | the swing must be set up before the leaf, or the ball drifts straight into the next row's stems |
| Leaf 4 (-1.2, -153) on the shortcut line | - | leaf grip | the shortcut-taker must be lined up before it |
| Bed width | 13 m (sections 2-3), 15 m with walls (start, section 1, finish) | stem layout | the outer stem of every row touches the edge, so there is no sneaky lane along the water |
| Water surface | y = -1.5 (fall zone top at -1.7) | fall_respawn_y -2.5 | the ball fails on touching the water, before the global respawn height |
| Course length | 190 m | max_speed 14.2, roll_acceleration (~7.3 m/s^2 effective) | 0 -> 14 m/s takes 2 s / 14 m, so the 20 m rows of section 1 let the player get up to speed and learn that they must then shed it |
| Camera | 2.14 m behind, pitch 26 degrees | camera_distance | stems are 9-13 m tall and openings alternate strictly, so the next opening is readable from the previous row; white stems and the dirt trail mark the shortcut from ground level |

## Testing done

- `godot --headless -- --drive=tests/levels/level_2.json` -> PASS, 0:30.18, 0 falls.
- `godot --headless -- --drive=tests/levels/level_2_shortcut.json` -> PASS, 0:26.64, 0 falls (9 m/s through the gaps; also passed at 10 and 12 m/s in scratch runs).
- Scratch drives (not committed): the normal line at 9-11 m/s passed in 26 s, at 5 m/s in 44 s; a drive aimed straight at the inner stem of row 1 at 10 m/s never got past it (no tunnelling, clean knock-back).
- Screenshots at several zooms, plus the F2 collision overlay: stem cylinders, walls and leaf boxes sit where the visuals are; the ball does not clip the ground.
- `./run_tests.sh` -> RESULT: all checks passed.

## Not done / could be better

- The flower heads of three stems in a row overlap into one bouquet when
  seen from high above; from the ball's height (the real view) this is
  invisible, so it was left alone.
- The bed's base is only 11 m wide under a 13-15 m bed, on purpose: the
  overhang means there is no ledge to land on. It is a stylised look.
- All assets are code-built kit pieces; no external assets were added.
