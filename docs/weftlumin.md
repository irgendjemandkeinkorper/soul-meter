# Weftlumin in-game editor — debug tools

Weftlumin is the debug-build-only in-game editor shell (`addons/weftlumin`, architecture in
`docs/architecture-in-game-editor.md`). Since E2.5b (#337) it is the **only** host for the five
former debug tools: the state console, the consequence timeline, Combat Lab, Dialogue Lab and the
quest editor. This page replaces the five per-tool documents (`dev-console.md`,
`consequence-timeline.md`, `combat-lab.md`, `dialogue-lab.md`, `quest-editor.md`); their rules are
carried over below, restated for the panel host.

## Status

| Tool | Panel (dock slot) | Model (`weftlumin/panels/models/`) | Retired legacy surface |
| --- | --- | --- | --- |
| State console | `console_panel.gd` (Console) | `dev_console.gd` | `DevConsole` autoload, F1 overlay, `SOUL_METER_DEV_CONSOLE` |
| Consequence timeline | `timeline_panel.gd` (Consequence timeline) | `consequence_timeline.gd` | `ConsequenceTimeline` autoload, F4 overlay, `SOUL_METER_CONSEQUENCE_TIMELINE` |
| Combat Lab | `combat_lab_panel.gd` (Combat lab) | `combat_lab.gd` | `CombatLab` autoload, F3 overlay, `SOUL_METER_COMBAT_LAB` |
| Dialogue Lab | `dialogue_panel.gd` (Dialogue lab) | `dialogue_lab.gd` | `DialogueLab` autoload, F5 overlay, `SOUL_METER_DIALOGUE_LAB` |
| Quest editor | `quest_panel.gd` (Quest editor) | `quest_editor.gd` | `QuestEditor` autoload, F6 overlay, `SOUL_METER_QUEST_EDITOR` |
| Layout mode | not yet a panel | `globals/layout_mode.gd` (unchanged) | **kept** — see below |

**Layout mode is deliberately kept.** The Weftlumin scene panel cannot yet pick or drag nodes in
the viewport, so `LayoutMode` (its autoload, `ui/debug/layout_editor*`, its tests and
`docs/layout-mode.md`) stays as-is until that port lands in **#470**.

## Enablement and release safety

Open Weftlumin with **F12** (the remappable `weftlumin_toggle` action) in a debug build started
with `SOUL_METER_WEFTLUMIN=1`. The shell owns activation, key bindings and pause; no tool listens for
its old F-key or environment variable any more.

Each panel creates **one private instance** of its model as a child (`SoulMeterToolPanel.configure()`)
and enables it through the model's `host_in_panel()` seam. A model that no panel hosts is inert: no
children, no signal connections, no input processing, no files, and every mutating entry point
refuses. `host_in_panel()` refuses in release builds (`OS.is_debug_build()` is load-bearing and must
never be weakened), outside the scene tree, and — for the two sandbox tools — without the shell's
sandbox owner token.

Release builds contain none of this code. `weftlumin/panels/*` (panels and models) is in every
preset's `exclude_filter` in `export_presets.cfg`, the five autoload entries are gone from
`project.godot`, and no shipped script references a model. The `*_inert` suites under
`test/integration/` pin exactly that (via `test/helpers/weftlumin_tool_release.gd`), alongside the
bootstrap's own `test_weftlumin_inert.gd`. Never ship a Gate T playtest artifact with tool access:
such a session is invalid evidence.

The shell's production-owner predicate (`production_owner_live()` in
`addons/weftlumin/shell/soul_meter_adapter.gd`) treats a live
`Battle` session or any Dialogue Manager balloon under the current scene as production content; the
sandbox tools refuse to start over it.

## State console

The console reaches authored mid-chapter states without replaying the chapter. Enter a command and
submit it; `Up`/`Down` navigate history. Bad arguments and unknown commands produce `ERROR:` log
lines instead of engine errors.

