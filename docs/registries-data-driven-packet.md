# World map, fast travel and building transitions from canon — owner review packet

**Issue:** #342 (E3.3b, second half). **Status:** owner ruling required; nothing is changed by this
packet. Written 2026-10-22 from the code on `main` @ `1758d88e`.

**Why this is in front of you.** `LocationRegistry` has read `data/generated/location_index.json`
since PR #488. The other three registries still hold hand-typed tables, so every new location
package (the Kesselford, Ashlaren, Long Verge and Hollowmere PRs all did this) hand-edits
`WorldMapRegistry`, `FastTravelRegistry` and `BuildingTransitionRegistry` beside its canon files,
and `docs/weftlumin.md` §"Limits" lists that as the known hole. The 2026-10-12 note on #342 named
two things only you can settle: the canon format that will carry this data, and which spelling of
three location ids wins. Both are below with a recommendation. Route numbers and hub costs are
**not** part of this ruling; they move as they are, still marked PROVISIONAL.

## 1. What is hand-wired today

| Registry | Rows | Read by | Numbers in it |
|---|---|---|---|
| `globals/travel/world_map_registry.gd` | 8 nodes (`id`, `scene_path`, `map_coordinate` 0–1), 8 routes (`steps`, `phases_cost`, `risk_tier`, `risk_modifier`, weighted `encounter_table`, `min`/`max_encounters`; one `band_encounter_weights`) | region map, `GameFlow` journeys, `EncounterDirector`, `GameState` discovery, the quest editor | routes 4–8 PROVISIONAL (C1–C4) |
| `globals/fast_travel_registry.gd` | 3 hubs (`dom` 25, `kesselford` 40, `ashlaren` 60 GP) | `GameFlow.fast_travel`, hub discovery, `TownNpcSpawner`, `NpcRoster.town_ids` | all three PROVISIONAL; header says "no ratified hub/travel-cost contract" |
| `actors/building_door/building_transition_registry.gd` | 48 preloaded `.tres` (24 enter/exit pairs: 20 Dom, 2 Kesselford, 2 Ashlaren) | `BuildingDoor` by `transition_id`; `GameFlow` names one const (`GARRISON_YARD_ENTER`) | gates only (flags, Iron Companies band) |

`weftlumin.location.v1` (`weftlumin/kinds/locations.gd`) rejects any key outside its gazetteer and
scene fields, so none of this can be written in canon yet. The editor note
(`docs/architecture-in-game-editor.md` §4.3.3) sketched `world_map`, `fast_travel_hub` and
`transitions` facets, but its shapes predate the code: pixel positions where the code uses 0–1
coordinates, a `danger_rank` where the code has steps, phases, risk tier and modifier, no hub cost.

## 2. Ruling A — where the data lives in canon

### A1. Facets on the location document, routes as their own documents — **recommended**

- A location document gains three **optional** facets, so every existing file stays valid:
  `world_map: {map_coordinate: [x, y]}`, `fast_travel: {base_cost_gp: 40}` (present means hub;
  Long Verge and Hollowmere simply omit it), and on an interior, `transition: {building_id,
  building_name, source_scene, source_anchor, source_position, prompt_text, spawn_id,
  destination_spawn_position, required_flag, reputation_faction, minimum_reputation_band,
  locked_message}` for the enter door; the exit is derived (`<building>_exit`, anchor
  `Room/ExitDoor`, spawn `from_<building>`), which is how all 24 pairs are built today.
- A route is one file, `canon/<hub>/routes/<origin>-<destination>.json`,
  `weftlumin.route.v1`, with exactly the fields the code has now. It lives in the origin's hub
  package. A route is between two locations, so it is not a facet of either.
- The bake writes the facets and a `routes[]` array into the one generated index (schema bumps to
  `weftlumin.location_index.v2`) and keeps writing the `.tres`, including the 48 transition
  resources, which become generated like `world/locations/*.tres` already are. The three
  registries read the index; named consts that code still references stay.
- Fits ruling 2 of the editor note (canon is the text canonical layer) and the shape the location
  document already has: `harmonic_accord` and `thinning_tier` are game numbers in canon today, so a
  hub cost beside them is the same kind of thing. The `FastTravelRegistry` header's older plan,
  "migrate to generated Pandora output", predates the Weftlumin rulings; this supersedes it.

### A2. Everything on the location document, as §4.3.3 sketched

Routes as a `routes[]` list on the origin location. Cheaper to write, but a route edit then touches
the origin's document, the destination's package cannot carry its own return route, and the quest
editor cannot list routes without walking every location. Not recommended.

### A3. Leave the three tables in code

Status quo. Every location PR keeps hand-editing three registries; the in-game editor's
`new_scene` can never make a reachable location on its own. Not recommended.

## 3. Ruling B — one id per location

Three ids are spelled two ways: the world map says `dorthkor-road`, `wound-lip`, `long-verge`;
canon, the index, the `.tres`, the save's top-level `location_id`, the fast-travel hub ids and the
NPC roster say `dorthkor_road`, `wound_lip`, `long_verge`. Code bridges them by comparing
`scene_path` strings in three places. The world-map spelling is in saves twice:
`travel_plan.origin_id` / `destination_id`, and the flag `world_location_discovered:<id>`.

### B1. The location id wins — **recommended**

Rename the three world-map node ids to the location ids and retire the `scene_path` bridge: a
world-map node *is* the location, looked up by id. One save migration, v9 → v10, rewrites the two
`travel_plan` ids and the three discovery-flag keys (the migration pattern already exists for
v2 → v9; mid-journey plans are re-derived by `TravelPlan.reconcile()` as today). Cost: one file,
one migration, the tests that spell the ids. Saves are pre-gold playtest saves.

### B2. The world-map (hyphen) spelling wins

Rename the three location ids instead. The underscore spelling is in 36 files outside tests
(canon, scenes, dialogue, NPC data, generated artifacts) plus the save's `location_id`; 28 of the
33 scene-backed ids already use underscores and the other five are single words, so no scene-backed
id uses a hyphen today. Larger for no gain. Not recommended.

### B3. Alias field, no migration

`world_map.id` on the document, defaulting to the location id. No save change, but the double
naming the issue called a blocker becomes permanent. Not recommended.

## 4. What does not change

- No name, coordinate, route number, encounter weight or hub cost changes. PROVISIONAL marks move
  with the data; item 4 (Hollowmere route numbers) and the balance pass still own them.
- Save compatibility is preserved by the v10 migration; `location_id` + `scene` resolution and the
  `travel_plan` round-trip keep their tests.
- `GameFlow` edits are no longer frozen: #281 and #283 closed 2026-10-10.

## 5. Sequencing and cost (after your answer)

Three Codex PRs on `feat/weftlumin-data-driven-registries`, one registry each as #342 says, Claude
reviewing: (1) format + bake + index v2 + `WorldMapRegistry` + the id migration; (2)
`FastTravelRegistry`; (3) `BuildingTransitionRegistry` with the 48 `.tres` generated. Existing
suites pin the counts (8 nodes, 8 routes, 3 hubs, 48 transitions) and keep passing because the data
is identical; each PR adds an "index and registry agree" test. Then `docs/weftlumin.md` §"Limits"
and `docs/weftlumin-agents.md` lose the hand-wiring steps, and §4.3.3 of the editor note is amended
to the shipped shape. About two to three worker days plus review.

## 6. Answer format

`18: as recommended` (A1 + B1), or `18: A<n> B<n>` with any change you want on the field names.
