# GameState and Battle decomposition scope

This is a scoping note, not an immediate refactor. It records seams to evaluate before the
next feature batch adds more responsibility to either autoload.

## GameState candidate seams

`globals/game_state.gd` currently combines core flags and party state with inventory, persisted
settings, and audio-bus setup. A future split could keep a small `GameState` facade for flags,
party, and serialization while extracting:

- an inventory adapter that owns GLoot setup, item creation, and inventory round-trips;
- a settings service that owns persisted display/audio/input values; and
- an audio service that owns bus creation and volume/mute updates.

The facade must remain the single compatibility seam for existing callers until each consumer
has migrated. The main blocker is autoload coupling: `SaveGame`, UI screens, dialogue mutations,
and tests currently reach directly into `GameState`, so an eager extraction would create a broad
signal/API migration rather than a local refactor.

## Battle candidate seams

`globals/battle.gd` combines turn sequencing, actor/result calculation, encounter setup, and
signals consumed by the battle screen. `BattleActor` and `BattleResult` already provide a useful
calculation seam; the next split could extract:

- a resolver for attack/defense math, damage, death, and victory results; and
- a battle-session coordinator for turns, encounter state, reputation writes, and emitted
  presentation events.

The UI should continue consuming result/reporting data rather than owning resolution. The hard
blocker is signal and autoload compatibility: `ui/screens/battle.gd`, `GameState`, and the
existing tests depend on the current `Battle` instance and event ordering. Issue #48 should not
silently introduce collision identity or a new combat framework while this boundary is unsettled.

## Sequencing

Treat this document as input to a separate refactor issue. Land feature work through the current
public seams first, then migrate one seam at a time with characterization tests before deleting
the old facade methods.
