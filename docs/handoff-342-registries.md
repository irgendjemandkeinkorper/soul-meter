# Handoff — #342: WorldMapRegistry, FastTravelRegistry and BuildingTransitionRegistry read canon

**Worker:** Codex (`delegated-to-codex`). **Reviewer:** Claude. **Issue:** #342. **Ruling:** owner
2026-10-22, options A1 + B1 of `docs/registries-data-driven-packet.md` (facts and the reasons are
there; this file is the build order). **Branch:** `feat/weftlumin-data-driven-registries` off
`main`, one PR per registry, each PR green on its own.

The data does not change. Every node, route, hub cost and transition that exists today moves into
canon byte-for-byte and comes back out of the generated index. A reviewer must be able to diff the
old hardcoded tables against the index-driven ones and see no difference in values.

## 0. Rules that apply to every PR

- Follow `AGENTS.md`. No `addons/` edits except `addons/weftlumin`. No hand edits under
  `data/generated/` or `world/locations/`: change the canon documents and the bake, then regenerate
  with `tools/generate_locations.gd` (see `docs/weftlumin.md` for the command).
- Typed GDScript, snake_case files, explicit types on Variant-inferred vars. Re-import after adding
  a `class_name` (`godot --headless --path . --import`). Judge gdUnit4 by its output, not the exit
  code (headless teardown aborts with 134 some of the time).
- Tests run through `scripts/test.sh` with `GODOT_BIN`, `LP_NUM_THREADS=1` and a private
  `SOUL_METER_TEST_DATA_DIR` (`docs/agent-verification.md`).
- Named consts that code references stay (`LocationRegistry.DOM`, `WorldMapRegistry.DOM_ID`,
  `BuildingTransitionRegistry.GARRISON_YARD_ENTER`). Registries keep their public method names
  and signatures; callers in `ui/`, `globals/`, `actors/`, `world/` are not rewritten beyond what
  §1–§3 name.
- Do not decide: field names beyond this file, any number, any display name, any new travel rule,
  anything in `docs/game-identity.md` "Open questions". Anything not listed: ask in the issue.
- Handoff in the PR description: changed files, test evidence (suite counts), the value-identity
  check (§1.6, §2.3, §3.4), risks, open questions.

## 1. PR 1 — format, bake, index v2, WorldMapRegistry, the id migration

### 1.1 Location document facets (`weftlumin/kinds/locations.gd`)

Add two **optional** keys to the accepted set (a document without them stays valid; none of the
gazetteer-only cities gets one):

```json
"world_map": { "map_coordinate": [0.2, 0.4] },
"fast_travel": { "base_cost_gp": 40 }
```

Validation: `map_coordinate` is two numbers in 0–1; `base_cost_gp` is an integer ≥ 0;
`fast_travel` is refused when `allowed_gameplay` is false or the document has no scene fields.
Both facets are refused on a document that has no `scene_path`.

Write them into the eight scene-backed macro-location documents from today's tables
(`globals/travel/world_map_registry.gd` `_location_rows()`, `globals/fast_travel_registry.gd`
`_HUBS`): `world_map` on all eight; `fast_travel` on `dom` (25), `kesselford` (40), `ashlaren`
(60) only. Long Verge, Hollowmere, Wilds, Dorthkor Road and Wound Lip get no `fast_travel` key.

### 1.2 Route documents (`weftlumin.route.v1`, new kind)

One file per route, `canon/<hub>/routes/<origin_id>-<destination_id>.json`, in the package whose
`locations/` holds the origin. Fields are exactly today's `_route_rows()` keys, ids spelled as
location ids (§1.4):

```json
{ "schema": "weftlumin.route.v1", "id": "dom-kesselford",
  "origin_id": "dom", "destination_id": "kesselford",
  "steps": 10, "phases_cost": 2, "risk_tier": "low", "risk_modifier": 5.0,
  "encounter_table": [ { "encounter_id": "loam-boar", "weight": 2 },
                       { "encounter_id": "bog-wight", "weight": 1 } ],
  "min_encounters": 0, "max_encounters": 1 }
```

`band_encounter_weights` is an optional object with today's shape (`faction_id`, `bands` →
band → encounter id → weight); only `dom-dorthkor_road` carries it. Validation: both endpoint ids
resolve to scene-backed location documents; `encounter_id`s exist in `EncounterCatalog`; weights
> 0; `min_encounters ≤ max_encounters`; `risk_tier` is one of the values the code accepts today;
`id` equals `<origin_id>-<destination_id>`. Add the kind to the same validate/bake path the
locations kind uses, and to `addons/weftlumin` package manifests where kinds are enumerated.

### 1.3 Index v2 (`data/generated/location_index.json`)

Schema string becomes `weftlumin.location_index.v2`; `LocationRegistry.INDEX_SCHEMA` follows.
Location rows keep every v1 key and gain `world_map`, `fast_travel` and (PR 3) `transition`, each
either the facet object or `null`. A top-level `routes` array holds every route document's fields
(minus `schema`), sorted by `id`. `LocationRegistry._load_index()` must ignore the keys it does
not read, as it does now.

### 1.4 One id per location (ruling B1)

`WorldMapRegistry.DORTHKOR_ROAD_ID`, `WOUND_LIP_ID`, `LONG_VERGE_ID` become `&"dorthkor_road"`,
`&"wound_lip"`, `&"long_verge"`. Route ids follow (`dom-dorthkor_road`, `dom-wound_lip`,
`dom-long_verge`, `long_verge-kesselford`, `dorthkor_road-hollowmere`). The `scene_path` bridge
goes: `GameFlow` (`ui/flow/game_flow.gd` ~731), `RegionMap` (`ui/screens/region_map.gd` ~280) and
`EncounterDirector` (`globals/travel/encounter_director.gd` ~125) look a node up by location id.
`RegionMap._display_name()` reads the index row's `display_name` instead of prettifying the id.

