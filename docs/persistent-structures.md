# Persistent structures and selective merchant service

The structure model implements the owner-approved recovery rules in
[the mechanical systems packet](../CAPABILITY-MAP-mechanical-systems.md).
It is opt-in: campaign buildings and merchants have no assignments yet. A playable
structure yard now binds saved damage to four-state art, terrain collision and
navigation. Spell targeting and NPC movement remain separate integration work.

## Play the field fixture

From the repository root, run `bash scripts/play_structure_yard.sh` (set `GODOT_BIN`
if Godot is not on PATH). This uses the existing `capture-scene` launch option so
GameFlow does not replace the fixture with the title screen.

Walk near a barricade and press **E** three times to destroy it. **F6** advances
one world phase: the maintained barricade rebuilds after two, while the abandoned
one stays ruined. Stand on the rubble to hold a due repair; stepping clear lets
it finish without another time advance. **F5/F9** store/restore a local runtime
snapshot, including the fixture player's position. Campaign autosaves are
sandboxed; these keys do not write a save slot. Restarting the fixture starts a
fresh process; durable disk persistence is covered by the save integration suite.

The fixture values (30 integrity, 10 damage per E press, two recovery phases) are
test controls, not spell formulas or campaign balance. Its generated
[sprite sheet](../assets/generated/sprites/world/objects/timber-barricade--states.png)
and [built-in imagegen prompt](../assets/generated/sprites/world/objects/timber-barricade--states.md)
are checked in together.

## Runtime ownership

`SaveGame.world_structures` owns a `WorldStructureState` instance. It survives
combat and field-scene changes. The additive `world_structures` save section
contains structure records and service assignments; old saves default to empty.
Save payload validation rejects malformed records and dangling service references
before applying them. Runtime snapshots, rollback and new-game reset include it.

`WorldClock.phase_advanced` fires only from an actual `advance()` call. The save
owner uses this signal to advance reconstruction. Restoring a clock, setting its
display phase and resetting it do not age structures. No wall-clock timer runs.

## Register and damage a structure

Content integration supplies a stable, namespaced structure ID, maximum integrity
and an authored rebuild duration in world phases. Four phases make one world day.
Zero duration means **no automatic rebuilding**. Numbers here are test values,
not campaign balance or canon:

```gdscript
var structures = SaveGame.world_structures
structures.register_structure("test-town/market", 10, 4)
structures.register_structure("test-wilds/temple", 10)
structures.damage("test-town/market", 10, WorldClock.phase_count)
structures.damage("test-wilds/temple", 10, WorldClock.phase_count)
```

Registration is idempotent with identical parameters. It never repairs an existing
record. Conflicting parameters return false instead of silently changing saved
integrity or recovery policy. Callers must handle that refusal; a future content
revision needs an explicit migration, not an implicit reset during scene loading.

Damage reduces integrity to zero at minimum. Partial damage is `damaged`; zero
integrity is `ruined`. A maintained structure receives an absolute recovery
deadline at destruction. The first later world phase marks it `rebuilding`; at
the deadline it becomes `intact`. Duplicate damage to an already ruined object is
inert. Damage during rebuilding demolishes the work and replaces the old deadline
with a new full interval. This interruption rule is an implementation default
for this slice, not a simulated labor/material economy.

## Story restoration

```gdscript
structures.begin_rebuild(
    "test-wilds/temple", 4, WorldClock.phase_count, "test-quest:restore-temple"
)
```

The event must target a ruined structure without an active recovery deadline.
The event ID is recorded once and persists after rebuilding and later destruction.
Replaying it cannot start a second restoration or postpone the first deadline.
An abandoned structure's automatic duration stays zero: a story restoration does
not turn it into permanently maintained infrastructure. Destruction during its
story-funded rebuilding cancels that job; another distinct story event is required.

## Selective merchant service

```gdscript
structures.register_service("test-grocer", "test-town/market", "item-shop", "dom")
# Omit the temporary location for a merchant whose service closes during repairs.
```

Assignments use the **existing vendor ID**, a registered structure ID, a home
location ID and an optional distinct temporary location ID. The model does not
copy merchant inventory, quest state or NPC identity. `service_status(vendor_id)`
returns `available`, `relocated`, `location_id` and `structure_id`; an unregistered
vendor returns an empty dictionary and follows the existing economy rules.

Partial structural damage leaves service usable in this first slice. Ruin or
rebuilding switches to the authored temporary location, or closes the service if
none exists. Repair returns the effective service location home.

`VendorRegistry.trade_status()` enforces both standing and structural availability.
It resolves the active scene through `LocationRegistry`; an optional third argument
supplies a location for explicit queries/tests. The existing buy/sell/stock paths
already call this gate, so a closure cannot charge money or consume stock. A
relocated service is denied at its former site and accepted at its temporary site,
subject to the same standing rules as before. Registration is not NPC relocation:
field integration must move the existing actor and its interaction point there.

