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
| Tests | `test/unit/test_class_resource.gd`, v2: `test/unit/test_class_resource_seam_v2.gd` |

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
`caster_context.*`, `unit.attack_scale`, `unit.harmony`, plus the v2 terms below
(`reveal`, `hidden_draw`, `fizzle_percent_override`). Overrides are applied with
`CombatController.deep_merge()` — a **key-level** merge: `{"unit": {"attack_scale": 1.25}}`
changes only `unit.attack_scale` and keeps `unit.id`/`edge`/`breath`; `{"fizzle": {"mastery":
true}}` keeps `fizzle.patron`/`pitch`. Anything else is a Resolution change, which is out of a
B-wave worker's scope: file a finding.

## v2 channels (seam follow-up, 2026-09-02)

The B1–B10 first passes documented five contract gaps. Seam v2 closes them; every existing hook
and signature is unchanged, so a v1 subclass loads as-is.

| Channel | API | Fires / applies | For |
|---|---|---|---|
| Broadcast | `on_any_action(actor_id, action_id, target_id, outcome)` | `_emit_event()` for EVERY `action_resolved`, on EVERY actor's resource, after the owner's `on_action`. `outcome` is the same dict `on_action` sees (`resolution`, `verb`, `damage`, …) | Threads (B10) |
| Deferred execution | `enqueue_deferred(effect, due, label)` → `CombatController.enqueue_deferred(entry)`; `on_deferred_fired(entry)` | `_drive_scheduler()` → `_fire_due_deferred()` right after `scheduler.advance()`, before the turn is handed out. Due = `due_tick`/`delay_ticks` (charge-time clock) or `due_round`/`delay_rounds` (AP). Writes are materialized from live state (`_materialize_write`) and applied by `_apply_resolution_writes()` — the same path Resolution writes take. Fires even if the source is down. `snapshot().deferred` lists what is pending; events `deferred_queued` / `deferred_effect_fired` | Oathclock Ledger (B7), Hunger DoT ticks (B4) |
| Cancellation | `request_cancel(target_id, kind)` → `CombatController.request_cancel(requester, target, kind)`; `on_deferred_cancelled(entry, by_id)` | `kind` &"deferred" removes the target's queued entries; &"committed" voids its committed-but-unresolved scheduler action (a charging Song under charge time, `scheduler.cancel_committed(target, false)`); &"any" both. Emits `action_cancelled`; refuses `nothing_to_cancel` when nothing was in flight | Jam the Gears (B8) |
| Reveal | `on_cast_forecast` → `{"reveal": true}` | `forecast_context()` always carries `reveal` (default false). `Resolution.resolve()` echoes it as `result.reveal` and, when true, adds `result.revealed` = `{fizzle_percent, target_element, relation, attunements, hidden_draw_row_id}`. The forecast panel appends `· TRUE` and un-hides hidden draws. The A5 Triad **Dayspring** sets the SAME flag from its round-scoped `revealed_until_round`; there is one mechanism | Clarity (B6), Dayspring |
| Hidden draw | `on_cast_forecast` → `{"hidden_draw": {"table_id", "seed_key", "rows": [{"id", "bonus_damage", …}]}}` | `Resolution.resolve()` draws a row with `_deterministic_draw_roll()` (fizzle-roll key space + `seed_key`), adds `bonus_damage` as a breakdown step, reports `result.hidden_draw` = `{table_id, seed_key, roll, row_id, row}`. No draw on a fizzle or a miss. The panel shows `?` for damage unless `reveal` is set; forecast == resolution regardless | Attribution (B9) |

Write kinds added for the refund classes (applied in `_apply_resolution_writes()`, also valid
inside a deferred effect):

| Kind | Fields | Effect |
|---|---|---|
| `dot` | `target_id`, `amount` (HP lost) | HP loss whose kill cause is `&"dot"` (on_kill receives `&"dot"`; `on_damage_taken` fires as usual) |
| `soul_refund` | `target_id`, `amount` | Adds `amount` to the live Soul meter (`GameState.set_soul_meter`). The only Soul income channel a resource has |

Notes for B9/B11 and the refund classes:

- The hidden-draw row pick is an **unweighted modulo** over `rows` (`(roll - 1) % rows.size()`).
  B11 must not assume per-row weights; to weight a row, repeat it in the table.
- `soul_refund` is **live `GameState` income** — it lands on the real Soul meter the moment the
  write applies, unlike Breath, which is copied into the battle and written back by
  `Battle._finish()`. A refund that fires in a lost battle has still happened.
- The deferred queue is saved inside the `class_resources` dict under
  `CombatController.DEFERRED_SAVE_KEY` (only when non-empty); older saves restore an empty queue.
- Hook ordering: the parent `action_resolved` event is delivered to listeners BEFORE
  `on_action`/`on_any_action` run, so a child event a hook emits (`deferred_queued`,
  `action_cancelled`) always carries a higher sequence than its parent.
- `request_cancel(&"committed")` on the actor whose action is being resolved is refused with
  `resolving`; retry from `on_turn_start` or a later event.

Forecast term added: `fizzle_percent_override` (0–100) pins the fizzle chance for that cast;
`result.fizzle_overridden` is true when it was applied. `0` = a guaranteed cast (Instructive
Failure, B2).

### Which channel each class uses

| Class | Channel(s) |
|---|---|
| B1 Mirrorblade Balance | `on_action` + `on_cast_forecast` (`unit.attack_scale`, `fizzle.agreement_integrity`) — key-level merge now keeps the rest of `unit`/`fizzle` |
| B2 Flamebinder Instructive Failure | `on_fizzle` banks; `on_cast_forecast` → `fizzle_percent_override: 0` while armed; consume in `on_action` |
| B3 Ironbrand Scars | unchanged (`to_hit_enabled`); crit still has no channel |
| B4 Husk-bearer Hunger | enqueue a `dot` write per stack (`delay_rounds: 1`, re-queue from `on_deferred_fired`); `on_kill` with cause `&"dot"` → enqueue/apply `soul_refund` |
| B5 River-Mother Name-Ledger | `soul_refund` write from the record action; `on_any_action` to watch the named ally |
| B6 Lensbearer Clarity | `reveal: true` while armed |
| B7 Oathclock Ledger | `enqueue_deferred()` on file, `on_deferred_fired()` to bookkeep, `snapshot().deferred` for the plate |
| B8 Locksmirk Jam the Gears | `request_cancel(target, &"any")`; the fizzle floor stays in `SkillCheckService` |
| B9 Stormbearer Attribution | `hidden_draw` with B11's table; `on_action` reads `resolution.hidden_draw.row_id` |
| B10 Threadwalker Threads | `on_any_action` to evaluate the contract; payoff via `enqueue_deferred()` or a direct write from `on_any_action` through `enqueue_deferred({"delay_rounds": 0})` |

## Adding a class (B1–B10 recipe)

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
- Anything requiring a new Resolution term or write kind beyond the v2 set → finding, not a change.
- Which patron a companion has → `PartyMember.patron` is content, not code.
- Guaranteed-crit: Resolution has no crit channel; Scars ships guaranteed-hit only until one
  is ratified.
