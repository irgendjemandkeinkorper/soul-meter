# Architecture — Tactical Grid, Navigation, State at Scale, and the Soul Meter

**Status:** DRAFT — proposed, not ratified
**Date:** 2026-08-07 · **Owner:** Adam (solo dev)
**Language rule:** ASD-STE100 (Simplified Technical English), adopted 2026-08-07.
Game content is excluded from this rule. See §7.
**Derives from:** `docs/prd-chapter-one.md` (RATIFIED 2026-08-03),
`docs/prd-amendment-tactical-layer.md` (RATIFIED 2026-08-05),
`docs/godot-architecture.md` (the five-layer spec)
**Session decisions:** `.claude/session-intent.md` (D1 to D8, 2026-08-07)

---

## 0. Purpose

This document gives the Godot scene structure and script structure for four systems. The
2026-08-07 planning reset named these four systems.

This document is architecture. It is not authorisation.
`docs/prd-amendment-tactical-layer.md` §8.1 prevents work on grid content until Gate T passes.
The amendment permits work on the interface. §2.1 of the amendment makes the interface work
mandatory.

This document does three things that you must know:

- It does not re-open FR-102a (charge time). It does not re-open FR-105a (grid). Both are
  ratified.
- It does not answer open canon questions. It names them in §6 and leaves them open.
- It does not add an upper-bound penalty to the Soul Meter. Canon holds. See §4.1.

### 0.1 The governing precedent

Copy `globals/combat/turn_scheduler.gd`. Its own header states the reason:

> The retired FR-102 AP economy had no interface: `action_points`/`ap_cost` were inlined
> across 34 sites in `combat_controller.gd`, which is why retiring it is a controller rewrite
> instead of a swap.

This lesson governs every section below. Apply it as one rule:

> **Put an interface in front of a decision before the first implementation. Do not wait for
> the second implementation.**

---

## 1. Tactical combat — the widened `BattlefieldModel`

### 1.1 Present state

The team measured these values on 2026-08-07. See the Appendix for the commands.

| Item | Value |
|---|---|
| `BattlefieldModel` implementations | 1 (`zone_battlefield_model.gd`) |
| `GridBattlefieldModel` | **Does not exist** |
| Consumer call sites in `combat_controller.gd` | **14** (lines 65, 107, 109, 348, 383, 428, 430, 439, 528, 535, 539, 546, 662, 663) |
| Position type | `StringName` — `&"front"`, `&"back"`, `&"flank"` |
| Concepts the interface can express | side, position, cover, flank, AoE shape |
| Concepts FR-105a needs | cells, elevation, facing, occupancy, line of sight, path cost |

Fourteen call sites make a small surface. Widen the interface now. The cost increases with
each encounter that you author against the narrow interface.

### 1.2 The controlling constraint

Amendment §8.1 gives this stop-loss rule:

> Stop if the interface cannot express cells/elevation/facing/occupancy/LOS/path-cost without
> consumers learning the concrete type.

The design problem is therefore not "how do I show a grid". The design problem is this:

> **How do I show a grid, and keep `CombatController` unaware that a grid exists?**

### 1.3 The solution — opaque handles and capability queries

Keep `StringName` as the position type. Treat it as an **opaque handle**. The zone model
already meets this rule. No consumer reads the contents of `&"front"`. Each consumer passes
the handle back to the model.

The grid model makes its own handles. An example handle is `&"c:12,7,1"` for cell x, cell y,
and elevation. Consumers stay unaware of the contents.

State the rule so that a test can check it:

> No consumer outside `globals/combat/*_battlefield_model.gd` may build, read, split, or
> pattern-match a position `StringName`. Handles come from the model. Handles go back to the
> model.

Get structured detail from query methods. Each query method returns a Dictionary. Never read
the contents of a handle.

