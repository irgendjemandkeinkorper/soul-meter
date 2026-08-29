# Wave 5 acceptance evidence — lootable world

**Date:** 2026-08-29 · **Contract:** `docs/fallout2-adoption-spec.md` Wave 5.
Commits under evidence: `594a08c`/`b81f173` (subtask 1 — inspectable loot panel,
persistent containers, spoils everywhere), `ae1a37a` merge lineage (subtask 2 —
ownership + theft consequence), plus this change (subtask 3 — scavenging pass).

## What shipped (system recap)

- **Inspectable loot flow**: `ui/screens/loot_panel` (take / take-all, capacity
  refusal leaves the row in the source); `Chest` persists remaining contents via
  the additive `GameState.loot_containers` key (`{items, theft_recorded}`, no
  save-schema bump) keyed by an exported `container_id`; `Pickup` is an
  E-to-take interaction (walk-over auto-grant removed).
- **Spoils everywhere**: `BattleResult.spoils` + `EncounterCatalog.roll_spoils`;
  every victory presents spoils through the same panel. Travel keeps its
  per-slot deterministic roll and exactly-once `spoils_granted`.
- **Ownership**: `owned_by_faction` on containers/pickups; the first successful
  take per opened-panel session writes exactly one `Reputation.record`
  (delta −5.0, PROVISIONAL), surfaced by the existing ConsequenceNotices HUD.

## 26-scene scavenging review

Placement target was sparse-and-deliberate (8–15); result: **11 placements in
10 scenes**, 15 scenes reviewed no-place, 1 scene (test_room) already carried
its quest pickup.

| Scene | Placed | Container id | Owned by | Contents (qty × item) | Base GP | Rationale |
|---|---|---|---|---|---|---|
| world/dorthkor_road.tscn | ✔ | dorthkor-road-camp-cache | — | 1× hearthloaf, 1× lamp_oil | 12 | Abandoned road camp; unowned scavenge |
| world/wound_lip.tscn | ✔ | wound-lip-ledge-cache | — | 1× bitterleaf_poultice, 1× grave_salt | 32 | Wilds ledge stash; unowned |
| world/wound_lip.tscn | ✔ | wound-lip-guard-kit | — | 1× binding_thread, 1× field_needle | 19 | Dropped field kit near the lip; unowned |
| world/starting_town.tscn | — | | | | | Open town square — goods there belong to stalls/vendors; no free-loot chest |
| world/test_room.tscn | — | | | | | Already has the FieldDebtProof quest Pickup (now interaction-based) |
| interiors/cask_warehouse.tscn | ✔ | cask-warehouse-supply-crate | iron-companies | 2× lamp_oil, 1× binding_thread | 20 | Working warehouse stock — owned |
| interiors/chefs_pantry.tscn | ✔ | chefs-pantry-supply-crate | iron-companies | 2× loam_bread, 1× loam_smoked_eel | 26 | The chef's larder — owned |
| interiors/equipment_forge.tscn | ✔ | equipment-forge-rivet-crate | iron-companies | 2× iron_rivets | 22 | Forge consumables — owned |
| interiors/iron_companies.tscn | ✔ | iron-companies-supply-crate | iron-companies | 1× iron_rivets, 1× binding_thread | 17 | Company hall stores — owned |
| interiors/item_shop.tscn | ✔ | item-shop-backroom-crate | iron-companies | 1× surveyors_chalk, 2× lamp_oil | 23 | Shop backroom overstock — owned (shelves stay vendor stock) |
| interiors/players_house.tscn | ✔ | players-house-provisions | — | 2× hearthloaf, 1× loam_bread | 18 | The player's own provisions — unowned by definition |
| interiors/river_shrine.tscn | ✔ | river-shrine-offering-box | ironbrand-sentinels | 1× votive_cinder | 12 | Offerings under Sentinel watch — owned |
| interiors/shrine_undercroft.tscn | ✔ | shrine-undercroft-offering-box | — | 2× votive_cinder | 24 | Forgotten undercroft offerings — unowned scavenge |
| interiors/bell_house.tscn | — | | | | | Inhabited home, no fiction hook yet; revisit with content wave |
| interiors/bell_loft.tscn | — | | | | | As above |
| interiors/building_interior.tscn | — | | | | | Template scene — placements go in the scenes that instance it |
| interiors/chefs_house.tscn | — | | | | | The pantry next door carries the loot beat |
| interiors/council_chamber.tscn | — | | | | | Civic chamber; free-loot would read as tone-breaking |
| interiors/dom_tavern.tscn | — | | | | | Party-picker hub; tavern goods are the keeper's trade |
| interiors/equipment_shop.tscn | — | | | | | Vendor floor — stock IS the shop; forge next door has the owned crate |
| interiors/garrison_yard.tscn | — | | | | | Armed garrison; theft-with-no-witness mechanics would strain plausibility |
| interiors/lower_trial_hall.tscn | — | | | | | Trial spaces kept clean of loot |
| interiors/players_loft.tscn | — | | | | | House already has the provisions crate |
| interiors/registry_archive.tscn | — | | | | | Registry paper has quest value, not GP value |
| interiors/registry_stacks.tscn | — | | | | | As above |
| interiors/town_hall.tscn | — | | | | | Civic; the scribe stall there is a vendor |
| interiors/trial_hall.tscn | — | | | | | Trial spaces kept clean of loot |

