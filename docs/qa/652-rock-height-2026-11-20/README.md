# #652 gap 3: Dorthkor Road's rock outcrops are high ground (2026-11-20)

Owner item 48(d), `48: d rocks`. Rendered with `test/manual/rock_height_capture.gd` on WSLg at
1920x1080 (`SOUL_METER_HEADLESS=0`), on branch `claude/652-rock-height`.

| Frame | What it shows |
|---|---|
| `01-standing-on-the-warn-rock.jpg` | Out of a fight, the player stands on top of the Warn Rock (left of the warning post). Before this change, the rock's base stopped the walk. |
| `02-qa-height-cells.jpg` | **QA overlay only; the game does not draw this.** Hexes at height 2 are red and hexes at height 1 are amber, for the Warn Rock (bottom left), the North Rock (top) and the South Rock (bottom middle). |
| `03-strike-from-the-rim.jpg` | The vanguard fight. Vex climbs onto the North Rock's rim (a 25 CT move), beside the Breach Hound on the ground. The breakdown reads **Height +4 pp** to hit and **Height advantage 1.1 ×** to power. |

Harness log: `MOVE Vex the Unbowed to c:-53,98,1 allowed=true ct=25`, then
`FORECAST ... ally_height=1 ... target_height=0 height_advantage_steps=1`.

## What to judge
- **Height shows only in the forecast.** On a painted map the game draws no raise for a unit
  on high ground. A unit on a rock stands on the rock's base, which the art draws as the rock's
  lower faces. Frame 1 reads as "on the rock" because the Warn Rock's base runs under its top
  surface. On the small rocks a unit is at the rock's foot more than on its top.
- **Which rocks.** Only the three sprites named `*Rock` are climbable. Five sprites named
  `*Stone` (`MemorialStone`, `SouthStoneA/B/C`, `EastStone`) show the same mossy-rock art and
  still block. Making one climbable is one `metadata/climb_height` line plus a run of
  `tools/paint_blocking.gd`.
- **The Warn Rock's top** is 50 hexes at height 2. 20 of them are shut to walking, by the walk
  clearance the grid keeps around nearby solids.
- **Melee from the top:** a melee strike needs the attacker's jump to be at least the height
  difference (`GridBattlefieldModel`). With the default jump of 1 in `tactical_tables.json`, a unit
  on height 2 cannot strike in melee down to the ground, and a unit on the rim (height 1) can.
  Ranged attacks are not limited this way.