```gdscript
# --- additions to globals/combat/battlefield_model.gd ---

## What this model can express. A consumer branches on capabilities, never on type.
## The zone model reports each spatial capability as false and stays fully functional.
func capabilities() -> Dictionary:
    return {
        "cells": false, "elevation": false, "facing": false,
        "occupancy": false, "line_of_sight": false, "path_cost": false,
    }

## Structured description of an opaque position handle.
## Zone model returns {"kind": &"zone", "id": &"front"}.
## Grid model returns {"kind": &"cell", "cell": Vector2i, "elevation": int}.
## A consumer reads the named fields that capabilities() declared.
func describe_position(_position: StringName) -> Dictionary:
    return {}

## Each position that this actor can legally reach with `ct_budget` charge time.
## Zone model returns the legal zones. Grid model returns an AStarGrid2D flood fill.
## One signature. One return shape. No consumer branch.
func reachable_positions(_actor: BattleActor, _ct_budget: int) -> Array[StringName]:
    return []

## Path cost in the refusal shape. Returns {allowed, blocked_by, nearest_unblock, message}.
## Adds {"ct_cost": int, "path": Array[StringName]} when allowed is true.
func path_query(_actor: BattleActor, _destination: StringName) -> Dictionary:
    return _blocked(&"position", "Positioning model does not support paths.", {})

## Facing. The zone model returns &"" and refuses to set. capabilities() declared this.
func facing_of(_actor: BattleActor) -> StringName:
    return &""

func set_facing(_actor: BattleActor, _facing: StringName) -> Dictionary:
    return _blocked(&"facing", "Positioning model does not support facing.", {})

## Line of sight, in the refusal shape.
## `blocked_by` must separate &"blocked_by_elevation" from &"blocked_by_occupancy" and from
## &"blocked_by_range". Amendment §2.2 and FR-606 both require this separation.
## A single &"no_los" destroys the refusal taxonomy. Do not use one.
func line_of_sight(_actor: BattleActor, _target: BattleActor) -> Dictionary:
    return _allowed()

## The actor at a position, or null.
func occupant_of(_position: StringName) -> BattleActor:
    return null

## Elevation delta. Target minus actor. The zone model always returns 0.
func elevation_delta(_actor: BattleActor, _target: BattleActor) -> int:
    return 0
```

Each addition obeys two conventions that the project already uses:

1. **The refusal shape** `{allowed, blocked_by, nearest_unblock, message}`.
   `BattlefieldModel._blocked()` and `TurnScheduler._blocked()` already share this shape. One
   refusal shape across positioning, casting, and turn order lets FR-606 answer "why can I not
   do this?" through one code path.
2. **Base-class defaults that degrade honestly.** The zone model inherits each new method
   without change. The zone model continues to work. The widened interface must not break the
   zone model on day one. Amendment §8.1 reversibility depends on the zone model. Keep the
   zone model alive until Gate T passes.

### 1.4 Why `capabilities()` and not `is_grid()`

A boolean `is_grid()` is a concrete-type check in disguise. It fails the §8.1 criterion.

`capabilities()` also does a second job. It drives the adaptation of the UI. The battle HUD
shows an elevation indicator when `capabilities().elevation` is true. The HUD hides the
indicator when the value is false. No HUD code names either model.

### 1.5 File layout

```
globals/combat/
  battlefield_model.gd          # widened interface + create_default()  [EDIT]
  zone_battlefield_model.gd     # no change; inherits the new no-op defaults [DO NOT EDIT]
  grid_battlefield_model.gd     # NEW — sibling implementation
  grid/
    iso_grid.gd                 # NEW — AStarGrid2D + iso projection (SHARED, see §2)
    elevation_map.gd            # NEW — height per cell, authored as TileMapLayer custom data
    facing.gd                   # NEW — 8-direction facing math + arc classification
```

`create_default()` is the only construction site. Keep it to one switch. §8.1 requires that a
change back to zones is a data change. Do not make it a code change.