Leave alone: `ui/hud/regions/stage/battle_stage_region.gd` (its `"dorthkor-road"` is a backdrop
theme name), canon character and spawn-table ids that merely contain `long-verge`.

### 1.5 Save migration v9 → v10 (`globals/save_migrations.gd`)

`CURRENT_SCHEMA_VERSION` 10. `_migrate_v9_to_v10` rewrites, when present:
`game_state.travel_plan.origin_id` and `.destination_id` through
`{"dorthkor-road": "dorthkor_road", "wound-lip": "wound_lip", "long-verge": "long_verge"}`, and
every flag key `world_location_discovered:<old>` to `world_location_discovered:<new>` (the
`fast_travel_hub_discovered:` keys already use location ids). Follow the shape and tests of
`_migrate_v8_to_v9`. `TravelPlan.reconcile()` keeps handling a plan whose route changed.

### 1.6 WorldMapRegistry reads the index

`_location_rows()` and `_route_rows()` are replaced by reads of the index (nodes: rows with a
`world_map` facet; routes: the `routes` array), built once and cached like `LocationRegistry`.
Public API unchanged. **Value identity:** before deleting the hardcoded tables, copy them verbatim
into `test/unit/test_world_map_registry.gd` as the expected fixture and assert the index-driven
`all_locations()` and `all_routes()` equal them field by field (ids spelled per §1.4).

Acceptance for PR 1: `test_world_map_registry`, `test_travel_plan`, `test_travel_flow`,
`test_region_map`, `test_encounter_director`, `test_location_registry`, the save-migration suite,
`test_long_verge`, `test_hollowmere`, `test_kesselford`, `test_ashlaren`, `test_first_chapter_journey`
green; `tools/quest_audit.gd` 0 errors; the regenerated index committed; canon documents valid.

## 2. PR 2 — FastTravelRegistry

### 2.1 `_HUBS` is replaced by the index rows that carry a `fast_travel` facet, in index order
(sorted by id). Row shape stays `{id, scene_path, display_name, base_cost_gp}`; `display_name`
comes from the row's gazetteer field. `validate()` keeps every check it has (unique ids and scenes,
cost ≥ 0, id and scene agree with `LocationRegistry`, `allowed_gameplay`).

### 2.2 Order matters to one caller: `NpcRoster.town_ids()` lists hubs first "in registry order".
Today that order is dom, kesselford, ashlaren; sorted-by-id gives ashlaren first. Keep today's
behaviour by ordering hubs with `dom` first, then by id, and say so in a comment and a test. (This
is the only ordering rule; do not invent a priority field.)

### 2.3 Value identity: fixture copy of today's `_HUBS` in `test/unit/test_fast_travel.gd`,
compared field by field.

Acceptance: `test_fast_travel`, `test_location_registry`, `test_kesselford`, `test_ashlaren`,
`test_long_verge`, `test_hollowmere` (the "no hub row" assertions), the `TownNpcSpawner` and
`NpcRoster` suites green.

## 3. PR 3 — BuildingTransitionRegistry

### 3.1 `transition` facet on an **interior** location document, describing the enter door:

```json
"transition": {
  "building_id": "kesselford_wayhouse", "building_name": "Ferry Bell Wayhouse",
  "source_scene": "res://world/kesselford.tscn", "source_anchor": "WayhouseDoor",
  "source_position": [0, 0], "prompt_text": "…", "spawn_id": "default",
  "destination_spawn_position": [0, 0],
  "required_flag": "", "reputation_faction": "", "minimum_reputation_band": "",
  "locked_message": "",
  "exit": { "source_anchor": "Room/ExitDoor", "spawn_id": "from_kesselford_wayhouse",
            "destination_spawn_position": [0, 0], "prompt_text": "…" } }
```

The enter's `destination_scene` and `destination_location_id` are the document's own scene and id.
The exit's `destination_scene` / `destination_location_id` are the enter's `source_scene` and the
location that owns it; its `id` is `<building_id>_exit`, the enter's is `<building_id>_enter`.
**Before writing the facets, diff all 24 exit `.tres` against that derivation**; put every value
that does not follow it into the `exit` object explicitly. Nothing is derived that was authored
differently.

### 3.2 The bake writes the 48 `BuildingTransitionDefinition` `.tres` under
`actors/building_door/transitions/` (they become generated, like `world/locations/*.tres`) and the
facet into the index row. `dom_tavern_interior` has no transition and gets no facet.

### 3.3 The registry builds `ENTRIES`, `EXITS`, `ALL` and the `by_id` / `entry_for` / `exit_for` /
`entries_from` lookups from the index at load. Preload consts shrink to the ones code references
(`GARRISON_YARD_ENTER`); they point at the generated `.tres`.

### 3.4 Value identity: a test that loads each generated `.tres` and compares every exported field
with the committed file at `main` (snapshot the 48 resources' field dumps as a fixture before the
change).

Acceptance: `test_building_transition_registry`, `test_building_interiors`,
`test_interior_population`, `test_reputation_area_access`, `test_location_registry` (`_hub_of`
walks `EXITS`), `test_kesselford`, `test_ashlaren` green; `BuildingDoor` still resolves every
door's `transition_id` export.

## 4. After PR 3 (Claude)

`docs/weftlumin.md` §"Limits" loses the three hand-wiring bullets; `docs/weftlumin-agents.md` §1
and §5 drop the registry steps; `docs/architecture-in-game-editor.md` §4.3.3 is amended to the
shipped shape; #342 closes.