## Physical field binding

`structure(id)` and `to_dict()` return detached snapshots. `structure_changed(id)`
reports a physical state transition; `state_restored` reports a snapshot replacement.
Presentation can consume these without being allowed to mutate internal rows.

`actors/destructible/destructible_structure.tscn` extends the existing
`SMInteractable` input/range/feedback contract. Authors supply a stable structure
ID, integrity, rebuild duration, a `blocking_path` pointing to `BlockingLayer`,
and an exclusive array of painted footprint cells. Positions are authored at
the actual `map_to_local()` centers; isometric cells include a center offset.
Use static, unflipped collision tiles and do not move their layer after binding.
The fixture demonstrates the contract without changing a campaign map.

The object captures those cells' tile IDs before applying saved state. Damage
retains collision until integrity reaches zero, then erases only those cells.
Rebuilding keeps the footprint open until completion. Restoration puts the
original tiles back. `BlockingLayer.set_structure_footprint()` emits one change
notification after the edit; existing `IsoGrid` consumers refresh their static
obstacles while preserving actor occupancy and terrain weights. A grid rebuilt
against another field clears old solids and disconnects from the old layer.

`SaveGame.advance_world_structures()` gathers loaded objects' occupancy vetoes
before calling the model. Body shapes, live actor positions and non-colliding
party followers can hold a repair. Active field combat also holds repairs and
disables the inherited E interaction. A due object's 0.25-second poll only
retries placement at the **same world phase**; it never advances world time.
Offscreen structures continue to use their saved deadlines.

`apply_structure_damage(amount)` accepts an already-resolved positive amount.
`interaction_damage` defaults to zero; only the yard enables manual test strikes.
This is a damage receiver, not yet a spell target. Cover metadata, combat target
selection, entrances, physical merchant relocation and open-shop refresh still
need integration before assigning whole campaign buildings.

## Verification

Focused suites:

```sh
SOUL_METER_HEADLESS=1 GODOT_BIN=/home/adamjroder/.local/bin/godot bash scripts/test.sh \
  -a test/unit/test_world_structure_state.gd \
  -a test/unit/test_structure_persistence.gd \
  -a test/unit/test_structure_services.gd
```

The tests cover maintained versus abandoned recovery, idempotent registration,
occupied-footprint deferral at model level, interrupted construction, consumed
story events, detached snapshots, corrupt-save rejection, disk save/load, real
clock advancement, new-game reset, rollback, selective service locations, standing
gates and stock/money preservation. All saves in these tests use temporary paths.

### Recorded verification — 2026-09-09

Godot import completed without script parse/compile errors. All 18 new tests passed,
as did the focused save, clock, vendor and pricing suites.

The full feature run executed 1,930 cases: zero errors and nine failed assertions
across three pre-existing tests. A full run of the starting commit `4e8db002` in an
isolated checkout executed 1,912 cases with the same failures. Both revisions pass
all 22 cases from those three suites when run in isolation. This records a known
full-suite/order-or-environment issue; it does not claim a green full suite.

| Existing failing test | Full-run assertion locations |
|---|---|
| `test_thirty_outdoor_townsfolk_spawn_from_generated_placements` | `test/integration/test_town_townsfolk.gd:72–73`, two NPC dialogue path/title pairs |
| `test_all_thirty_indoor_npcs_use_generated_positions_and_dialogue_titles` | `test/integration/test_interior_population.gd:48–49`, two NPC dialogue path/title pairs |
| `test_holding_sprint_moves_the_player_materially_faster` | `test/integration/test_field_room.gd:160`, headless movement ratio |

Local evidence: feature `reports/report_1375/results.xml`; baseline
`/tmp/soul-meter-structure-baseline/reports/report_2/results.xml`. Reports are
generated artifacts. No existing test was weakened or disabled to obtain a pass.

### Field object verification — 2026-09-09

The final focused run passed **50/50** cases across the grid, structure model,
save persistence, merchant service, interactable and field-map suites
(`reports/report_1385/results.xml`). Six new cases exercise field input,
damage/art/collision, scene re-entry, occupied repair and automatic retry,
combat deferral, fixture snapshot rewind, live grid edits and scene teardown.

Native Godot/OpenGL captures verified intact, damaged, ruined and rebuilding
frames at gameplay scale. The source sheet is a 1254×1254 RGBA PNG consumed
directly as four frames; no raster postprocessing was applied.

Final full run: **1,936 executed cases**, zero runtime errors, and the same nine
failed assertions in the three baseline tests listed above
(`reports/report_1386/results.xml`). Test names and failure locations were compared
programmatically with the unmodified baseline report and match exactly. The
scene-teardown regression found during the focused follow-up is fixed and covered
by a dedicated grid test.
