# Hex grid plan (2026-11-03)

**Status (2026-11-03): built.** H0–H3b are draft PRs #571–#575 (stacked); H4 is this PR's docs
and the FR-105a amendment, ratified 2026-11-03. The game walks and fights on hexes
(`soul_meter/grid/hex = true`). What is still PROVISIONAL is on the owner list, item 34.

**Owner request, 2026-11-02:** "wire the map up to a grid system like Fallout, probably
hexagonal like they have, to calculate ranges better and have a more seamless transition
between combat and the exploration/normal map."

**Ruling (item 33):** `plan first`. Building starts only on the owner's go-ahead, as its own
wave after the demo work (#568 and #569).

**Rulings taken 2026-11-03** (item 34, §5 of `docs/owner-decisions.md`):

| # | Question | Owner's answer |
|---|---|---|
| H-a | Hex size | **Fallout scale.** A hex is half a cell along each ground axis, about four hexes per current cell. |
| H-a2 | Movement cost | **1 AP walks 2 hexes.** A turn covers the same ground as today. Ranged reaches double in hexes. Melee is "touching hexes". |
| H-a3 | Bodies | **One hex each.** Two units on touching hexes overlap a little on screen. Draw order keeps the nearer one in front. No art changes. |
| H-b | Row direction | **Rows run left to right.** Pointy-top hexes, squashed 2:1 to sit on the iso view. |
| H-c | Visibility | **Shown in fights by default.** A setting keeps a faint grid on while exploring. It is off by default. |
| H-d | Roll-out | **Every map at once.** The hex grid is derived at load from each map's square layers. |

## Where we are today (checked in code, 2026-11-03)

1. **One grid already.** Walking and fighting share the field's `IsoGrid` (same-map
   architecture D1). `IsoGrid` hides its `AStarGrid2D` from both consumers (D4), so the grid
   can change behind the same calls. A fight already opens on the map you are walking on. Since
   item 33, on-map fights skip the deployment screens.
2. **The grid is square.** Cells are 64×32 iso diamonds with eight neighbours. Combat distance is
   Chebyshev (`max(|dx|, |dy|)`) in 22 places across four files, so "within 4" is a square, and
   a diagonal reaches about 1.4 times as far as a straight line.
3. **The swap was always planned.** The 2026-08-29 ruling (`docs/fallout2-adoption-spec.md`,
   Wave P) put tactics "on the CURRENT square grid now — a hex conversion is a separate later
   wave through the FR-105 battlefield-model seam". This is that wave.
4. **Movement costs 1 AP per cell.** Turns have 4–5 AP. The move budget is
   `action_points / MOVE.ap_cost` (`CombatController._move_budget`).
5. **The seam has a visible snap.** At a fight's start, `FieldMap.seat_party()` centres the
   lead on its cell and teleports each follower onto its seat.
6. **Saves hold world positions, not cells.** `globals/save_game.gd` has no cell fields, so the
   new grid needs no save migration. A loaded position snaps to the nearest free hex.

## The geometry

- **Art stays as it is.** Kesselford's painted ground, the 64×32 tile layers and the lived-in
  dressing are untouched. The square `Blocking` and `Terrain` layers stay the authoring source.
  No map file changes, and no generated hex data is hand-edited.
- **Hex size.** A hex step is half a cell side in ground space. On screen at zoom 1 a hex is
  about 23 px wide, and the rows step down about 10 px. That is about 4.5 hexes per cell by
  area: Fallout's ratio of four hexes per floor tile.
- **Derived solids.** A hex is solid if its centre, or any of its six corners pulled halfway in,
  lands on a solid cell. Walls get slightly thicker, but no path can leak through a wall one
  cell thick. Height and terrain cost come from the cell under the hex's centre.
- **Ranges become rings.** Hex distance counts equal steps in all six directions, so "within
  8" is a near-circle. Diagonals no longer reach farther.

## How the rules carry over

