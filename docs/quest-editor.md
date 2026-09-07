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

A complete package may also contain manually authored dialogue text:

```text
user://campaigns/<campaign_id>/
├── campaign.json
├── quests/
│   └── <quest_id>.json
├── dialogue/
│   └── *.dialogue
└── encounters/
    └── *.json
```

The `.dialogue` files in a runtime package are plain text despite their extension. The editor does not create or modify them; dialogue text is authored in those package files outside the game for now. The editor writes only the JSON files shown above. It never writes `res://`, committed dialogue or quest sources, Pandora data, the Dramgid vault, or any other canon surface. Promotion into canon remains the responsibility of `tools/bake_campaign.gd`.

Encounter JSON is also authored outside the in-game form in this wave. The editor has no
encounter-authoring UI; save stages and promotes every existing encounter file byte-for-byte with
the manifest and quest documents so it cannot drop authored work. Encounter validation errors use
the same validation and inline error list as quest or dialogue errors.

Campaign quest ids may use `/` to create nested paths such as `quests/side/baked-quest.json`. The path derived from an id must be portable and remain inside the campaign package: the id may not start with `/`; every `/`-separated segment must be non-empty, may not equal `.` or `..`, and may not end in a period or a space (Windows strips those from a path component, so `side.` and `side` would name the same directory there while staying distinct ids here); `:` and backslashes are forbidden; and no segment stem may be a case-insensitive Windows device name (`CON`, `PRN`, `AUX`, `ZHEM`, `COM1`–`COM9`, or `LPT1`–`LPT9`), with or without an extension. Substrings such as `a..b` remain legal when they satisfy `StableIds.QUEST`. Within one package, quest ids must also be unique under ASCII case folding so two documents cannot name the same path on a case-insensitive filesystem. `CampaignQuestLoader` enforces all of these rules for both disk loading and editor validation.

