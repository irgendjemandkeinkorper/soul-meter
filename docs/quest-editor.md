# In-game quest editor

The quest editor authors campaign quest packages from inside a debug build. Its output is the same runtime package format loaded by `CampaignQuestLoader`, so a saved quest can be loaded and played without rebuilding the project.

## Enable and open

Start a debug build with:

```bash
SOUL_METER_QUEST_EDITOR=1 godot --path .
```

Press **F6** to open or close the overlay. The editor is enabled only when both `OS.is_debug_build()` is true and `SOUL_METER_QUEST_EDITOR` equals `1`. When disabled, the autoload has no children, signal connections, input handling, or writable public entry points.

## Authoring workflow

1. Pick an existing campaign package or choose **New Campaign**.
2. Enter the campaign id, title, and entry location. Existing manifests keep their additional ordered `locations`; a newly selected entry is added to that list.
3. Add, select, edit, or remove quest drafts in the package list.
4. Edit each outcome as one object containing its id, label, faction, reputation delta, cause, and readback. A new quest starts with two outcome objects. The overlay keeps the loader-owned runtime minimum visible but permits removing rows below it so normal attributed validation can explain the violation.
5. Choose **Validate with Loader**. Errors are shown both in the validation list and beside the attributed field, using the loader's `file`, `field`, `expected`, and `message` values.
6. Choose **Save + Reload + Register**. A success message appears only after the written package has made a round trip through `CampaignQuestLoader` with zero errors and the editor has passed the complete validated set to `QuestRegistry.register_runtime_quests()`.

Removing a quest removes it from the draft first. Saving stages every serialized document as a sibling `.tmp` file. Only after every staged write succeeds does the editor protect the previous JSON files as last-known-good `.bak` siblings and promote the complete new set. Failed writes or promotions clean up staged files and restore the previous package; stale quest removal is part of the same checked transaction. `written_files` always describes the JSON package that is actually on disk after the call.

Registration replaces the currently registered runtime quest set. If any currently registered runtime quest is active or completed, save and reload refuse to register by default and name every quest whose live progress would be reset. The overlay then exposes a labelled **Confirm Reset + Register** control. That confirmation authorizes only the displayed stable quest identities. The editor recomputes conflicts before registering; an unchanged or smaller set may proceed, while a newly conflicting identity causes another refusal that displays the complete new set for fresh confirmation. Saving may already have completed on disk when registration is refused, and the status message says so.

## Output boundary

The editor writes only beneath:

```text
user://campaigns/<campaign_id>/campaign.json
user://campaigns/<campaign_id>/quests/<quest_id>.json
```

It never writes `res://`, dialogue sources, committed quest sources, Pandora data, the Dramgid vault, or any other canon surface. Promotion into canon remains the responsibility of `tools/bake_campaign.gd`.

Campaign quest ids may use `/` to create nested paths such as `quests/side/baked-quest.json`. The path derived from an id must be portable and remain inside the campaign package: the id may not start with `/`; every `/`-separated segment must be non-empty, may not equal `.` or `..`, and may not end in a period or a space (Windows strips those from a path component, so `side.` and `side` would name the same directory there while staying distinct ids here); `:` and backslashes are forbidden; and no segment stem may be a case-insensitive Windows device name (`CON`, `PRN`, `AUX`, `NUL`, `COM1`–`COM9`, or `LPT1`–`LPT9`), with or without an extension. Substrings such as `a..b` remain legal when they satisfy `StableIds.QUEST`. Within one package, quest ids must also be unique under ASCII case folding so two documents cannot name the same path on a case-insensitive filesystem. `CampaignQuestLoader` enforces all of these rules for both disk loading and editor validation.

## Validation and runtime state

`CampaignQuestLoader.validate_package_data()` is the single in-memory validation entry point used by the editor. Disk package loading and editor validation share the loader's campaign, quest, identity, collision, and outcome validation implementation; the UI contains no second quest-rule implementation.

The game loader remains tolerant: `load_package()` may return valid quests alongside errors for invalid quest documents. The editor is intentionally strict at the registration boundary. It always loads with `register_runtime = false`, and it calls `QuestRegistry.register_runtime_quests()` only when the loader returned zero errors. A rejected authoring package therefore registers nothing and leaves the previously registered runtime set untouched.

The read-only **Loader-registered quests** section is derived from the most recent real loader result, never from the unsaved draft.

The editor does not offer, resolve, complete, or otherwise advance quests. It does not mutate `GameState`, `Reputation`, `Renown`, `SkillCheck`, or the available/active/completed quest pools, and it never opens a runtime save sandbox. Its only runtime-state effect is explicit registration after a strict loader round trip, subject to the live-progress refusal above.

## Threat model and limitations

- **Symlinked write paths are out of scope.** Package containment is lexical. A symlink or junction inside a package can direct a write outside it. The editor is debug-only and environment-gated, and someone able to plant such a link in the developer's `user://` already has the ability to write anywhere the game can. The containment check therefore confines the editor's own id-derived paths; it is not a privilege boundary.
- **Save is rollback-capable but not crash-atomic.** Files are promoted individually, so terminating the process during promotion can leave a partially updated package and `.bak` or `.tmp` files. There is no transaction marker or startup recovery. Re-save from the editor, which still holds the draft, to recover. Campaign packages are proposals rather than canon, and `SaveGame` has the same property class.

## Picker sources

Known values come from existing runtime sources:

- Entry locations: `WorldMapRegistry.all_locations()`
- Giver actors: `NpcRoster.all()`
- Dialogue titles: the routed `DialogueResource` read by `CampaignQuestLoader`
- Factions: NPC roster faction ids, current reputation standings, and registered side-quest outcomes

An existing package value that is no longer present in a source remains visible in its picker so it can be corrected without being silently replaced.