| Command | Public implementation path | Result |
| --- | --- | --- |
| `flag <name> [true\|false]` | `GameState.set_flag()` / `get_flag()` | Sets a flag; omitted value means `true`. |
| `flags [filter]` | `GameState.flags` names plus `GameState.get_flag()` | Lists flags, optionally filtered by case-insensitive substring. |
| `soul <value>` | `GameState.set_soul_meter()` | Sets the Soul Meter through its normal clamping and husking rules. |
| `gp <value>` | `GameState.set_gp()` | Sets GP through its normal non-negative clamp. |
| `rep <faction> <delta>` | Generated `FactionIds` catalog, then `Reputation.record()` | Appends a tagged faction-consequence event. |
| `standing <faction>` | `Reputation.standing()` / `band()` | Shows the derived standing and band. |
| `why <faction>` | `Reputation.why()` | Shows the newest recorded faction reasons. |
| `renown <delta>` / `infamy <delta>` | `Renown.gain_reputation()` / `gain_infamy()` | Appends a tagged Renown or Infamy event. |
| `why renown` / `why infamy` | `Renown.why()` | Shows the newest reasons for that ledger. |
| `item <item_id> [count]` | Generated `ItemIds` catalog, then `GameState.inventory.create_and_add_item()` | Adds valid item prototypes; count defaults to one. |
| `treat <member_id> <location> [service-test\|field-test] [practitioner_id]` | Treatment coordinator | Drives treatment through its public path and refuses cleanly. |
| `quest offer <quest_id>` | Runtime-aware `QuestRegistry` catalog, then `QuestRegistry.offer()` | Offers and starts the quest; refuses a completed quest. |
| `quest complete <quest_id>` | Not available | Returns an error and changes no quest state (see below). |
| `phase <morning\|afternoon\|evening\|night>` / `phase next` | `WorldClock.set_phase()` / `advance()` | Sets or advances the phase. |
| `goto <scene-or-hub-id>` | `LocationRegistry`, then `GameFlow.travel()` | Requests legal travel; never `change_scene_to_file()`. |
| `help` | Console read path | Lists commands. |

`quest complete` stays refused: `QuestRegistry.debug_force_complete(quest)` accepts no cause, and
some resolvers append ledger events, so debug evidence would be indistinguishable from play.

**Tagged provenance.** Every console-originated ledger write passes a cause beginning with the
model's exported `DEBUG_CAUSE_PREFIX` (`[debug] `); `is_debug_caused(cause)` is the canonical test.
Never add an untagged or post-hoc mutation path.

**Session hygiene.** The first command of each hosted session sets the durable, write-once
`dev_console_used` flag (not settable from the console). The model keeps a session command audit.
When `PlaytestRecorder` is active, each command appends one `dev_console_command` event.

## Consequence timeline

A read-only observer of both append-only ledgers (`Reputation` per-faction, `Renown`
reputation/infamy). It never calls a ledger mutator or `from_dict()`; it connects only
`reputation_changed`, `renown_changed` and `SaveGame.load_requested` (a load replaces both ledgers
without a change signal, so it resynchronises from history).

Live rows are newest-first by the observer's private arrival counter, never written to a ledger.
History that predates the observer is backfilled per ledger in that ledger's own `order` and labelled
`RESTORED HISTORY / CROSS-LEDGER ORDER APPROXIMATE`. Each row shows timestamp, ledger, faction or kind,
signed delta, resulting value, cause, actor and scene; causes with the console's `DEBUG_CAUSE_PREFIX`
are flagged `DEBUG-INJECTED`. At most `MAX_RETAINED_ROWS` (200) rows are kept.

## Combat Lab

An encounter sandbox for provisional combat balance in the running game. The panel needs the shell
sandbox: the shell arms the shared `WeftluminSandbox` under the panel's token and the lab's sessions
restart under that same token.

- **Setup.** Encounters come from `EncounterCatalog` (including registered campaign encounters).
  Party choices combine the current party and recruitable candidates, capped at
  `GameState.REQUIRED_COMPANIONS + 1`. Weather starts from the location's authored default (or
  `CALM`) and is labelled as authored, absent or overridden. A tile seed sets cell, element and charge
  on the runtime `TileState`. Called-shot anatomy and visibility fixtures are lab-only.
- **Production path.** `Battle.start(encounter_id)` then `GameFlow.send_event("enter_battle")`; the
  lab never changes scenes or substitutes a controller.
- **Inspector feed.** The model emits `inspector_changed(payload)` from `Battle.combat_event`,
  `turn_resolved`, `balance_changed` and `battle_ended` (no polling): scheduler order and READY_AT,
  the pending forecast, matching resolution, Balance, weather, tiles, style points, turns and outcome.
