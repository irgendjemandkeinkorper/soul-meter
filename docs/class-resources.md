# Class resources — the seam for the ten patron-class signature resources

Roadmap Wave B (`docs/fleet-roadmap.md`), seam issue #223. Canon source:
`dramgid-vault/systems/magic-system.md` §Per-class resources; in-fiction proposals per class
in `dramgid-vault/proposals/class-resources/` (owner approval pending).

## Where it lives

| Piece | Path |
|---|---|
| Base class + hook contract | `globals/combat/class_resources/class_resource.gd` |
| No-op for classless actors | `globals/combat/class_resources/null_class_resource.gd` |
| Patron id → resource factory | `globals/combat/class_resources/class_resource_registry.gd` |
| Worked example (Kero) | `globals/combat/class_resources/ironbrand_scars.gd` |
| Attachment point | `CombatController.start()` → `_attach_class_resources()` |
| Per-actor slot | `BattleActor.class_resource` (runtime only, never exported) |
| HUD view | `CombatController.snapshot()` → each actor's `class_resource` dict |
| Save | additive `class_resources` key (no schema bump) — see below |
| Tests | `test/unit/test_class_resource.gd` |

Attachment reads `BattleActor.source_member.patron` (the `PartyMember` display form, e.g.
`"Kero"`, `"Ofshütje"`) and folds it through `ClassResourceRegistry.normalize_patron()` to the
vault's kebab id. Enemies and ad-hoc actors have no `source_member` and get
`NullClassResource`. An actor whose `class_resource` is already non-null when the battle starts
keeps it (that is how tests inject spies and how a save restores state).

## The hook contract

Every hook is dispatched by `CombatController` at an existing commit point. Resources never
subscribe to events themselves and presentation never calls them.

| Hook | Fires from | Receives |
|---|---|---|
| `on_turn_start()` | `_drive_scheduler()` when a `turn_started` beat is emitted for the owner (allies), or when an enemy actor's turn begins; NOT on AP continuations of the same turn | — |
| `on_action(event)` | `_emit_event()` for every `action_resolved` whose actor is the owner | the `CombatEvent` (`data` = outcome dict: `action_id`, `verb`, `resolution`, `damage`, …) |
| `on_damage_taken(amount, source_id)` | `_apply_resolution_writes()` when an `hp` write lowers the owner's HP | HP lost (> 0), attacker's combat id |
| `on_kill(target_id, cause)` | same place, when the owner's `hp` write takes a target from alive to 0 | victim combat id; `&"attack"`, `&"cast"` or `&"defining_strike"` |
| `on_fizzle(resolution)` | `_resolve_attack()` after a CAST resolution with `fizzled == true` is applied | the committed Resolution dict |
| `on_cast_forecast(context) -> Dictionary` | `forecast_context()` — the ONE function both `forecast_action()` and the commit path use | a copy of the context about to go to `Resolution.resolve()`; returns overrides merged on top |

`on_cast_forecast` is the only way a resource changes an outcome, and it is called with identical
input at forecast and at commit. That is what keeps forecast == resolution: a resource cannot
compute damage, it can only adjust the context that Resolution computes from. Because it runs
twice per action, it must be pure with respect to its own state — consume one-shot flags in
`on_action`, never here. Scars shows the pattern: `spend_scar()` arms a window,
`on_cast_forecast` returns `{"to_hit_enabled": false}` while armed, `on_action` disarms once a
resolution has actually happened.

Context keys a resource may override today (all already honoured by `Resolution.resolve()`):
`to_hit_enabled`, `fizzle.*` (`agreement_integrity`, `pitch`, `mastery`, `patron`),
`caster_context.*`, `unit.attack_scale`, `unit.harmony`. Anything else is a Resolution change,
which is out of a B-wave worker's scope: file a finding.

## Adding a class (B1–B10 recipe)

| Issue | Patron | Resource | Current status |
|---|---|---|---|
| B6 | Stuid | Clarity | State-only until seam v2 |
| B7 | Pazzah | Oathclock Ledger | State-only until seam v2 |
| B8 | Fickah | Locksmirk Jam | State-only until seam v2 |
| B9 | Ofshütje | Stormbearer Attribution | State-only until seam v2 |
| B10 | Izhakel | Threadwalker Threads | State-only until seam v2 |

These five resources intentionally use only the existing seam. Deferred execution, cancellation
hooks, all-actor `on_any_action` broadcast, reveal delivery, and hidden effect draws remain
state-only until seam v2.

1. `globals/combat/class_resources/<patron>_<resource>.gd`, `class_name <PascalCase>`,
   `extends ClassResource`. Header comment quotes the vault table row. Override only the hooks
   you use. Keep every number as a `const` marked `PROVISIONAL` (B11 owns tuning).
2. One line in `ClassResourceRegistry._FACTORIES`: `&"<patron>": preload("res://…/your.gd")`.
3. `snapshot()` returns `{patron_id, label, value, max, …}` — the unit plate reads `label`/`value`
   (`ui/hud/regions/unit_plate/`); add a readout there if the existing generic one is not
   enough. `to_dict()`/`from_dict()` call `super` and add your fields.
4. If the resource needs a player command (spend, file, bind…), author a `CombatAction` `.tres`
   under `data/combat/actions/` (B13 batch) and gate it in `Battle.action_refusal()` on the
   resource state — do not add a new `CombatAction.Kind`.
5. Tests in `test/unit/`: registry lookup, each hook you use (drive a 2-cell grid battle like
   `test_class_resource.gd::_battle()`), save round-trip. Static typing; never `:=` from a
   Variant-returning call.
6. Re-import after adding the `class_name` script.

## Save

`SaveGame` writes `class_resources` (`Battle.class_resources_to_dict()`, keyed by combat id,
Null resources omitted) beside the other runtime sections and reads it back with
`Battle.restore_class_resources()`. Outside a live battle it is `{}`; the loader defaults `{}`.
A restore that arrives before a controller exists is held in `Battle._pending_class_resources`
and applied by the next `Battle.start()`. Mid-battle save is not a Chapter 1 behaviour, so this
is model-level round-trip only.

## Do not decide (B-wave workers)

- Numbers: caps, refund sizes, floors, variance tables → B11.
- Anything requiring a new Resolution term or write kind → finding, not a change.
- Which patron a companion has → `PartyMember.patron` is content, not code.
- Guaranteed-crit: Resolution has no crit channel; Scars ships guaranteed-hit only until one
  is ratified.
