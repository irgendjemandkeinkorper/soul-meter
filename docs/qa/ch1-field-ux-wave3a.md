# Chapter One field-UX — Wave 3a evidence (#309 interior Kenney retool)

Date: 2026-09-13. Branch `feat/ch1-facade-occlusion`. Luna generated the batch-2 art
(`assets/generated/sprites/interior/_contact_sheet.md` holds every prompt + source);
Fable reviewed the rendered result and re-tuned scale/placement.

## What changed
- 11 painted assets (table, bench, stool, bar counter, hanging sign, chest ×2, switch ×2,
  stone floor + dark brick tileables) replace every `fantasy-town-kit`/`nature-kit`/
  `castle-kit` reference under `world/interiors`, `actors/chest`, `actors/switch`,
  `actors/travel_exit`. Grep for those kits in that scope: zero hits.
- Reviewer fixes on top of Luna's swap: props were scaled to the old Kenney footprints and
  read as miniatures — now uniform 0.6/0.5/0.4 (table/bench/stool); bar counters are
  UV-mapped across their polygon (`BuildingInterior.configure_counter`) and anchored at
  their base so actors y-sort against them; the 10 inner doors show door art instead of
  the brown `DoorPanel` blockout; chest/switch blockout `Marker` squares hidden; accent
  rugs now take the floor texture with a darkened accent tint instead of flat orange.

## Rendered verification (Xvfb, `test/manual/ch1_field_ux_wave2_probe.gd`)
- `docs/qa/wave3a/tavern_interior.png` — painted bar, tables/stools/benches at actor scale.
- `docs/qa/wave3a/item_shop_interior.png` — back-wall warehouse door art, no blockout
  rectangles, chest without yellow marker.
- Suites: `test_building_interiors.gd` 21/21, `test_starting_town.gd` 19/19,
  `test_facade_occluder.gd` 10/10, `test_interior_population.gd` 2/2 — all rendered.

## Open for owner
- Taverner now stands east of the bar (moved so the title and counter are readable);
  if you want them *behind* the bar, say so and the sprite moves back to (480, 50).
- Inner-door art sits on the back wall at 0.55 scale; looks like a doorway, tune if it reads
  as floating.