- **Forecast equals resolution** (#209). The lab compares the controller's own forecast with the
  later `action_resolved` damage for the same target and labels any mismatch
  **FORECAST / RESOLUTION DIVERGENCE** — a combat correctness defect, never display variance.
- **Seeds.** The seed drives `SkillCheck`'s RNG only; combat damage is deterministic per controller
  sequence, so "new seed" re-rolls skill checks and leaves damage identical by design.
- **Containment.** Every session arms the shared sandbox over everything
  `SaveGame.capture_runtime_state()` covers (enumerated once, in `SaveGame`), plus the RNG position;
  autosaves are refused at staging while armed. Restarts restore-then-capture as a pair.
- **Ownership.** Every start and restart refuses over a production battle or another tool's armed
  sandbox; the panel shows `REFUSAL_WARNING`.
- **Export.** `user://combat_lab/<timestamp>.md` with setup, a forecast/resolution parity table,
  outcome and, for weather overrides, an authoring candidate for a human to apply. The lab has no
  write path to catalogs, the element matrix, Pandora or generated data.
- **Recorder.** Each lab battle appends one `combat_lab_battle_started` event.

## Dialogue Lab

A read-only play-edit-reload loop for `.dialogue` resources under `dialogue/` and
`dialogue/companions/`.

1. Pick a resource and one of its titles (read from the imported `DialogueResource`).
2. Optionally seed replay-only flags, faction standings and Renown targets.
3. Play. Dialogue launches through `DialogueManager.show_dialogue_balloon()`, the production path.
4. Edit the file externally, then **Reload from disk + replay** (`CACHE_MODE_IGNORE`), or
   **Replay same state**.
5. **End session**, or leave the tab, to restore.

**Containment** is the same shared sandbox as Combat Lab: every session begins armed, seeded state is
applied after capture, a session restores exactly once and then disarms, and autosaves cannot be
staged while armed. **Ownership:** every replay entry point (`start_replay`, `start_test_session`,
`replay_same_state`, `reload_and_replay`) refuses over a production battle, a production dialogue
balloon, or another tool's armed sandbox; the panel shows `REFUSAL_WARNING`. The lab never writes
dialogue text and has no export path.

## Quest editor

Authors runtime campaign packages in the exact format `CampaignQuestLoader` consumes. The panel edits
`campaign.json` and the quest documents as JSON; validation, transactional writes, reload and
registration are the model's.

- **Validate** uses `CampaignQuestLoader.validate_package_data()` — the single rule implementation —
  and lists errors with `file`, `field`, `expected` and `message`.
- **Save** stages every document as a `.tmp` sibling, protects the previous files as `.bak`, then
  promotes the complete set; failures roll back. It writes only
  `user://campaigns/<campaign_id>/campaign.json` and `quests/<quest_id>.json`; existing package
  `dialogue/` and `encounters/` files are preserved byte-for-byte. It never writes `res://`, committed
  sources, Pandora or the vault; promotion to canon is `tools/bake_campaign.gd`'s job.
- **Registration** happens only after a zero-error loader round trip, and replaces the runtime set.
  If a registered runtime quest has live progress, save/reload refuse to register, name every
  affected quest, and offer **Authorize reset of listed live quests**, which authorises exactly those
  identities (a newly conflicting identity refuses again).
- The editor never offers, resolves or advances quests and never opens a save sandbox.
- **Package rules** (portable quest-id paths, case-folded uniqueness, discovery depth and link
  limits, campaign encounters, campaign dialogue compiled with `DMCompiler`, campaign-first title
  resolution) are owned by `CampaignQuestLoader`; campaign encounters are reachable from campaign
  dialogue `do Battle.start(...)` and from the Combat Lab panel.
- **Limits:** package containment is lexical (symlinked roots are out of scope), runtime dialogue is
  not sandboxed, and save is rollback-capable but not crash-atomic.

## Tests

| Coverage | Suites |
| --- | --- |
| Release build carries no tool code; unhosted models are inert | `test/integration/test_{dev_console,consequence_timeline,combat_lab,dialogue_lab,quest_editor}_inert.gd`, `test_weftlumin_inert.gd` |
| Model behaviour | `test/unit/test_{dev_console_commands,consequence_timeline,combat_lab,dialogue_lab,quest_editor,campaign_encounters,campaign_quest_registry}.gd` |
| Panels in the shell | `test/integration/test_weftlumin_panels.gd`, `test_weftlumin_shell.gd` |

The original file-to-behaviour migration plan is `docs/weftlumin-test-migration.md` (E1.9).