```gdscript
static func create_default(rules: CombatRules) -> BattlefieldModel:
    var path := "res://globals/combat/zone_battlefield_model.gd"
    if rules.use_grid_battlefield:        # NEW @export on CombatRules, default false
        path = "res://globals/combat/grid_battlefield_model.gd"
    var model := (load(path) as Script).new() as BattlefieldModel
    model.configure(rules)
    return model
```

Set the default to `false`. The grid must not become live because it exists. Gate T changes
the flag.

### 1.6 How the grid model uses `AStarGrid2D`

`GridBattlefieldModel` owns one `IsoGrid` (§2.2). It adds four combat concerns:

- **Movement range.** Use an `AStarGrid2D` flood fill. Bound the fill by the CT budget. Use
  `CombatRules.move_ct_cost` for each step. Set `DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES`. This
  setting stops a path that cuts a corner through a building.
- **Elevation as path cost.** Use `set_point_weight_scale()`. Scale the weight by the height
  delta. A climb costs more CT. Make a cliff an impassable point. Do not make a cliff an
  expensive point. This keeps "blocked by elevation" and "expensive because of elevation" as
  different refusals. §2.2 requires the difference.
- **Occupancy.** Set `set_point_solid()` for each living combatant. Do not set it for a
  corpse. Recalculate after each move and after each death. Do not cache across a turn.
- **Line of sight.** Use a Bresenham line across the cells. Test the line against a blocking
  tile layer and against elevation. High ground sees across low cover. Gate T exists to
  validate this mechanic.

### 1.7 Interaction with charge time

The grid does not change turn order. `TurnScheduler` owns order. `BattlefieldModel` owns
space. `CombatRules.move_ct_cost` is the single contact point. Movement has a price in CT.
`path_query()` returns a `ct_cost`. `CombatController` gives that cost to
`scheduler.commit()`.

**A defect here is expensive and silent.** `path_query().ct_cost` must equal
`scheduler.quote()`. If the two disagree, the timeline lies. FR-102a forbids this. Test the
equality as an invariant. Do not test it as one example.

### 1.8 Save and determinism

`ChargeTimeScheduler` is strict about determinism. It uses no RNG. It serializes seats. It
keeps CT overflow. The grid model must meet the same standard. If it does not, it becomes the
weak link.

- Add `to_dict()` and `from_dict()` to `GridBattlefieldModel`. Save the cell, the elevation,
  and the facing of each actor.
- **Use no RNG in path selection.** Resolve equal-cost paths with a stable tie-break. Use the
  lowest cell index. A replay then selects the same path each time.
- Amendment §5 criterion 8 requires that grid position, facing, elevation, and CT all survive
  a save round trip. Write one test. Cover all four.

### 1.9 Definition of done — the seam, before Gate T

- [ ] The interface is wider. `zone_battlefield_model.gd` has **zero** changes.
- [ ] All 305 existing tests pass. No test was modified.
- [ ] `GridBattlefieldModel` passes the behavioural suite that the zone model passes.
- [ ] `rg` shows no consumer outside the model files that builds or reads a position handle.
- [ ] `capabilities()` drives each UI branch. No `is_grid()`. No `as GridBattlefieldModel`.
- [ ] A test proves `path_query().ct_cost == scheduler.quote()`.
- [ ] A test proves that position, facing, elevation, and CT survive a mid-battle save.
- [ ] `use_grid_battlefield` defaults to **false**. The flag is the only activation.

---

## 2. Isometric world and navigation — the unbuilt layer

### 2.1 Present state

```
world/isometric_blockout.gd   IsometricBlockout extends TileMapLayer
                              TILE_SIZE = Vector2i(64, 32), z_index = -10
                              procedural fill: grass/dirt/stone + road axes
actors/player/player.gd       Player extends CharacterBody2D
                              Input.get_vector(...) * speed; move_and_slide()
```

**`AStarGrid2D` has 0 occurrences. `NavigationServer2D` has 0. `NavigationAgent2D` has 0.**

