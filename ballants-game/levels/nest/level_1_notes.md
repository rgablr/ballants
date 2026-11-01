# Level 1 -- Tunnel Drop (design notes)

Teaches: **speed control**. One long dirt tunnel winding down through the
nest, 477 m of centerline and a 70 m drop, built from a single `DirtTrack`
(the course) plus a second one for the hidden shortcut tunnel. The scene
is GENERATED: `python3 tools/make_tunnel_drop.py` (run from
`ballants-game/`) rewrites `level_1_tunnel_drop.tscn` and the three bot
drive files from a cursor walk of straights and arcs, so every seam meets
by construction. Change the walk in `build()`, not the scene.

Target time 1:25 (85 s). The bot's clean run is about 1:07, the shortcut
run about 1:06 (the tunnel is slower than it looks: narrow and steep), a
careful first-timer 3-4 minutes. Beating 1:25 needs clean braking into
the switchbacks and the final curve, not the shortcut.

The level floats in the dark; the floor is never below y = 5 (the ball
counts as fallen out below y = -2.5), and a FallZone at y = -1 catches
whatever leaves the track.

## Section by section

| # | Section | What it is | Skill beat |
|---|---|---|---|
| 1 | Gentle slope | 100 m, 10 m wide, walls both sides, 1-3.5 degree slope, three soft bends (radius 28-30 m) | Hold forward; feel the ball build and keep speed; nothing can go wrong |
| 2 | First open edges | 87 m, 7 m wide, 4.6 degree slope. A right bend (radius 9 m) with NO outer wall, a walled straight, a left bend (radius 9 m) with no outer wall. An amber crystal cluster stands off each open edge as a landmark | At top speed you slide off the open outside; ease off to ~8 m/s and it fits |
| 3 | Switchbacks | leg 0 (20 m) then four 180-degree hairpins (centerline radius 5 m, 6.5 m wide, walls both sides) joined by 24 m legs at 12 degrees | Brake before every hairpin: above ~6.5 m/s you hit the outer wall and lose time |
| 4 | The plunge | a 12 m crest, then 5 m at 11 degrees, 5 m at 22, 50 m at 31 degrees, a 30 m flat landing, a right curve (radius 15 m, walled), 10 m straight and the goal on a 16 m wide plateau | Speed builds past the push cap by itself; brake on the landing for the final curve |

The goal is a small ant hill (base radius 5 m) at the end of the plateau.

## Hidden crystals

- **Shortcut (hidden 1).** Turn 1 is a right-hand hairpin; at its apex a
  4.6 m section of the outer (left) wall is a `FalseWall`: no collision,
  the same shape and lean as the real wall but looser dirt, a few loose
  clods and two thin cracks. Behind it a 2.8 m wide, 2.6 m tall tunnel
  (walls, ceiling, blue-white fungus) runs straight out, tips over to a
  14 degree drop, hairpins right with a 10 m radius (the crystal floats
  at the hairpin's far point) and comes back through the outer wall at
  turn 3's apex. It skips legs 1-2 and turns 2-3. You pop out sideways
  into turn 3 and must brake at once. Rolling into the exit from turn 3
  lets you climb the tunnel backwards and find it the slow way.
- **Off-route ledge (hidden 2).** At the crest before the plunge the
  right wall has a 6 m gap into a 5.6 x 5.4 m pocket with dirt walls on
  three sides. A thick root grows out of the pocket's uphill corner and
  arches across the uphill half of the gap, so from the approach you see
  a root in the wall and nothing behind it; the crystal sits in the
  pocket's uphill-back corner. Stop at the crest and look back uphill and
  the opening is plain. A speedrunner carrying speed over the crest never
  sees it.

## Layout <-> physics (the owner's current tuning)

| Measurement | Depends on | Why |
|---|---|---|
| Open-edge bend radius 9 m centerline (outer edge 12.5 m) | `roll_acceleration` 10.085, `turn_assist` 0.1, `max_speed` 9.775 | Sideways push ~ 0.714 x 10.085 x 1.1 = 7.9 m/s^2, so the tightest steady turn at speed v has radius v^2 / 7.9: 12.1 m at top speed, 8.1 m at 8 m/s. Hugging the outside at full speed only just fits; a late turn goes off |
| Hairpin radius 5 m, 6.5 m wide (outer edge 8.25 m) | same | 6.3 m/s on the centerline, 8.1 m/s on the outer edge; arriving at 9.8 m/s means the wall |
| 24 m legs at 12 degrees between hairpins | `gravity` 12.27, `rolling_resistance` 0.3975, `brake_multiplier` 1.2525 | Rolling resistance is 0.3975 x speed, so on any slope under ~26 degrees the ball never beats `max_speed` on its own; a full-speed ball brakes from 9.8 to 6 m/s in about 3 m (brake push 9 m/s^2 + resistance 3.9 m/s^2) |
| Plunge 31 degrees, 50 m | `gravity`, `rolling_resistance` | Downhill pull 0.714 x g x sin 31 = 4.5 m/s^2 against 0.3975 x v: terminal ~11.3 m/s, reached in ~30 m. Above 26 degrees the slope beats the push cap; below it it does not |
| Flat landing 30 m before the final curve | `brake_multiplier`, `rolling_resistance` | From 11 m/s to the final curve's 10 m/s-ish limit takes under 10 m of braking; 30 m leaves room to coast |
| Crest into the plunge: 11 -> 22 -> 31 degrees over 10 m | `ground_stick` 1.0 | A sharper crest popped the bot 1.3 m/s into the air; the staged lip keeps it grounded |
| Tunnel 2.8 m wide, 2.6 m ceiling | ball radius 0.5, `jump_height` 1.59 | Two ball widths of play; no jumping out |
| Tunnel hairpin radius 10 m at 14 degrees | `turn_assist`, hairpin spacing | The legs are 10 m apart, so a 10 m radius comes back level with turn 3; it is comfortable up to 8.9 m/s, and the slope keeps you under that |
| Level apexes at turns 1 and 3 (slope 0 for 30 degrees of arc) | the junction with the tunnel | The tunnel's floor is level across; a sloping apex left a 10 cm lip that popped the ball |
| Every floor above y = 5 | `fall_respawn_y` -2.5 | Falling below -2.5 fails the run even on a floor |
| Fungus every 13 m along the walls | `camera_distance` 2.14 | The camera is close; a light every 13 m keeps the next bend readable |
| Wall height 3 m | `jump_height` 1.59 | The ball cannot hop over a wall |

If any of those tuning values change, re-run `./run_tests.sh`: the three
drive files (`tests/levels/level_1_tunnel_drop*.json`) prove the main
route, the shortcut (expects hidden 1) and the ledge (expects hidden 2).
