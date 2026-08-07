# Research spike: the GodotGAS integration seam

**Closes #55.** Status: design proposal. **No GodotGAS code has been read**, because the package
is not obtainable in this environment.

Per the issue's validation gate, every claim below is tagged. Nothing about GodotGAS's actual API
is asserted as fact.

## Evidence ledger

**Verified in this repo (2026-08-06, `main` @ `36ba4ad`):**

- `globals/combat_action.gd` already declares the intent in its header: *"Data carried by the
  combat engine. GodotGAS can implement the effects behind this seam later without making battle
  flow depend on that addon."* The seam is a stated design position, not a new idea.
- `CombatAction` is a `Resource` with `Kind`/`Verb` enums and exported cost/effect fields
  (`ap_cost`, `ct_cost`, `power_bonus`, `balance_shift`, `soul_cost`, targeting fields).
- Effect resolution today lives in `globals/combat/combat_rules.gd`,
  `globals/combat/combat_controller.gd`, and `globals/elements/composition_resolver.gd`.
- `addons/` contains no GAS plugin. Nothing imports it. There is no partial integration to
  reconcile.

**Recorded in our own docs but NOT verified against the package** — these come from
`DEPENDENCIES.md` and `docs/godot-architecture.md`, which were written from a store listing and a
prior handoff, not from reading the source:

- ⚠️ *"abilities/attributes/effects/tags/stacking/durations"* — the claimed feature set.
- ⚠️ *"100% GDScript"* — claimed; matters because it decides whether GDExtension build steps
  enter CI.
- ⚠️ *"single-player-scoped today, networking is roadmap"* — the stated reason for wrapping it.
- ⚠️ *"No public repo; distributed via store.godotengine.org (login-walled)"* — the reason this
  spike cannot verify anything.

**Unknown — must be answered by reading the source once downloaded:**

- ❓ Every class, node, and resource name. This document deliberately invents none.
- ❓ Whether abilities are Nodes, Resources, or plain objects. This decides whether the adapter
  owns a subtree or just objects, and it is the single biggest unknown.
- ❓ Whether effect application is synchronous or deferred/signal-driven. Our combat resolution
  is synchronous and #142 ratifies resolution as a **pure function** — a deferred effect model
  would be a genuine architectural conflict, not an adapter detail.
- ❓ Whether it has its own serialization, and whether that survives our save schema.
- ❓ Whether it assumes `_process`/`_physics_process` ticking. Our combat is turn-based and moving
  to charge time (#138); a real-time-tick assumption would be a poor fit.
- ❓ Its license and redistribution terms.

## The proposed seam

The seam is **an interface we own**, in our vocabulary, with GodotGAS as one implementation
behind it. `CombatAction` stays the authored data; the addon never appears in battle flow.

```
CombatController / CombatRules
        │  (talks only to this)
        ▼
   AbilityRuntime            ← our interface, our vocabulary
        ├── InHouseAbilityRuntime   (today's CombatRules logic — the default)
        └── GasAbilityRuntime       (adapter; only file allowed to import the addon)
```

Proposed interface — deliberately small, phrased entirely in our own terms:

```gdscript
class_name AbilityRuntime
extends RefCounted
## The only surface combat code may use for ability/effect resolution.
## Implementations must be swappable without touching CombatController.

## Can this actor pay for and legally use this action right now?
func can_activate(actor: BattleActor, action: CombatAction, ctx: Dictionary) -> bool

## Resolve the action. MUST be pure: no mutation of actor/ctx, no side effects.
## Returns the outcome for the caller to apply. (FR: #142 resolution-as-pure-function.)
func resolve(actor: BattleActor, action: CombatAction, ctx: Dictionary) -> CombatEvent

## Durations/stacks tick on OUR schedule, driven by the turn scheduler — never by _process.
func advance(actor: BattleActor, ticks: int) -> Array[CombatEvent]
```

Three constraints are non-negotiable regardless of what the addon turns out to look like:

1. **Purity of `resolve()`.** #142 ratifies forecast, replay, and AI on one code path. If
   GodotGAS can only apply effects by mutating state, `GasAbilityRuntime` must resolve against a
   throwaway copy and report the delta — and if that proves impossible, the addon is the wrong
   fit and we keep the in-house runtime. This is the criterion that decides adoption.
2. **We own the clock.** Durations advance from `TurnScheduler`/`ChargeTimeScheduler`, never from
   engine frames.
3. **Pandora stays canonical.** Per `docs/godot-architecture.md`, spells are Pandora entities
   referencing GAS effect resources **by ID**, and the linkage is *generated* into
   `data/generated/`. GAS resources are generated artifacts, never hand-authored, same one-way
   rule as GLoot.

## Why a seam at all

Recorded reason: co-op is a live maybe, and GodotGAS is understood to be single-player-scoped.
`CLAUDE.md` already lists "wrap GAS behind a seam" as a decision on record.

The stronger reason is the one this spike surfaces: **we cannot evaluate the package before
committing to it.** A seam converts "adopt GodotGAS" from an irreversible bet into a reversible
experiment. Given that six substantive questions about it are unanswerable today, that is the
only responsible shape.

## Sequenced plan

**Now (no download needed).** Extract `AbilityRuntime` and move today's logic into
`InHouseAbilityRuntime` behind it. This is pure refactoring, is independently valuable, is
testable against the existing suite, and is **not blocked on the store download**. It should not
wait for GodotGAS.

**On download (human, Windows machine).** Read the source first — `DEPENDENCIES.md` says so
twice. Answer the six ❓ questions, especially the purity one, and write the answers back into
this document, replacing the ledger above.

**Then decide.** Adopt only if `resolve()` can be made pure and the clock can be ours. Otherwise
close it out: the in-house runtime already works, and the seam will have paid for itself by
making that a shrug instead of a rewrite.

## Effort note

Do not gate combat work on this. The Phase 2 combat vertical, the CT migration (#138), and the
tactical layer T1 issues all proceed on the in-house path. GodotGAS is an optimization on
implementation effort, not a prerequisite for anything ratified.