The planning brief is correct on this point. This is the largest unbuilt gap in the overworld.
Movement uses raw velocity. Nothing calculates a path. Obstacle avoidance depends on collision
bodies, and the procedural blockout does not author them.

### 2.2 `IsoGrid` — one grid for two layers

D4 selects this design. It is the highest-leverage item in this document. **One `AStarGrid2D`
construction serves overworld click-to-move and tactical movement range.** One technology. Two
consumers. One set of defects.

```gdscript
# world/nav/iso_grid.gd
class_name IsoGrid
extends RefCounted
## Shared isometric pathfinding substrate. Built from a TileMapLayer.
## Consumed by the overworld click-to-move controller AND by GridBattlefieldModel.
## Neither consumer knows about the other.

var _astar := AStarGrid2D.new()
var _ground: TileMapLayer
var _blocking: TileMapLayer     # obstacle layer; may be null

func build(ground: TileMapLayer, blocking: TileMapLayer = null) -> void:
    _ground = ground
    _blocking = blocking
    var used := ground.get_used_rect()
    _astar.region = used
    _astar.cell_size = Vector2(ground.tile_set.tile_size)   # 64 x 32
    # Iso diagonals look cardinal. A Euclidean heuristic ranks them incorrectly.
    _astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
    _astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
    # Never cut a corner through a building.
    _astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    _astar.update()
    _bake_obstacles()

func _bake_obstacles() -> void:
    if _blocking == null:
        return
    for cell in _blocking.get_used_cells():
        if _astar.is_in_boundsv(cell):
            _astar.set_point_solid(cell, true)

# --- coordinate conversion: the ONLY place that holds world/cell math ---
func world_to_cell(world: Vector2) -> Vector2i:
    return _ground.local_to_map(_ground.to_local(world))

func cell_to_world(cell: Vector2i) -> Vector2:
    return _ground.to_global(_ground.map_to_local(cell))

func path_cells(from: Vector2i, to: Vector2i) -> PackedVector2Array:
    if not _astar.is_in_boundsv(to) or _astar.is_point_solid(to):
        return PackedVector2Array()
    return _astar.get_id_path(from, to) as PackedVector2Array

func path_world(from: Vector2, to: Vector2) -> PackedVector2Array:
    var cells := path_cells(world_to_cell(from), world_to_cell(to))
    var out := PackedVector2Array()
    for c in cells:
        out.append(cell_to_world(Vector2i(c)))
    return out
```

**Reason for `AStarGrid2D` instead of `NavigationServer2D`:** the tactical layer needs
discrete cells, a movement budget for each cell, occupancy, and range highlight. A navigation
mesh gives a continuous path. A navigation mesh cannot answer "which cells can I reach with 40
CT".

One system for both layers is worth more than the small gain in smoothness that a navigation
mesh gives on the overworld. The overworld work therefore reduces the risk of Gate T. Keep
`NavigationServer2D` available for later. Hub NPC routines (§4, D6) may need crowd avoidance.

### 2.3 Obstacle authoring — the missing layer

`IsometricBlockout` generates ground only. Buildings do not exist as data today. Nothing can
collide with them for this reason. Add a sibling `TileMapLayer` for obstacles:

```
world/starting_town.tscn
└── YSortRoot                      (Node2D, y_sort_enabled = true)
    ├── Ground        IsometricBlockout : TileMapLayer   z_index -10, y_sort off
    ├── Blocking      TileMapLayer                       obstacle cells; source of truth
    ├── Props         Node2D                             y_sort children (buildings, trees)
    ├── NPCs          Node2D                             y_sort children
    └── Player        CharacterBody2D
```

Make the blocking layer the **single source of truth for passability**. Derive the
`AStarGrid2D` bake from it. Derive the physics collision from it also. Do not author obstacles
twice. Two authoring paths drift apart. The drift stays invisible until a player walks through
a wall.

### 2.4 Y-sorting — the depth rules

Apply three rules. All three are necessary.

