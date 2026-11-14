# Lived-in Kesselford on main's walk-in buildings — QA evidence (2026-11-14)

Follows `docs/qa/lived-in-2026-11-02/` (the first dressing, owner item 32). This pass brings
the dressing up to date with main's walk-in buildings (item 35) and hex grid (H3b), regenerated
with the same seed (1102) and the same 84 approved sprites.

## Captures (1920×1080, camera zoom 1; overview at zoom 0.5)

Rendered under Xvfb by `test/manual/lived_in_capture.gd`, HUD and title screen hidden.

| Spot | File |
|---|---|
| Overview | `kesselford-overview-after.jpg` |
| Wayhouse front (1150, 860) | `kesselford-wayhouse-after.jpg` |
| Chandlery front (1900, 860) | `kesselford-chandlery-after.jpg` |
| South yards (1500, 1400) | `kesselford-south-yards-after.jpg` |

## What changed in the dresser

- **Walk-in floors take no dressing.** Every cell of a walk-in building's footprint is left
  out (`no_dress`); a ground decal whose jitter would carry it onto a floor is dropped.
- **Doorways keep an apron.** Each doorway cell (`D` in the building plan) keeps a
  ±128×64 px clear zone, inside and out, and joins the main-route corridor.
- **Townsfolk posts stay clear.** Posts are read from `data/generated/*_npc_placements.json`
  (anchor node + offset, as `TownNpcSpawner` places them) and keep a ±80×56 px zone; the
  townsfolk themselves only spawn with a party, so the live scene cannot be read for them.
- **Walk-in buildings cast no contact shadows.** They sit under `SolidProps`, so their wall,
  floor and furniture sprites were each getting a shadow (640 inside the buildings);
  `DressingShadows` now skips them.

## Counts

| | 2026-11-02 | 2026-11-14 |
|---|---|---|
| Ground decals | 211 | 209 |
| Standing pieces (solid) | 272 (79) | 363 (103) |
| Blocking cells painted at load | 79 | 103 |
| Contact shadows | 284 | 375 |

Draw calls per frame, dressing off → on (this branch, `LIVED_IN_OFF=1` for "off"): wayhouse
387 → 634, chandlery 303 → 568, south yards 156 → 397, overview 456 → 1008. The walk-in
buildings account for most of the "off" figure. The 84 separate greeble textures are still
unbatched (an atlas would batch them); frame time on real hardware stays with FR-904 (owner
item 14).

## Seen in the captures

- Floors and doorways are clear; NPCs stand with room around them; no prop on a road.
- The walk-in buildings still render with their placeholder kit (grey roofs, plain plank
  walls). Their exterior art is not part of this pass.
