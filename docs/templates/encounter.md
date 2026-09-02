# Template — field encounter

An encounter is **Pandora data first** (FR-108). The runtime reads
`data/generated/encounters.json`, which is generated; never hand-edit it.

## File set a worker must produce

| File | Purpose |
|---|---|
| `tools/seed_pandora.gd` `_encounter_rows()` (+ a row in `_seed_combatants()` for a new enemy) | The authored row — Pandora is canonical |
| `data.pandora` + `data/generated/encounters.json` + `data/generated/encounter_ids.gd` | Regenerated: run the seed script, then `tools/generate_gloot.gd` (`Project → Tools → Regenerate GLoot prototypes`, or headless with `SOUL_METER_DRIFT_CHECK=1` to verify) |
| `globals/encounter_catalog.gd` | `_FIELD_GRID_DATA[<id>]` (grid board), optional `_WEATHER_DEFAULTS[<id>]`, optional `_SPOILS[&<id>]` |
| a scene placement | An `actors/enemy` instance with `encounter_id`, optional `required_flag` / `locked_message` |
| `test/integration/test_<slug>_encounter.gd` | Starts the battle headless, both win and loss consequences write the ledger (pattern: `test/integration/test_combat_controller.gd`, `test_gate_t1_clearability.gd`) |

## Pandora row (`_seed_encounters` properties, in `_encounter_rows()` order)

```
[ Display Name, Encounter Id, Combatant Ids, Defeated Flag,
  Win Faction, Win Delta, Win Cause,
  Loss Faction, Loss Delta, Loss Cause ]
```

- `Encounter Id`: kebab, becomes `EncounterIds.<CONST>` after regeneration.
- `Combatant Ids`: comma-separated combatant ids seeded in `_seed_combatants()` (`Combatant Id`, `Display Name`, `Max HP`, `Attack`, `Defense`, `Edge`, `Balance Affinity`, `Balance Pressure`, `Element Id`).
- `Defeated Flag`: obeys the flag grammar with domain `encounter` (e.g. `encounter_bog_wight_defeated`).
  Existing `defeated_bog_wight` is grandfathered in `LEGACY_FLAGS`; new ones are not.
- Win/Loss `Faction`: vault faction kebab id. `Delta` signed float. `Cause`: the sentence
  written to `Reputation` via `Battle._apply_victory()` / `_apply_loss_consequence()`.

Generated shape (what the catalog serves, `EncounterCatalog.definition(id)`):

```
{
 "display_name": "Bog Wight", "defeated_flag": "defeated_bog_wight",
 "win_faction": "ssae-seeders", "win_delta": 6.0, "win_cause": "...",
 "loss_faction": "ssae-seeders", "loss_delta": -3.0, "loss_cause": "...",
 "default_outcome": "slain", "context_actions": [], "speech_hooks": [],
 "outcomes": {"slain": {"faction": ..., "delta": ..., "cause": ..., "message": ...}},
 "enemies": [{"id": "bog-wight", "max_hp": 20, "attack": 4, "defense": 1,
              "balance_affinity": 1, "balance_pressure": 18, "element_id": "molm", "edge": 2}]
}
```

## Catalog rows (`globals/encounter_catalog.gd`) — worked example, Bog Wight

```
const _FIELD_GRID_DATA := {
	"bog-wight": {
		"dimensions": Vector2i(7, 5),
		# Contestable tussocks around low hummocks in the bog's center.
		"cover": [Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 3)],
		"elevation": {Vector2i(3, 1): 1, Vector2i(4, 2): 2},
	},
}
const _WEATHER_DEFAULTS: Dictionary = {"bog-wight": "molm"}   # element id or absent = CALM
const _SPOILS: Dictionary = {
	&"bog-wight": [ItemIds.MATERIALS_GRAVE_SALT, ItemIds.CONSUMABLES_BITTERLEAF_POULTICE],
}
```

Rules: deployment columns (x = 0 and x = width − 1) stay clear of cover/elevation; every
`Vector2i` inside `dimensions`; weather element must be on the Wheel (`ElementsData`).
All three tables are marked PROVISIONAL in the file — say so in the handoff too.

## Scene placement (`world/wound_lip.tscn` shows one)

```
[node name="JawbraceGuard" parent="." instance=<enemy>]
encounter_id = &"jawbrace-empty-post"
required_flag = ""                       # gate on a quest flag if the fight is sequenced
locked_message = "Resolve the threat before this one."
```

The enemy node asks `EncounterCatalog.definition(encounter_id)` and hides itself when
`defeated_flag` is set — no per-scene logic.

## Speech-in-battle (FR-106)

If the encounter can be talked down it needs a `speech_hooks` entry (dialogue path + start
title) so `Battle.ACTION_SPEECH` is available. The generator already reads a `Speech Hooks`
JSON-array property (`tools/generate_gloot.gd`), but `_seed_encounters()` does not create
that property yet — adding it is an additive seed change; list it in the handoff. Shape:
`globals/combat/combat_speech_option.gd`. Harem Stet-aligned encounters MUST have one.

## Pre-handoff checklist

- [ ] Row added to `_encounter_rows()` (and a row in `_seed_combatants()` if a new enemy), seed run,
      generator run, `SOUL_METER_DRIFT_CHECK=1` passes, `encounter_ids.gd` has the new const
- [ ] No hand edits under `data/generated/`
- [ ] `_FIELD_GRID_DATA` row present; board rules above hold
- [ ] Defeated flag obeys the grammar (domain `encounter`)
- [ ] Integration test: win writes `win_faction` delta; loss writes `loss_faction` delta
- [ ] Placement in a scene that is itself branch-held until #93