1. Set `y_sort_enabled = true` on the **common parent** (`YSortRoot`). Do not set it on each
   sprite.
2. Keep the ground **outside** y-sorting. Give it a fixed low `z_index`. The ground must never
   sort against an actor. `IsometricBlockout` already sets `z_index = -10`. Keep this value.
3. Put the origin of each sortable sprite **at the feet** of the character. Do not put it at
   the centre.

Rule 3 prevents the most common isometric defect. A centred origin sorts a tall sprite half a
body too early. The sprite then flickers in front of a prop that it stands behind.

For a building that covers several cells, use a `TileMapLayer`. Set `y_sort_origin` for each
tile in the TileSet. This sorts correctly. You do not need to split the sprite.

### 2.5 Click-to-move controller (D4)

Keep `CharacterBody2D` on `Player`. This is a controller change. It is not a rewrite. Add a
sibling component. A component keeps the movement mode swappable and testable in isolation.

```
actors/player/
  player.gd                  # keeps CharacterBody2D, move_and_slide, footsteps
  click_move_controller.gd   # NEW — owns the path queue and the follow logic
```

Flow of control:

1. The player clicks.
2. `IsoGrid.world_to_cell()` converts the click to a cell.
3. `path_cells()` returns the path.
4. The controller stores a queue of world waypoints.
5. `_physics_process` steers `velocity` toward the next waypoint.
6. The controller removes each waypoint on arrival.

Obey these five constraints:

- **Keep the footsteps.** `_update_footsteps()` reads `get_last_motion()`. It works with
  pathed movement without change. Do not rewrite it.
- **Keep `facing_direction`.** The interaction system reads it. The click controller must
  continue to set it from the movement vector.
- **Refuse an unreachable click.** Return the refusal shape of the project. Show the refusal.
  FR-606 states this principle for combat. The reason applies here also. A click that does
  nothing, and shows nothing, looks like a defect.
- **Recalculate the path when an obstacle changes.** Examples are an open door and an NPC that
  stops in a doorway. The calculation is cheap. Its absence causes the classic symptom: the
  actor walks into a wall forever.
- **Do not delete keyboard input.** Keep WASD as a debug path and an accessibility path. The
  cost is almost zero. FR-607 requires input remapping. D4 selects click-to-move as the
  *primary* mode. D4 does not require you to delete the alternative.

### 2.6 Definition of done

- [ ] `IsoGrid` builds from `IsometricBlockout` and a blocking layer. A fixture unit-tests it.
- [ ] A test proves that `world_to_cell` and `cell_to_world` round-trip across the map rect.
- [ ] Click-to-move paths around a building in `starting_town.tscn`. It **cannot** cross it.
- [ ] Y-sort is correct. The prop hides the player above it. The player hides the prop below.
- [ ] An unreachable destination produces a refusal. It does not produce silence.
- [ ] Footsteps still work. `facing_direction` still works. NPC interaction range is unchanged.
- [ ] The existing field-room movement, collision, and NPC-range tests still pass.
- [ ] `IsoGrid` has **no** dependency on `globals/combat/`. It is the shared layer.

---

## 3. Global state and flags at scale

### 3.1 Present state

`GameState` already carries the load. It holds `flags: Dictionary` with `set_flag()`,
`get_flag()`, and the `flag_changed` signal. It also holds the Soul Meter, GP, party, GLoot
inventory, skills, Vär harmony, combat knowledge, vendor stock, and settings.

`Reputation` is the separate append-only ledger. `Renown` is the second ledger, and it is
faction-independent. `SaveGame` is at schema 5. It has a migration scaffold and a fixture.

**The architecture is sound.** It does not need a replacement at several hundred quest
variables. It needs three disciplines that it does not enforce today.

### 3.2 Discipline 1 — namespace the flag IDs

`flags` is an untyped `Dictionary` with string keys. This is acceptable at 20 flags. At 400
flags it becomes a collision surface with no diagnostics.

Adopt this grammar. Make it mandatory.

