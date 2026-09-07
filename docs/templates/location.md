# Template — macro location

Use this for every Wave C location issue (C1–C8). Everything below is derived from the code
that consumes it; if a field is not listed here, the engine does not read it.

## File set a worker must produce

| File | Purpose |
|---|---|
| `world/locations/<slug>.tres` | `LocationDefinition` resource (the data contract) |
| `world/<slug>.tscn` | The scene (`Node2D`, script `world/chapter_location.gd` for arrival flagging) |
| `world/<slug>/` (optional) | Interiors, dressing sub-scenes |
| `globals/npc_routines.gd` rows | Only for hub NPCs (cap: 15 routines across all hubs) |
| `globals/encounter_catalog.gd` rows | `_FIELD_GRID_DATA` / `_WEATHER_DEFAULTS` for encounters placed here; the encounter itself follows `encounter.md` |
| `test/integration/test_<slug>.gd` | Load, movement/collision, NPC range (pattern: `test/integration/test_field_room.gd`) |

**Do NOT** add the location to `LocationRegistry.ALL` or `FastTravelRegistry._HUBS` until
playtest #93 signs off (`docs/playtest-packet.md`). Keep it on `feat/region-<slug>` and note
the registry lines the reviewer must add in the handoff.

## `LocationDefinition` fields (`globals/location_definition.gd`)

| Field | Type | Meaning | Read by |
|---|---|---|---|
| `id` | `StringName` | Stable location id, kebab or snake; unique across `ALL` | `LocationRegistry.by_id`, `LoadDestination` |
| `scene_path` | `String` | `res://world/<slug>.tscn`, must exist | `GameFlow.travel()`, `LocationRegistry.by_scene` |
| `allowed_gameplay` | `bool` | `true` for any scene the player walks in | `LocationRegistry.gameplay_scenes()` → `GameFlow.GAMEPLAY_SCENES` |
| `default_spawn_id` | `StringName` | Spawn used when a traveller asks for `&"default"` | `resolve_spawn()` |
| `spawns` | `Dictionary` | `{"<requested_id>": "<marker id>"}` alias table | `resolve_spawn()` |
| `arrival_flag` | `String` | Flag set on first arrival; grammar `<domain>_<subject>_<predicate>` | `world/chapter_location.gd` |
| `arrival_checkpoint` | `String` | Label for the `LOCATION_ARRIVAL` checkpoint autosave | `chapter_location.gd` → `SaveGame` |
| `harmonic_accord` | `float 0..100` | Local Harmonic Accord (Agreement Integrity renamed, #329); 100 = neutral, C21 owns authored values | fizzle context key `harmonic_accord` |
| `thinning_tier` | `int 0..3` | FR-506 gradient input: 0 = Dom, 3 = Wound Lip | `SkillCheck.location_fizzle_integrity()` |

Spawn ids resolve to scene markers by name: spawn id `from_dom` → a `Marker2D` named
`SpawnFromDom` (`"Spawn" + PascalCase(id)`, see `globals/save_game.gd`). Every scene needs
`SpawnDefault`.

## Worked example — Wound Lip (real asset)

`world/locations/wound_lip.tres`:

```
[gd_resource type="Resource" script_class="LocationDefinition" load_steps=2 format=3]

[ext_resource type="Script" path="res://globals/location_definition.gd" id="1_definition"]

[resource]
script = ExtResource("1_definition")
id = &"wound_lip"
scene_path = "res://world/wound_lip.tscn"
thinning_tier = 3
default_spawn_id = &"default"
arrival_flag = "chapter_wound_lip_reached"
arrival_checkpoint = "location-arrival"
spawns = {
"from_dom": "from_dom"
}
```

Scene skeleton (`world/dorthkor_road.tscn` shows the same shape):

```
[node name="DorthkorRoad" type="Node2D"]           # script = chapter_location.gd
[node name="Player" parent="." instance=<player>]
[node name="SpawnDefault" type="Marker2D" parent="."]
[node name="SpawnFromDom" type="Marker2D" parent="."]
[node name="FieldHUD" parent="." instance=<field_hud>]
[node name="ReturnToDom" parent="." instance=<travel_exit>]
target_scene = "res://world/starting_town.tscn"
label_text = "RETURN TO DOM"
spawn_id = &"from_dorthkor"
required_flag = ""            # or a flag that gates the route
locked_message = "Break the demon vanguard first."
```

`TravelExit` exports (`actors/travel_exit/travel_exit.gd`): `target_scene`,
`target_location_id`, `label_text`, `required_flag` / `required_flags`, `locked_message`,
`spawn_id`, `barrier_size`. It calls `GameFlow.travel()`; never route around it.

NPCs (`actors/npc/npc.gd`): `npc_name`, `npc_id` (kebab, unique), `dialogue_path`,
`dialogue_start`, `vendor_id`, `interaction_radius`. A quest-critical NPC (a `.tres`
`giver_actor_id`, or a dialogue file containing `QuestRegistry.offer(`) that has an
`NpcRoutines` row must be present in ≥ 2 phases (`quest_audit` `phase_reachability`).

Hub routine row (`globals/npc_routines.gd`, positions in THAT scene's coordinates):

```
"sella-varn": {
    &"morning":   {"position": Vector2(2820, 1525), "state": &"working"},
    &"afternoon": {"position": Vector2(1480, 1250), "state": &"buying"},
    &"evening":   {"position": Vector2(1700, 1560), "state": &"drinking"},
    &"night":     null,   # ABSENT must be declared, never missing
},
```

Note: `NpcRoutines.HUB_SCENE` is currently Dom only; hubs 2–3 need that constant widened
(one-line change, list it in the handoff — do not do it silently).

## Flag grammar

`<domain>_<subject>_<predicate>`, lower snake case, underscores only. Domain must be in
`tools/quest_audit.gd FLAG_DOMAINS` (currently: chapter, deep_trial, dom, dorthkor,
encounter, field_debt, party, …). A new location that needs its own domain adds it to
`FLAG_DOMAINS` in the same PR — never to `LEGACY_FLAGS`.

## Pre-handoff checklist

- [ ] `.tres` loads; `scene_path` exists; `default_spawn_id` is `default` or a key of `spawns`
- [ ] Scene has `SpawnDefault` and one `Spawn<PascalCase>` per spawn alias
- [ ] Every `TravelExit` targets an existing scene; the reverse exit exists in the target
- [ ] `arrival_flag` obeys the grammar; `thinning_tier` set (C21 owns the value; use 0 and flag it)
- [ ] Integration test green under xvfb; quest audit 0 errors (`template_conformance` included)
- [ ] NOT in `LocationRegistry.ALL` / `FastTravelRegistry._HUBS`; handoff lists the lines to add
- [ ] Names/lore come from the approved C23 proposal or are prefixed `tmp_`
