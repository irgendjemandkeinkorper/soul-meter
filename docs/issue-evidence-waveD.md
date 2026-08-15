# Wave D issue evidence — six-region battle interface

Full suite on this branch: `Overall Summary: 731 test cases | 1 errors | 4 failures`
— failures confined to the known baseline suites (test_actor_presentation, test_y_sort,
test_click_to_move_input). **Zero new failures.** Import clean.

## #144 — six-region parent
- `ui/hud/battle_interface.tscn` + `battle_interface.gd`: six-region container with a
  documented signal/data contract; consumes `Battle.combat_event` with replay
  (`battle.gd` wires `consume_event` + `replay_combat_events`). Battle remains an overlay
  (instanced into `battle.gd`'s stage space, no scene swap).
- Assembly proven by `test/integration/test_battle_interface.gd` (scripted state, each
  region asserts rendered values).

## #145 — Region B stage
- `ui/hud/regions/stage/`: iso grid fed by grid_battlefield_model + tile_state — per-tile
  charge, residue, height. Theme via ds.gd tokens/type variations; rg confirms zero
  per-node style overrides. Tests: `test_battle_stage_region.gd`.

## #146 — Regions A+E
- `ui/hud/regions/unit_plate/` + `ui/hud/regions/ct_timeline/`: active unit plate
  (portrait, HP, element, CT) and scheduler-forecast timeline incl. wait-cap visibility,
  updating on scheduler events. Tests: `test_unit_plate_region.gd`,
  `test_ct_timeline_region.gd`.

## #147 — Regions C+D
- `ui/hud/regions/weather_chip/` + `ui/hud/regions/forecast_panel/`: weather chip
  (element + measure tick), act wheel, affinity strip; forecast panel returns
  `Resolution.resolve(_context)` directly — the same pure path, no second math path.
  Tests: `test_weather_forecast_regions.gd`.

## #148 — deployment flow
- `ui/screens/deployment/` + GameFlow chart: `Deployment` state with paired
  Slate/Attune/Loadout/Place sub-states (events, not destinations; no
  change_scene_to_file anywhere — rg-verified); placement writes spawn positions into
  grid_battlefield_model. Tests: `test_deployment_flow.gd`.