| Rule | Today (cells) | On hexes | Data change |
|---|---|---|---|
| Move | 1 AP per cell | 1 AP per 2 hexes. A move order of an odd number of hexes rounds up (3 hexes = 2 AP). **PROVISIONAL** | None. The budget doubles at the seam. |
| Ranged and spell reach | N cells | 2N hexes (reach 4 → 8) | None. The authored N stays; the model doubles it. |
| Melee | adjacent cell | touching hex | None. |
| Radius effects, light fields | within N cells | within 2N hexes | None. |
| Facing (FR-105a) | 8 neighbours: FRONT 1, SIDE 6, BACK 1 | 6 neighbours: FRONT 1, SIDE 4, BACK 1 | None. The ratified bonuses are unchanged. |
| Bodies | one per cell | one per hex | None. |

Every authored number keeps its value. The model converts at one place, and
`GridBattlefieldModel.distance()` replaces the 22 Chebyshev sites. Any number that moves
after the balance runs stays PROVISIONAL and goes on the owner list.

## Slices (each its own PR, stacked, suite green at every step)

The hex grid sits behind a project setting (`soul_meter/grid/hex`, off) until H3 turns it on.
Each slice keeps the suite green with the setting off and runs its own tests with it on.

| # | Slice | What it does | Proof |
|---|---|---|---|
| H0 | **Hex maths** | A pure `HexMath` (axial and offset coordinates, distance, the six neighbours, line, ring, range) and `HexLayout` (hex ↔ world for the 64×32 iso view, hex ↔ the cell under it). No behaviour change. | Unit tests: distance symmetry, ring sizes 6n, lines match the reference algorithm, every hex centre maps back to its hex. |
| H1 | **Walking on hexes** | `IsoGrid` gets a hex mode on `AStar2D` (`AStarGrid2D` is square-only), with the same public calls. It covers derived solids, six-way keyboard stepping (`screen_direction_to_neighbor` already picks by screen direction), click-to-move, followers, hostile patrols, and occupancy. Doors, exits, spawns and interactables resolve to their hexes. | For every map, each spawn, door and exit can reach the same places it can on the square grid. An existing save loads at the same spot. Profile: Kesselford's roughly 50,000 hexes build at load and path inside the #282 budget (100 hostiles). |
| H2 | **Fighting on hexes** | `GridBattlefieldModel` takes one `distance()` and the conversions in the table above. Covers controller, KitAI, light fields, line of sight on hex lines, six facings, radius rings, seating, and set pieces (each authored seat goes to its nearest free hex). | The combat suites. Gate T-1 (≥80% wins over 40 seeds per encounter), the Gate T-2 evidence rerun, and the 5v5 demo over ten seeds. |
| H3 | **The seam, the overlay and the setting** | At fight start everyone walks the last step to their seat instead of snapping. The grid fades in under the fighters, and fades out when the fight ends. The overlay draws the hex cursor, path, move range and reach rings. Settings gets "Show hex grid while exploring" (faint, off by default). The hex setting turns on. | Rendered captures before and after a fight starts on Kesselford and in the Trial Hall, a frame-count check that nobody teleports, the setting on and off, and two units on touching hexes (the overlap). |
| H4 | **Docs and ratification** | The PRD amendment changes FR-105a's "square grid positioning" to hexes (owner ratifies). Also an architecture D1/D4 note and `docs/testing.md`. | Owner sign-off. |

## Risks

- **Body overlap.** A character is about 40 px wide on screen and touching hexes are about 23 px
  apart. Two units side by side therefore overlap by about 40% of a body. The owner ruled for
  overlap. H3's frames show it at full size so the owner can judge it in play.
- **Thin walls.** A one-cell wall on an iso diagonal is the leak case. The corner-sampling rule
  covers it, and H1's reachability test fails if any map gains a path the square grid did not
  have.
- **Performance.** About 4.5 times the points (about 50,000 on Kesselford). `AStar2D` with
  explicit edges replaces the square grid's built-in pathing. H1 profiles both the build at
  load and per-path cost, and has to stay inside the #282 budget.
- **Balance at finer steps.** Same ground per AP keeps the pacing. Finer positioning still
  changes flanking and line of sight. Gate T-1 and the 5v5 seeds will show any drift.

## Acceptance

- Walking and fighting use the same hexes. A fight starts without anyone teleporting and
  without a screen change.
- Every move, reach and radius counts hex steps under the table above, and the overlay shows
  them as hexes.
- The grid shows in fights by default, and the setting keeps a faint grid while exploring.
- Every map reaches what it reached before (test), saves load where they were, and Gate T-1
  and the 5v5 demo pass.
