# Wave E issue evidence — screens to spec + NG+ reactivity

Full suite on this branch: `Overall Summary: 734 test cases | 1 errors | 4 failures`
Failures confined to the known baseline suites (test_actor_presentation, test_y_sort,
test_click_to_move / test_click_to_move_input). Import clean.

Post-worker corrections (applied during synthesis review, all in this branch):
- Two `:=` Variant-inference parse errors in `test/integration/test_inventory_screen.gd`
  (warnings-as-errors aborted the whole suite run, exit 105) — typed explicitly.
- `transfer_to_equipment` always failed for multi-cell items: the equipment slot's
  GridConstraint was fixed at 1×1, so GLoot's fit check rejected e.g. the 2×3 Taubstummer
  Axe. The slot grid now resizes to the incoming item's footprint (and back to 1×1 when
  emptied); single-item semantics stay enforced by ItemCountConstraint.
- Gate T-10 (`test_wavec_tactical_gates`) flagged the new `ap_cost` display reference in
  `ui/screens/inventory.gd` as an undocumented AP path — annotated as display-only metadata.
- `test_field_room.test_open_inventory_screen` still asserted the old hand-rolled
  GridContainer/Button slots — rewritten against the GLoot `BagGrid` bound to
  `GameState.inventory` (same 6 seeded items + stack sizes asserted).

## #126 — Inventory screen to spec (3-column layout on GLoot)
- `ui/screens/inventory.gd`/`.tscn`: 3-column layout (equipment rail / bag `CtrlInventoryGrid`
  on `GameState.inventory` / detail panel with stats + flavour), weight readout via GLoot
  WeightConstraint, equipment slots as single-item GLoot inventories with slot-name gating
  (`transfer_to_equipment` / `transfer_from_equipment`, static + unit-testable).
- Tests: `test/integration/test_inventory_screen.gd` (layout + transfer accept/reject),
  `test/integration/test_field_room.gd::test_open_inventory_screen` (in-world open/close,
  seeded items visible).

## #128 — World Map screen (gazetteer rail + etched map field)
- `ui/screens/region_map.gd` + new `ui/screens/region_map_canvas.gd`: gazetteer rail
  (discovered hubs, costs, lock states from `FastTravelRegistry`) beside an etched map
  canvas; purchase/route still exclusively through `GameFlow.fast_travel()`.
- Tests: `test/integration/test_region_map.gd` (existing suite, green on this branch).

## #114 — Missing DS components
- `ui/components/badge.{gd,tscn}`, `item_slot.{gd,tscn}`, `meter_bar.{gd,tscn}` — theme
  type variations only (rg confirms no per-node style overrides); `item_slot` is the
  `custom_item_control_scene` for both bag and equipment grids; `theme_builder.gd` gained
  the matching variations.

## #105 — FR-801/803: NG+ carry-over + NG+-only reactivity lines
- FR-801 (Mirror Shop carry-over) was already satisfied (`ui/screens/shop.*` + `ng_plus.gd`);
  the NOT-SATISFIED remainder was FR-803's NG+-only lines. Wave E added one NG+-gated echo
  line each to `dialogue/hadrik_vale.dialogue`, `iris_illepah.dialogue`,
  `marshal_coiljaw.dialogue`, gated on the new read-only `NGPlus.is_active()` predicate
  (checks completion metadata; no new write paths). All three lines are marked
  `PROVISIONAL — CANON REVIEW REQUIRED (NG+ echo line only)`; conditions use the
  self-closing `[if expr /]` form (rg-verified, no plain `[if]`).
- Tests: `test/integration/test_ng_plus_dialogue.gd`.

## #112 — NOT closed
No local copy of the mockup specs exists to vendor; source lives in the synced design-system
project (off-machine). Screens above were built from the spec text quoted in the issues.
Commented on the issue as needs-user.