```
<domain>_[<subject>_]<predicate>
dom_dishonest_casks_resolution
chapter_dorthkor_commissioned
encounter_bog_wight_outcome
field_debt_open                 # the subject is optional
```

**Corrected 2026-08-07. An earlier version of this section proposed a dotted form
(`<domain>.<subject>.<predicate>`). That was wrong, and §3.3 below says why.**

Every shipped flag is underscore-separated. Those names are written into save files, quest
`.tres` resources, `data.pandora`, and scene files. Adopting dots would have renamed about 55
shipped flags. §3.3 states that a rename is a save migration, never an edit. The dotted form
therefore proposed a migration that buys nothing a player can see, in a document that also
forbids exactly that. The grammar now describes what the content already does.

The subject is **optional**, for the same reason. Content uses both shapes, and neither is
wrong: `dom_dishonest_casks_resolution` names a subject, `field_debt_open` does not need one.

A domain must be registered in `FLAG_DOMAINS` before content may use it. That is the point of
the rule: it catches a typo (`dom_` against `domm_`) and a missing namespace, which both fail
silently today.

`tools/quest_audit.gd` already checks orphaned flags and read-backs. It now also enforces the
grammar, in a separate `flag_grammar` category, and rejects three conditions:

- A flag that the code writes but never reads. This is a dead consequence.
- A flag that the code reads but never writes. This is a broken branch.
- A flag with no registered domain, or with wrong case. This is a namespace violation.

Flags that predate the rule sit in a `LEGACY_FLAGS` list with a recorded reason for each. That
list protects existing saves. **Do not add to it to silence a new flag:** a new flag has no save
to protect, so it must satisfy the grammar.

**Read the header of `quest_audit.gd` before you trust a green result.** `CLAUDE.md` gives this
warning. The warning applies to the extension also. Two limits are specific to the grammar
check: it reads `.gd` and `.dialogue` sources only, so a flag named solely in a `.tscn` or
`.tres` is unscanned, and a flag built by format string is skipped rather than reported, because
the scanner sees the unsubstituted template.

### 3.3 Discipline 2 — stable IDs are a save contract

FR-802 already requires stable ID schemas. The schemas cover actors, quests, skills, items,
zones, world facts, and dialogue nodes. State the architectural result plainly:

> **A flag ID that has shipped in a save file is permanent.** A rename is a save migration. A
> rename is never an edit.

Grid positions join this list. See §1.8. The handle `&"c:12,7,1"` is serialized. The handle
*format* therefore becomes save-visible on the day the grid ships. Put a version on the format
in the save envelope from the start.

### 3.4 Discipline 3 — three ledgers, three questions

The project has three consequence stores. The separation is deliberate. Keep the boundary
sharp. A sharp boundary stops the three stores from collapsing into one unclear "karma" number.

| Store | Question it answers | Write path |
|---|---|---|
| `GameState.flags` | "Did this happen?" | `set_flag()` |
| `Reputation` | "How does *faction X* feel about me?" | `record()` — append-only, the only path |
| `Renown` | "How famous or infamous am I, globally?" | `gain_reputation()` / `gain_infamy()` |

`Reputation.why()` and `Renown.why(kind)` are the derived reads. They feed the "why" UI of
FR-404. FR-907 also names that UI as the day-2 recap. One mechanism serves two features.

### 3.5 Dialogue integration

Dialogue Manager reads `GameState` directly for its conditions. One syntax rule is
load-bearing. `DEPENDENCIES.md` already records it:

> Response conditions need the self-closing form `[if expr /]` — plain `[if expr]` silently
> no-ops.

A silent no-op means that a broken consequence check looks exactly like a working one. This is
the highest-value target for an automated lint in this document.

Write the lint. Scan `dialogue/*.dialogue`. Find each `[if]` in response position that is not
self-closing. Fail CI on a match. The lint is cheap. It catches a class of defect that
playtesting finds late and at high cost.

### 3.6 Definition of done