Dialogue and encounter discovery apply the same portable relative-path checks and the same depth
and regular-file limits as quest discovery. One shared package-discovery implementation owns those
rules. During discovery, child files and directories encountered beneath the fixed roots are skipped
when they are links. The package's own fixed `quests/`, `dialogue/`, and `encounters/` roots are
opened as given and are not link-checked. That distinction is intentional under
[Threat model and limitations](#threat-model-and-limitations), specifically **Symlinked package
read/write paths are out of scope**. A package that exceeds a bound or contains an unsafe relative
path is refused with a normal attributed loader error.

## Campaign encounters

Each encounter file is one JSON object. It requires `encounter_id`, `display_name`, a non-empty
`enemies` array, its own `grid`, and `weather_default` (an empty string means calm). Grid
`dimensions` and cover cells are `[x, y]` pairs; elevation rows are
`{"cell": [x, y], "height": <integer>}`. Grid width must be at least two, and grid height must
fit both sides: the larger of the enemy count and the normal party size (the protagonist plus
`GameState.REQUIRED_COMPANIONS`).

An enemy is either `{"archetype_id": "<generated combatant id>"}`, which inherits the complete
committed combatant row, or a complete row containing `id`, `display_name`, `max_hp`, `attack`,
`defense`, `balance_affinity`, `balance_pressure`, `element_id`, and `edge`. The loader
checks structure and playability, not balance: `max_hp` must be positive, but otherwise authored
stat magnitudes are not capped or canonized.

The package is refused with file-and-field attribution when an encounter shadows a committed id,
has missing/malformed required data or no enemies, names an unknown element or inherited archetype,
uses a grid too small for either side, places cover/elevation outside the grid, names an unknown
spoils item, authors a non-positive or non-integer spoils quantity, names an unknown faction in an
outcome or loss row, or supplies anything other than a JSON number for an authored `delta`,
`renown`, `win_delta`, or `loss_delta`. Numeric strings are refused. Consequence numbers may be
negative or arbitrarily large; the loader checks their type, not their balance. Campaign definitions
form a separate runtime overlay and carry their complete grid, weather, and spoils. They never
modify generated JSON, Pandora, or the committed grid/weather/spoils tables. Registering another
package replaces the entire prior encounter overlay.

There are exactly two supported reachability paths in this wave:

- Campaign dialogue can run `do Battle.start("<encounter_id>")`.
- Combat Lab (F3) lists every registered campaign encounter and starts it through the same
  `Battle.start()` production entry point.

There is no new encounter trigger type and no full encounter-authoring UI in scope.

## Campaign dialogue loading

Godot imports committed `.dialogue` assets before runtime, but files beneath `user://` cannot participate in that import pipeline. `CampaignQuestLoader` therefore reads package dialogue as text and compiles it during validation/loading with `DMCompiler`. It inspects compiler errors before constructing a `DialogueResource`; an author typo cannot trigger Dialogue Manager's assert-based runtime helper. Each compiler error reports the package file, the 1-based source `line`, `field`, `expected`, machine-readable `code`, and human-readable Dialogue Manager message.

Compiled resources belong only to the package being registered. Registering or clearing a runtime campaign replaces/releases the previous package's dialogue lookup, quests, and encounter overlay, so prior campaign content cannot route after a switch.

Title resolution is campaign-first: a runtime quest uses its package's compiled title when present, then the committed routed dialogue resource. A campaign title may not shadow a committed title, and duplicate titles across campaign dialogue files are also refused with attribution. A quest whose title exists in neither source is refused. Committed titles are still discovered through `ResourceLoader` and `DialogueResource.get_cues()` because source-file scraping would fail in exported builds.

## Validation and runtime state

`CampaignQuestLoader.validate_package_data()` is the single in-memory validation entry point used by the editor. Disk package loading and editor validation share the loader's campaign, dialogue compilation, title resolution, quest, identity, collision, outcome, and encounter validation implementation; the UI contains no second rule implementation.

The game loader remains tolerant: `load_package()` may return valid quests alongside errors for invalid quest documents. The editor is intentionally strict at the registration boundary. It always loads with `register_runtime = false`, and it calls `QuestRegistry.register_runtime_quests()` only when the loader returned zero errors. A rejected authoring package therefore registers nothing and leaves the previously registered runtime set untouched.

The read-only **Loader-registered quests** section is derived from the most recent real loader result, never from the unsaved draft.

The editor does not offer, resolve, complete, or otherwise advance quests. It does not mutate `GameState`, `Reputation`, `Renown`, `SkillCheck`, or the available/active/completed quest pools, and it never opens a runtime save sandbox. Its only runtime-state effect is explicit registration after a strict loader round trip, subject to the live-progress refusal above.

## Threat model and limitations

- **Symlinked package read/write paths are out of scope.** Package containment is lexical. As described under [Output boundary](#output-boundary), discovery skips linked child entries but opens the fixed `quests/`, `dialogue/`, and `encounters/` roots as given; a symlink or junction at one of those roots can therefore redirect reads, and a link in an editor write path can redirect writes. The editor is debug-only and environment-gated, and someone able to plant such a link in the developer's `user://` already has the ability to read or write anywhere the game can. The containment checks confine the tool's own id-derived paths; they are not a privilege boundary.
- **Runtime dialogue is not sandboxed.** Campaign dialogue can call autoload methods generally,
  including mutations such as `Battle.start()`. That is inherent to shipping runtime Dialogue
  Manager source. The tool is debug-only, environment-gated, and runs on the developer's own
  machine under the same accepted trust boundary as the symlink limitation; this wave documents
  the capability instead of pretending to sandbox it.
- **Save is rollback-capable but not crash-atomic.** Files are promoted individually, so terminating the process during promotion can leave a partially updated package and `.bak` or `.tmp` files. There is no transaction marker or startup recovery. Re-save from the editor, which still holds the draft, to recover. Campaign packages are proposals rather than canon, and `SaveGame` has the same property class.

## Picker sources

Known values come from existing runtime sources:

- Entry locations: `WorldMapRegistry.all_locations()`
- Giver actors: `NpcRoster.all()`
- Dialogue titles: campaign titles (`[CAMPAIGN]`) plus routed committed titles (`[COMMITTED]`), both supplied by `CampaignQuestLoader`
- Factions: NPC roster faction ids, current reputation standings, and registered side-quest outcomes

An existing package value that is no longer present in a source remains visible in its picker so it can be corrected without being silently replaced.
