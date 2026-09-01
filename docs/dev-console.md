# Developer state console

The developer state console is a debug-build-only tool for reaching authored mid-chapter states without replaying the chapter. Press `F1` to open or close it. Opening the console pauses the scene tree; closing it restores the exact pause state that existed before it opened. The `F1` binding is a provisional owner surface.

## Enablement and artifact safety

The console activates only when both conditions are true:

1. `OS.is_debug_build()` is true.
2. `SOUL_METER_DEV_CONSOLE=1` is present in the environment.

For automated tests, `force_enabled_for_tests` replaces the environment opt-in but does not bypass the debug-build requirement. When activation is false, the `DevConsole` autoload has no children, makes no signal connections, and does not process input.

Never set `SOUL_METER_DEV_CONSOLE` when exporting or running a Gate T playtest artifact. More importantly, the `OS.is_debug_build()` gate is load-bearing and must never be removed or weakened: an exported playtest session with state-console access is invalid evidence.

## Interaction

Enter a command and press `Enter`. `Up` and `Down` navigate command history. The overlay also has buttons for `help`, `flags`, `phase next`, and `clear`. Commands and their results appear in the console log; bad arguments and unknown commands appear as `ERROR:` lines in red instead of raising engine errors.

## Commands

| Command | Public implementation path | Result |
| --- | --- | --- |
| `flag <name> [true\|false]` | `GameState.set_flag()` / `get_flag()` | Sets a flag; omitted value means `true`. |
| `flags [filter]` | `GameState.flags` names plus `GameState.get_flag()` | Lists flags, optionally filtered by case-insensitive substring. |
| `soul <value>` | `GameState.set_soul_meter()` | Sets the Soul Meter through its normal clamping and husking rules. |
| `gp <value>` | `GameState.set_gp()` | Sets GP through its normal non-negative clamp. |
| `rep <faction> <delta>` | Generated `FactionIds` catalog, then `Reputation.record()` | Appends a tagged faction-consequence event. |
| `standing <faction>` | `Reputation.standing()` / `band()` | Shows the derived standing and band. |
| `why <faction>` | `Reputation.why()` | Shows the newest recorded faction reasons. |
| `renown <delta>` | `Renown.gain_reputation()` | Appends a tagged Renown event. |
| `infamy <delta>` | `Renown.gain_infamy()` | Appends a tagged Infamy event. |
| `why renown` / `why infamy` | `Renown.why()` | Shows the newest reasons for that ledger. |
| `item <item_id> [count]` | Generated `ItemIds` catalog, then `GameState.inventory.create_and_add_item()` | Adds one or more valid item prototypes. Count defaults to one. |
| `quest offer <quest_id>` | Public `QuestRegistry.ALL_QUESTS` ID catalog, then `QuestRegistry.offer()` | Offers and starts the numeric quest ID through the quest system. |
| `quest complete <quest_id>` | Not currently available; see below. | Returns a red error and changes no quest state. |
| `phase <morning\|afternoon\|evening\|night>` | `WorldClock.set_phase()` | Sets a valid authored phase. |
| `phase next` | `WorldClock.advance()` | Advances one phase, including night-to-morning wrap. |
| `goto <scene-or-hub-id>` | `LocationRegistry.by_id()` / `by_scene()`, then `GameFlow.travel()` | Requests legal gameplay travel. It never calls `change_scene_to_file()`. |
| `help` | Console read path | Lists command names. |
| `clear` | Console log only | Clears visible output while retaining command history and the session command audit. |

`quest complete` cannot currently be implemented without violating the provenance rule. The required public completion path, `QuestRegistry.debug_force_complete(quest)`, does not accept a cause or provenance argument and some quest resolvers append Reputation or Renown events. Calling it from the console would therefore make debug-created evidence indistinguishable from gameplay-created evidence. The console refuses the operation instead of reaching into private ledger or quest state.

## Tagged consequence provenance

Reputation and Renown are append-only consequence ledgers used as player-facing evidence. Every console-originated direct ledger write passes a cause beginning with the exported `DevConsole.DEBUG_CAUSE_PREFIX`, whose value is `[debug] `. `DevConsole.is_debug_caused(cause)` is the canonical test for that tag.

For example, `rep ironbrand-sentinels 5` records a cause shaped like `[debug] console rep ironbrand-sentinels +5.0`. The prefix is deliberately visible and serialized. Do not add an untagged, hidden, or post-hoc mutation path: the cause must be supplied to the public ledger write itself.

## Session hygiene and recorder interop

The first non-empty command of each enabled console session calls `GameState.set_flag("dev_console_used", true)`. This durable flag makes any save touched by the console self-identifying. The console keeps both visible output and a session command audit; `clear` does not erase history or that audit.

When the `PlaytestRecorder` autoload is present and active, each command also calls its public `append_event()` API with one `dev_console_command` event containing the command text. An absent or inert recorder is safe: the console uses a null/method guard, and the recorder rejects appends while disabled.