- [ ] The flag grammar is documented. `quest_audit.gd` enforces it.
- [ ] The audit fails on an orphaned write. The audit fails on an unwritten read.
- [ ] CI runs the `[if expr]` against `[if expr /]` lint.
- [ ] The save round-trip fixture grows past schema 5 as new state arrives.
- [ ] No new global state store exists. The three ledgers absorb the new state, or a written
      argument justifies the fourth store.

---

## 4. The Soul Meter

### 4.1 Canon — D5, binding

`dramgid-vault/cosmology/souls.md` states:

> Magic spends the Gauge, and **it mostly only goes down** — it is not a mana pool that
> refills overnight; it is closer to a wound count. […] Cast to zero and the soul unravels —
> death, or worse, **husking-while-alive**. Recovery is slow, partial, and social […] rest,
> meaning, love, ritual, and *being witnessed and remembered by others.*

**Canon has no high-end penalty. This document does not add one.** The planning brief proposed
a penalty at high values and at low values. The owner rejected that proposal on 2026-08-07.

Keep `soul_meter` as `clampf(value, 0.0, 100.0)`. The value 100 is a ceiling. It is not a
danger zone.

Name the design result, because it is the stronger reading. The tension comes from **spending
a finite self**. The tension does not come from balance of a needle. A needle teaches a player
to stay in the middle. A wound count makes each cast a real decision about worth.

### 4.2 Present implementation

| Part | Location |
|---|---|
| Value and signal | `GameState.soul_meter`, `set_soul_meter()`, `soul_meter_changed` |
| HUD | `ui/hud/soul_gauge.gd` — the FR-601 occluded-disc motif |
| Dialogue cost | `[#cost=-6 soul]` tags in `dialogue/*.dialogue` |
| Casting gate | `globals/elements/` composition resolver and casting gate |

### 4.3 The two hooks

**Combat.** A cast spends Gauge. When the player cannot pay, the refusal must name *Soul*.
FR-606 requires the refusal to identify the system that blocked the action. The message "you
cannot cast that" is the exact failure that FR-606 prevents. The existing refusal shape carries
the answer. Set `blocked_by = &"soul"`. Put the unblock condition in `nearest_unblock`.

**Narrative.** Dialogue conditions read the Gauge through Dialogue Manager. Use `[if …/]`. See
§3.5. Choices carry `[#cost=-6 soul]`.

Canon makes recovery social. The natural design therefore gates recovery behind narrative acts.
Examples are rest, ritual, and remembrance. Do not gate recovery behind a consumable.

`Renown` means "how well the world remembers you". `Renown` is therefore a canon-shaped
candidate to feed recovery. **This is a proposal. It is not adopted.** See §6, question 2.

### 4.4 The zero state — deliberately unbuilt

Canon defines a catastrophe at zero. The catastrophe is death, or husking-while-alive. The
codebase implements neither.

FR-905 constrains the design. FR-905 forbids soft-locks and requires failure-forward routes.
A Gauge of zero must therefore route to authored content. It must not route to a dead end.

This needs a design decision before any code. `CLAUDE.md` forbids a silent resolution. §6
records the question as open.

### 4.5 Definition of done

- [ ] A blocked cast reports `blocked_by = &"soul"` with a real `nearest_unblock`.
- [ ] Soul cost applies identically through dialogue and through combat. One code path. Tested.
- [ ] An authored event drives recovery. A passive tick never drives recovery. Canon: the
      Gauge is not a mana pool.
- [ ] The owner ratifies the zero-state design **before** implementation starts.
- [ ] The HUD shows occlusion (FR-601). The HUD encodes state without hue alone (FR-607).

---

## 5. Sequence of work

Amendment §8.1 stop-loss governs this sequence. The order is not a preference. The order is the
reversibility argument.