All placements use existing `ItemIds` prototypes and generic display names
("SUPPLY CRATE", "OFFERING BOX") — no new items, factions, or lore facts.

## Zero grant-all containers (repo scan)

`Chest._apply_interaction()` no longer contains a grant loop (it opens the
panel with the persisted contents). Scan for unconditional multi-item grant
paths outside quest/debug/seed code:

```
rg -n "create_and_add_item" actors/ ui/ globals/ | rg -v test
→ globals/quest_registry.gd   (quest rewards — deliberate direct grants)
→ ui/screens/debug_menu.gd    (debug tooling)
→ globals/game_state.gd       (_seed_demo_data / starting kit)
```

No world container grants items without the inspectable panel. **0 grant-all
chests remain.**

## Economy sanity note (PROVISIONAL)

Total placed base value: **225 GP** across 11 containers (per-container 12–32
GP, priced from `gloot_prototree.json` `base_price`). Context: starting GP is
250 (`GameState.DEFAULT_GP`); shop buy prices run base × vendor buy_modifier ×
band modifier (≈ base at neutral), so the entire world's placed loot ≈ one
mid-tier shopping trip and roughly 5× a single travel-encounter spoils roll
(1–2 rows of the same materials). Owned containers hold 120 of the 225 GP, so
nearly half the placed value carries a −5 reputation cost to take. This neither
floods the early economy nor starves scavenging; values are a balance surface
for the owner pass.

## Acceptance items

| Criterion | Evidence |
|---|---|
| Adapter generalized (containers + corpses/spoils) | Subtask 1: shared `LootPanel` serves persistent chests AND transient battle spoils |
| Authored drop tables on encounter data | `EncounterCatalog.roll_spoils` + `_SPOILS` tables; travel `SpoilsTable` unchanged |
| Interaction pickups replace walk-over | `Pickup extends SMInteractable`; e2e field-debt journey updated |
| Scavenging pass, all 26 scenes reviewed | Table above; placements in 10 scenes |
| Ownership → Reputation event | Subtask 2: once-per-panel-session `Reputation.record`, `test_owned_loot.gd` (7 cases) |
| Zero grant-all chests (repo scan) | Scan above |
| Exactly-once + persistence regression tests | `test_loot_container.gd`, `test_owned_loot.gd` save/load cases, travel `spoils_granted` tests |
| Economy sanity note | Above (PROVISIONAL) |
| Suite green | Recorded at commit time (see delivery log) |

## Residuals

- Container contents/values, theft delta, and `roll_spoils` tables are
  PROVISIONAL balance surfaces. `roll_spoils` seeds from the encounter id
  alone, so a given encounter's drop is fixed — variety needs an owner call on
  where per-battle entropy may come from.
- Corpse presentation: defeated enemies present spoils through the panel at
  victory; there is no lingering field-corpse container (deliberate — battle
  is an overlay, the field scene never sees the fallen).
