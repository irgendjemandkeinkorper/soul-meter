# Same-map combat — architecture note (F0, #280)

Status: **DECIDED 2026-09-04** (Claude, acting lead) under the ratified identity ruling 6
(`docs/game-identity.md`): *combat mode toggles on the field scene; no deployment for
ambient fights; off-screen mobs join the CT order when alerted; deployment survives only
for scripted set-pieces.* This note re-scopes #211 (battle stage presentation) and D4/#263
(`battle.gd` unification) and is the contract for F1 (#281) and F2 (#282). Items marked
**OWNER** need a ruling before the code that depends on them merges; everything else is
decided here.

Companion reading: `docs/architecture-tactical-and-navigation.md` (IsoGrid, opaque handles,
refusal taxonomy), `docs/prd-amendment-tactical-layer.md` (CT + grid, §4.5 boundaries).

## 1. What changes, in one paragraph

Today `Battle.start(encounter_id)` builds a private 7×N board from a synthetic
`TileMapLayer`, pauses the scene tree, and opens `ui/screens/battle.tscn` as a full-screen
overlay that redraws ground and units in screen space. After F1, a **combat session** runs
on the field scene's own `IsometricGround`/`Blocking` layers through the same
`GridBattlefieldModel`, `CombatController`, `TurnScheduler`, `Resolution`, and
`BattleInterface` we already have. The field scene is never paused; free movement is
disabled instead. Hostiles are real actors standing on the map; they enter the CT order
when alerted and leave it when downed. The six-region interface becomes a HUD over the
field, and region B (the stage) becomes a world-space overlay that highlights cells and
draws markers over the actors the field already draws.

## 2. Decisions

### D1. One grid: the field's `IsoGrid` wins
- `GridBattlefieldModel.build_grid(ground, blocking)` is called with the field scene's
  `IsometricGround` and `Blocking` `TileMapLayer`s. `Battle._grid_battlefield()` and
  `_encounter_grid_tile_set()` (`globals/battle.gd:200,281`) are deleted.
- Cell size is the field's 64×32 (`world/nav/blocking_tiles.tres`). `DS.TILE_W/TILE_H`
  (56×28) and `DS.iso_project()`/`iso_z()` are **retired from combat**; they may remain for
  the region-map/chargen mini-boards only. Anything that projects a combat cell goes through
  `IsoGrid.cell_to_world()` / `world_to_cell()`.
- Cover and elevation move onto the map: a `TileSet` custom-data layer `cover: bool` and
  `elevation: int` on `IsometricGround` (or a third layer `Terrain` if the ground atlas must
  stay art-only — implementer's choice, one of the two). `EncounterCatalog._FIELD_GRID_DATA`
  is deleted. Cliffs stay unsupported until an art pass exists (unchanged).
- `test_room.tscn` gains an authored `Blocking` layer. Every `GameFlow.GAMEPLAY_SCENES`
  entry must expose both layers; a scene without them cannot host combat and
  `Battle.can_fight_here()` returns false with the FR-606 refusal shape.

### D2. The field scene exposes a `FieldMap` contract
New `world/field_map.gd` (`class_name FieldMap extends Node2D`), the script on every
gameplay scene root (or a child node `FieldMap` the root registers — implementer's choice,
but one shape for all scenes):

```gdscript
func ground() -> TileMapLayer
func blocking() -> TileMapLayer
func iso_grid() -> IsoGrid                 # the SAME instance ClickMoveController uses
func combat_overlay() -> CombatOverlay     # see D6
func set_combat_mode(active: bool) -> void # disables free movement, hostile wander, travel exits
func hostiles() -> Array[Hostile]
func weather_default() -> StringName       # per-location (see D8)
func no_combat_zone() -> bool              # camp/home-base scenes: hostiles cannot alert here
```
`ClickMoveController.get_iso_grid()` and `FieldMap.iso_grid()` must return the same object;
a test asserts identity.

### D3. Chart: `Active → Battle` directly; deployment only for set-pieces
`ui/flow/game_flow.tscn`:
- `Active —enter_battle→ Battle` (was `→ DeploymentSlate`).
- New `Active —enter_set_piece→ DeploymentSlate → … → DeploymentPlace —accept_slate→ Battle`
  (existing chain, new entry event). `configure_placement()` receives the field's
  battlefield model and places allies on authored set-piece cells.
- `Battle —battle_end→ Active` unchanged.
- `_on_battle_entered()` no longer sets `get_tree().paused = true`. It calls
  `field.set_combat_mode(true)`, pushes the music context, and opens the battle HUD
  (`UIManager.open(BATTLE_HUD, false, true)`). `_on_battle_exited()` mirrors it.
  `Paused` (the pause menu) keeps pausing the tree as today; pausing from `Battle` is
  allowed and returns to `Battle`.
- Guards, not ifs: `enter_battle` carries an `ExpressionGuard` on `can_fight_here`
  (mirrored by GameFlow the way `rep_<faction>` is).

### D4. `Hostile` replaces `Enemy`
New `actors/hostile/hostile.gd` (`class_name Hostile extends CharacterBody2D`), scene
`hostile.tscn`. `actors/enemy/` is deleted after F1 (no compatibility shim).

```gdscript
@export var unit_id: StringName          # EncounterCatalog/UnitDefinition id
@export var group_id: StringName         # ledger + defeated-flag key (today's encounter_id)
@export var alert_radius: float = 320.0  # PROVISIONAL number, DeepSeek sweeps it in F2
@export var chain_radius: float = 192.0  # PROVISIONAL: alerted hostiles alert neighbours within this
enum State { IDLE, ALERTED, IN_COMBAT, DOWNED }
var combat_id: StringName                # FR-802 stable id, assigned at scene ready
var cell: Vector2i                       # authoritative map cell, synced to IsoGrid occupancy
func battle_actor() -> BattleActor       # built once via EncounterCatalog.make_actor(unit_id)
```
Alert sources, all of which raise `alerted(hostile)` on the `Battle` autoload:
1. any party member enters `alert_radius` (Area2D, physics layer for party only);
2. the hostile takes damage or is targeted by a hostile-facing action;
3. a hostile already `IN_COMBAT` within `chain_radius` (propagation is one hop per CT round,
   not instantaneous, so a 100-mob field does not all join on turn 1 — see F2).
`IDLE` hostiles are not in the scheduler and do not tick per frame; they may run a cheap
wander/patrol on a timer. `DOWNED` hostiles stay on the map as corpses (lootable via F4)
and set nothing in `GameState` until the group resolves (D7).

### D5. `Battle` becomes session-based; `CombatController.admit()` is the new seam
`globals/battle.gd` public API after F1:

```gdscript
func can_fight_here() -> Dictionary                      # FR-606 shape
func start_session(field: FieldMap, first: Hostile) -> void
func admit(hostile: Hostile) -> void                     # idempotent
func start_set_piece(field: FieldMap, encounter_id: StringName) -> void  # deployment path
var session_active: bool
signal session_ended(result: BattleResult)
```
`start(encounter_id)` is removed. `CombatController` gains:

```gdscript
func admit(actor: BattleActor, cell: Vector2i, side: StringName) -> Dictionary  # FR-606 shape on refusal
func release(combat_id: StringName) -> void                                      # downed/fled actors leave the order
```
`admit()` inserts the actor into the `TurnScheduler` at `current_ct + rules.admission_delay`
(new `CombatRules` field, PROVISIONAL default 40 on the 100-CT scale) so a newly alerted mob
never acts before the party's next turn. `start(ally_group, enemy_group, encounter_id)`
stays as the set-piece path and is implemented as `start` + N `admit`s so there is one
insertion code path. Allies are admitted from `GameState.party` at session start using the
existing `PartyMember → BattleActor` conversion, which becomes a named
`BattleActor.from_party_member()` (D4 of the old plan; do it now).

`tile_states` become lazy: `tile_state_at(cell)` creates on first touch; no full-map
allocation. `Weather` is configured from `field.weather_default()`.

### D6. Region B becomes `CombatOverlay`, a world-space node
`ui/hud/regions/stage/battle_stage_region.gd` stops drawing ground and units. Its
`tile_selected / tile_hovered / pointer_pressed / pointer_cleared` signals and the
`Dictionary` tile payload are kept verbatim (the `BattleInterface` contract is frozen).
Rendering moves to `world/combat_overlay.gd` (`class_name CombatOverlay extends Node2D`),
a child of every gameplay scene that draws: reachable/threatened cell tints
(`DS.charge_tint` for element charge, existing tokens for move range), the active-actor
ring, target reticle, facing chevron, and floating numbers. It is a pure `CombatEvent`
consumer via `BattleInterface.consume_event()` forwarding, exactly like the other regions
(`prd-amendment-tactical-layer.md` §4.5 holds: `CombatEvent` is the only combat input to
presentation). Actor sprites are the field's own `Hostile`/`Player`/`PartyFollowers`
nodes; region B moves them cell-to-cell on `move` events with the existing tween timing.

`ui/screens/battle.tscn` and `battle_stage.tscn` are deleted; `ui/hud/battle_hud.tscn`
(the FR-603 event-stream HUD) is folded into `BattleInterface` as planned by D4/#263. The
camera (Phantom Camera) follows the player by default and pans to the active actor for
the duration of that actor's turn when it is off-screen; enemy turns entirely off-screen
resolve without a pan (F2 budget).

### D7. Session end and the ledger
- **Victory:** every admitted hostile is `DOWNED` and no `ALERTED` hostile remains.
- **Defeat:** every party member is down. Hollowing rules (F6) apply; not death.
- **Flee (ruled 2026-09-04):** the session ends as `FLED`
  when no living hostile has any party member inside `alert_radius × 1.5` for two full CT
  rounds; fled hostiles return to `IDLE` at full HP, downed ones stay down. Ledger writes
  nothing for fled groups. *Ruled 2026-09-04 (accepted); the code path ships with
  a `PROVISIONAL` constant so the test can flip it.*
- The ledger (`Reputation.record` / `Renown` / spoils / `defeated_flag`) fires **per
  `group_id`** at the moment that group's last member is downed, not per session. The
  existing `already_resolved` dedupe keys on `group_id` and keeps working. Checkpoint
  autosave fires once at session end (unchanged behaviour, moved to `session_ended`).
- Saving is refused while `session_active` (FR-606 refusal on the pause-menu save buttons),
  so no session state is ever serialized. Save schema does not bump for F1.

### D8. Encounter data → map data
`EncounterCatalog` keeps `make_actors`/`make_actor`, spoils, faction deltas, flags, and
`display_name`. It loses `_FIELD_GRID_DATA` (D1), `battlefield`, `use_charge_time`
(always CT now; `ApRoundScheduler` stays only as the scheduler seam's alternate
implementation for tests), and `_WEATHER_DEFAULTS`, which becomes
`LocationRegistry` data `weather_default` per location (PROVISIONAL mapping preserved:
Loamroot Grove = molm, Dorthkor Road = terra, the Wound Lip = scor; Dom = none).
Hostile placement is authored in the scene (`Hostile` instances), not in JSON.

### D9. Scale budget (contract for F2, #282)
- Only `ALERTED`/`IN_COMBAT` hostiles are in the scheduler. 100 hostiles on a map is a
  presence budget, not a CT-order budget; the design target is ≤ 30 in one session.
- `IDLE` hostiles: no per-frame processing; Area2D overlap checks only.
- AI turns for actors outside camera + 1 screen margin resolve with no tween and no pan.
- Per-tick budget: enemy AI decision ≤ 2 ms averaged over a round on the FR-904 hardware;
  `docs/performance-benchmark.md` gains a `populated_field` scenario mirroring
  `populated_grid_benchmark.gd`. #175 numbers are the gate.

### D10. What does not change
`Resolution`, all damage/forecast math, `TurnScheduler` and both schedulers,
`CombatEvent`, the FR-606 refusal shape, `BattlefieldModel` opaque handles and
`capabilities()`, the `&"c:x,y,elev"` wire format, `BattleInterface` API and regions
A/C/D/E, `TileState`/`Weather` as data, `IsoGrid`, `BattleActor`, class resources and the
seam-v2 broadcast, `Reputation`/`Renown` APIs, the save schema.

## 3. Migration order for F1 (each step lands green, in this order)

| Step | Change | Proof |
|---|---|---|
| 1 | `FieldMap` contract on both gameplay scenes; `test_room` gets `Blocking`; identity test for the shared `IsoGrid` | `test_field_map.gd` |
| 2 | `GridBattlefieldModel.build_grid` from field layers; delete synthetic grid; cover/elevation from tile custom data | existing grid tests re-pointed at a real scene |
| 3 | Chart change (D3) + `set_combat_mode` instead of tree pause; deployment reachable only via `enter_set_piece` | `test_game_flow_battle_transitions.gd` |
| 4 | `Hostile` actor + `Battle.start_session/admit` + `CombatController.admit/release` with `admission_delay` | `submit_action`-path test: a hostile admitted mid-session acts after the party's next turn |
| 5 | Chain alert, one hop per round | test with three hostiles at 0/1/2 hops |
| 6 | `CombatOverlay` + region B rewire; delete `battle.tscn`/`battle_stage.tscn`; fold `battle_hud` | replay test over the frozen event log renders the same tile payloads |
| 7 | Session end (D7) with flee path behind the PROVISIONAL constant; ledger per group | victory/defeat/flee tests; `already_resolved` dedupe test |
| 8 | `EncounterCatalog` slimming + `LocationRegistry.weather_default` (D8) | drift check passes; weather forecast==resolution test unchanged |

Steps 1–3 can run as one Codex handoff; 4–5 as a second; 6 as a third (largest); 7–8 as a
fourth. `#282` starts after step 5.

## 4. Owner rulings (ruled 2026-09-04)
1. **Flee rule** (D7): **accepted as proposed.** Session ends `FLED` when no living hostile
   has a party member inside `alert_radius × 1.5` for two full CT rounds; fled hostiles return
   to `IDLE` at full HP, downed ones stay down, ledger writes nothing. Numbers stay
   PROVISIONAL constants for DeepSeek tuning.
2. **No-combat zones** (D2): **Dom interiors and the player's house are combat-free.** Dom
   streets *can* host combat (set-pieces later).
3. **Corpses across travel:** **no.** Downed hostiles despawn on scene exit; `group_id` flags
   keep them from respawning.

## 5. Risks
- Step 6 touches the frozen `BattleInterface` contract from the inside; the replay test is
  the tripwire. If the tile payload changes, stop and escalate.
- Two projections (56×28 vs 64×32) exist today; any leftover `DS.iso_project` call in combat
  code after step 6 is a bug, and a grep for it is part of step 6's acceptance.
- Pausing semantics: anything that assumed `get_tree().paused` during battle (dialogue
  balloon, interactables' `not get_tree().paused` checks) must instead check
  `Battle.session_active`. Grep `get_tree().paused` across `actors/` and `ui/` in step 3.