| Order | Work | Risk | Gate |
|---|---|---|---|
| 1 | `IsoGrid`, click-to-move, blocking layer (§2) | **Low** — new files, no combat dependency | None. It ships on its own value |
| 2 | Widen `BattlefieldModel` (§1.3) | **Low** — additive; the zone model is untouched | 305 tests pass, unmodified |
| 3 | `GridBattlefieldModel` behind `use_grid_battlefield = false` | **Low** — sibling; no controller change | Behavioural parity with the zone model |
| 4 | Flag grammar, audit, dialogue lint (§3) | **Low** — tooling | The audit passes on existing content |
| 5 | **GATE T** | — | Grid, elevation, and facing make encounters much harder or unwinnable without use of height or facing |
| 6 | Grid maps and encounter production | **High** — becomes sunk content | **Do not start before Gate T passes** (§8.1) |
| 7 | Soul zero state | Design-blocked | The owner ratifies §4.4 first |
| 8 | Day/night and hub NPC routines (D6) | Medium | **The FR-504 amendment must come first** |
| 9 | Region content into `world/locations/` | High | **Phase 1.5 comprehension gate** — 3 to 5 outside humans |

Steps 1 to 4 all carry low risk. Each one has independent value. **None of them needs Gate T.**

That is the practical result: approximately one milestone of de-risked work is available before
the first blocking gate.

---

## 6. Open questions

This document does not answer these questions.

| # | Question | Reason it stays open |
|---|---|---|
| 1 | **The Soul zero state** — death, husking-while-alive, or a costed non-game-over? | Canon-adjacent design. FR-905 constrains it. FR-905 does not decide it. The owner decides |
| 2 | **Does `Renown` feed Gauge recovery?** | Canon makes recovery social. A link from remembrance to `Renown` is an attractive reading. It is not ratified |
| 3 | **#132** — three combat disciplines against the Ten Patron Classes | Amendment §9.1 holds an advisory recommendation. Nothing in `globals/combat/` encodes a class, so no option has a head start in code |
| 4 | **FR-701** — which 4 to 5 vault peoples are playable | A canon-adjacent selection. Propose it, then ratify it |
| 5 | **FR-907** — the respec policy | A percentile system punishes an early mistake hard. Open since Phase 0 |
| 6 | **Gamepad at ship** | The one open human question in `docs/godot-architecture.md` |
| 7 | **The elevation authoring format** — TileMapLayer custom data or a separate height map | Decide when you build `elevation_map.gd`. Both are cheap to change before content exists |

---

## 7. Language rule for this document

This document uses ASD-STE100 (Simplified Technical English). The owner adopted the rule on
2026-08-07. The scope covers chat, repository documents, and GitHub issues.

**Game content is outside this scope.** Do not apply STE to `dialogue/*.dialogue`. Do not apply
STE to the Dramgid vault prose. Do not apply STE to any character speech. STE controls the
engineering documents. It does not control the fiction.

Two earlier documents predate this rule. `docs/prd-chapter-one.md` and
`docs/prd-amendment-tactical-layer.md` use a longer style. Do not convert them. They are
ratified. A rewrite of a ratified document risks a change in meaning.

---

## Appendix — provenance

The team verified each claim about the present code state against the working tree on
2026-08-07. No claim comes from documentation alone.

- `AStarGrid2D`, `NavigationServer2D`, and `NavigationAgent2D` occurrence counts: `rg` across
  `*.gd` and `*.tscn`, with `addons/` excluded — **zero for all three**
- `BattlefieldModel` consumer call sites: `rg -n '_battlefield|battlefield\.|BattlefieldModel'
  globals/combat/combat_controller.gd` — **14 sites**
- `GridBattlefieldModel` absence: `ls globals/combat/`
- Soul Meter bounds: `globals/game_state.gd:73` — `clampf(value, 0.0, 100.0)`
- Player movement: `actors/player/player.gd` — `Input.get_vector` then `move_and_slide`
- Soul Gauge canon: `dramgid-vault/cosmology/souls.md`, section "The Soul Gauge — the game's
  Soul Meter"
