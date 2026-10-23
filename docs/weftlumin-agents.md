# Weftlumin for agents: authoring a package headlessly

How Claude, Codex and other workers change scenes, canon documents, quests and encounters through the Weftlumin CLI and open a PR. They never hand-edit the outputs. The CLI is defined in architecture §4.13 (ruling 9). `docs/weftlumin.md` § "Headless CLI and PR flow" is the verb reference. This page covers the procedure and the rules.

The CLI replays the same command bus as the in-game editor. A package an agent writes and a package the owner records in the UI bake identically.

## Before you start

- Work only from an issue that authorizes the change. The issue supplies the scope. This runbook does not.
- Read `AGENTS.md` (lore and scope) and the design source the issue names. Canon values are design decisions; see [Never](#never).
- Every command below runs from the repository root:

  ```bash
  W() { "$HOME/.local/bin/godot" --headless --path . --script res://addons/weftlumin/tools/weftlumin.gd -- "$@"; }
  ```

- **Judge a run by its last line**: `WEFTLUMIN: <verb> <ok|errors|usage|refused_overlap> exit=<0|1|2|3>`. Read it, or the `--report <file>` JSON. Never trust the process exit code, because Godot can abort at teardown after a successful run.

## 1. Lay out the package

Keep the package **outside the repository**, for example `$TMPDIR/weftlumin/<id>/`. The package is authoring input. Only what `bake --write` produces gets committed. `apply` refuses any package inside the project.

```
<id>/
  campaign.json          manifest (optional, recommended)
  commands.jsonl         scene command log (kind "scenes")
  locations/*.json       canon documents: replace the canon doc with the same id, or add one under canon/<hub>/
  routes/*.json          weftlumin.route.v1, filed with the origin location (#342)
  characters/*.json
  spawn_tables/*.json
  quests/*.json          validated through CampaignQuestLoader (no canon bake target yet)
  encounters/*.json
  dialogue/**/*.dialogue linted: [if /] conditions, flag grammar, POT delta
```

```json
{"schema": "weftlumin.package.v1", "id": "dom-puddle-nudge", "title": "Dom: nudge the west river puddle", "kinds": ["scenes"]}
```

- **`id`**: becomes the branch name `weftlumin/<id>`, the worktree name and the scratch-directory name. Use only lowercase letters, digits, `-` and `_`; anything else is refused (`invalid_package_id`). `hub` follows the same rule (`invalid_hub`).
- **Missing manifest**: the id comes from the log and the kinds are the folders present. The committed fixture `test/fixtures/weftlumin/dom_scene_bake` has no manifest.
- **Canon documents**: start from a copy of the current file in `canon/<hub>/<kind>/`. Change only the fields the issue authorizes.

## 2. Write the command log

`commands.jsonl` has one `weftlumin.command.v1` object per line. A scene op from the fixture:

```json
{"schema": "weftlumin.command.v1", "id": "01M4NECT3K000000TMQ5PNP8VK", "package": "dom-puddle-nudge", "kind": "scene", "op": "set_property", "target": {"scene": "res://world/starting_town.tscn", "node": "TownscapeDressing/GroundDetails/PuddleRiverWest"}, "params": {"key": "position", "value": [736.0, 1518.0]}, "pre_state": {"value": [720.0, 1510.0]}, "provenance": {"actor": "codex", "source": "cli"}, "ts": "2026-10-14 12:00:00Z"}
```

- **Ops** (`kind: "scene"`):
  - `set_property`: `params.key`/`value`, `pre_state.value`.
  - `add_node`: `params.instance` with a `placeable`, `pre_state.present: false`.
  - `remove_node`: `pre_state.present: true`.
  - `paint_cells`: tile cells.
  - `undo` / `redo` are bookkeeping (`target.command`). They must name an earlier id.
  - The fixture log has an example of every op.
- **`id`**: unique and sortable. Copy the ULID shape (26 Crockford base-32 characters) and increase it line by line.
- **`pre_state`**: what the scene holds *before* the op. Replay checks it. On a mismatch it stops with `pre_state_drift` and writes nothing. To find the current value, write your best guess and run `W bake <pkg>`. The error names the recorded and the found value:

  ```
  ERROR res://world/starting_town.tscn [commands] pre_state_drift: … recorded pre_state { "value": [700.0, 1500.0] } but found { "value": [720.0, 1510.0] }.
  ```

- **`provenance.actor`**: name the agent truthfully (`codex`, `claude`, …); `owner` is reserved for the owner's own recordings.
- **Boundaries**: these are enforced, not advisory. Nodes inside an instanced sub-scene accept only property overrides. The scene root cannot be removed. Nodes spawned at runtime are not in any scene file.
- **Live-state verbs**: `{"kind": "console", "op": "execute", "params": {"command": "…"}}` runs against the live autoloads under `apply` and is excluded from replay. Use them for scratch checks only; they never reach a PR.

## 3. Check, bake, and plan the PR

Run these in order. Fix what each one reports before moving on.

```bash
W validate $PKG          # manifest + every kind, attributed errors (file, field, code)
W lint     $PKG          # [if /] conditions, quest_audit statics, flag grammar, POT delta
W bake     $PKG          # weftlumin.bake.v1 report; lists every file it would write; writes nothing
W apply    $TMPDIR/weftlumin/try $PKG/commands.jsonl   # optional: replay into a fresh dir's scratch/ to inspect the patched scene
W pr       $PKG --issue N --draft --trailer "Co-Authored-By: …"   # dry run: prints the exact plan
```

`apply` replays the target directory's own log first, then the given log. Point it at a fresh, empty directory, never the package itself, or the log replays twice and stops on `pre_state_drift`.

The dry-run `pr` makes no process or network call. Check its plan:

- **Changed files**: only what the issue authorizes. A scene package should list only its `.tscn`.
- **Affected tests**: these come from the adapter's fixed kind → test-glob map. For scenes: `test_starting_town`, `test_field_room` and `test_travel_*`.
- **Commit**: carries `Closes #N` and exactly the trailers you passed.

To check for conflicts before executing, save `gh pr list --state open --json number,title,headRefName,files` to a file and pass it as `--open-prs FILE`. If an open PR changes one of your files, the result is `refused_overlap` with exit 3. Don't reach for `--force`: stop and report the overlapping PR in the issue. Only the owner decides to collide with in-flight work, such as Dom's art batch.

## 4. Open the PR

```bash
W pr $PKG --issue N --draft --execute --trailer "Co-Authored-By: …"
```

`--execute` runs the plan:

1. Fetch `origin/<base>` and create a worktree on `weftlumin/<id>` from it.
2. Import, then run `bake --write`, and `regen --write` when the bake regenerates data.
3. Run lint and the affected tests.
4. Stage everything, then **re-scan for overlap on the staged files**. Regen can touch more than the plan named.
5. Commit, push, and run `gh pr create --draft`. The PR body is the bake report.

It stops at the first failed step, and the report's `pr.executed` shows where. The worktree and branch are kept for inspection. Remove both before a rerun (`git worktree remove …`, `git branch -D weftlumin/<id>`).

Pushing and opening a PR are outward-facing. Run `--execute` only when the issue or the owner authorizes it. Otherwise hand off the dry-run plan.

## 5. A new location, end to end

Hollowmere (`7b39b9a7`, C4 / #241) is the current worked example; the Long Verge (`9d13d10f`) and
the two hubs (#501, #502) have the same shape. `docs/weftlumin.md` § "New scene" lists what stays
hand-wired; this is the order of work and the refusals you will meet.

1. **Authority.** An owner-approved vault proposal (`../dramgid-vault/proposals/locations/<id>.md`)
   plus its issue. Every name, number and line beyond the proposal is PROVISIONAL: list it under
   items 4 (names and values) and 9 (prose) of `docs/owner-decisions.md`, never resolve it.
2. **Package** (outside the repository). `campaign.json` with kinds
   `["scenes", "locations", "characters", "spawn_tables"]`. The log opens with one `new_scene`
   (`template: "field"`, `size_cells: [105, 105]` is the 3000×1800 room; the root `<PascalId>`
   carries `chapter_location.gd`, `Player`, `SpawnDefault`, `OutdoorTownsfolk` and
   `<PascalId>Dressing/{GroundDetails,SoftDetails,SolidProps}`), then `add_node` ops: an
   `addition` is a dressing prop (`layer`, `name`, `texture`, `position`, `scale`, optional
   `collision`, `flip_h`; `SolidProps` bake to a `StaticBody2D`), an `instance` is a placeable
   (`spawn_marker`, `spawn_slot`, `travel_exit`, `hostile`, `npc`, `chest`) with exports as
   `var_to_str` text, for example `"spawn_id": "&\"from_hollowmere\""`. The neighbour's reverse
   exit and spawn marker are `add_node` ops in the same log whose target scene is
   `res://world/<neighbour>.tscn`. Write a generator script for a log of a hundred ops; ids are
   ULIDs (10 time, 6 sequence, 10 random Crockford characters) that increase line by line.
   Canon documents: `locations/<id>.json` (accord and tier from `docs/thinning-gradient.md`,
   tiers 0–3 read 95/85/70/55; `respawn_policy`; `spawns` with `from_<neighbour>`), an overlay
   `locations/<neighbour>.json` that only adds `from_<id>` to its spawns, one
   `characters/<id>-<role>.json` per NPC, and `spawn_tables/<id>-ambient.json` whose slots name
   `SpawnSlot*` markers and committed archetypes. Travel and doors are canon too (#342): the
   location document carries its `world_map` facet (and `fast_travel` only for a hub), each new
   road is a `routes/<origin>-<destination>.json` document (PROVISIONAL numbers), and an interior
   document carries the `transition` facet for its door. The bake writes the index and the door
   `.tres` pair; no registry is edited by hand.
   - Character `order` is global and contiguous across all locations (`test_canon_reader` pins
     it); after Hollowmere the next free order is 86.
   - `faction_id` must be a canon faction (`canon/dom/factions/<id>.json`); add the document
     first when the vault faction is not seeded yet, or the generator asserts.
   - At most one routined NPC per location (`NpcRoutines.ROUTINE_CAP`); the others declare
     `phase_agnostic: true`. Keep one phase-agnostic outdoor NPC for the prompt-range test.
3. **Render, validate, bake, regen.** Keep the log beside the package, not inside it:

   ```bash
   W apply    $PKG $LOG                 # writes $PKG/commands.jsonl and $PKG/scratch/world/*.tscn
   cp $PKG/scratch/world/<id>.tscn $PKG/scenes/<id>.tscn   # validate needs the rendered scene for a scene_path that does not exist yet
   W validate $PKG
   W bake     $PKG --write              # scene, neighbour patch, canon/<id>/, .tres, location_index.json, lint
   W regen    --write                   # Pandora seed, rosters, placements, <id>_townsfolk.dialogue, FactionIds / NpcIds
   ```

   A second `bake --write` against the already patched neighbour refuses with `pre_state_drift`;
   `git checkout -- world/<neighbour>.tscn`, delete the baked outputs, bake again. The patch is
   byte-identical across bakes.
4. **Hand-wire**, in this order, because the registry preloads need the baked `.tres`:
   `LocationRegistry.<ID>`, then `tools/seed_town_npcs.gd` town, name, placement-anchor rows and
   the district greeting and farewell pair. Then
   `godot --headless --path . --import`: the new `.dialogue` sidecar, the new scripts' `.uid`
   files and the `locale/translations_pot_files` entry are all import output; commit them.
5. **Verify.** `test/integration/test_<id>.gd` from `test_hollowmere.gd` (scene contract,
   registries, spawn-table anchors, reverse exit, roster spawn at anchors, talk prompt, movement).
   Bump the merged count literals: `test_canon_reader` (factions), `test_dom_npc_roster` and
   `test_weftlumin_characters_kind` (NPCs, `npcs_by_hub`), `test_weftlumin_character_panel`
   (rows), `test_location_registry` (locations), `test_weftlumin_locations_kind` (`MACRO_IDS`),
   `test_world_map_registry` (locations, routes). Run the affected suites,
   `scripts/check_generated_data.sh`, `tools/quest_audit.gd`, then a capture
   (`test/manual/<id>_capture.gd`, a temporary autoload under Xvfb that walks the real exits) and
   look at the frames. Dom's exits gate differently: `NorthRoad` reads the single
   `required_flag = "chapter_dorthkor_commissioned"`, the wilds exits accept any of
   `tutorial_road_open` / `chapter_one_free_roam`.
6. **Prose.** The generated `<id>_townsfolk.dialogue` is a placeholder. Real ambient talk goes
   in `dialogue/locations/<id>.dialogue` under the generated titles (C25 / #262): the canon
   `dialogue_hostile` / `dialogue_warm` lines verbatim as the band gates, no quest content, the
   `PROVISIONAL — CANON REVIEW REQUIRED` header; `test/unit/test_location_dialogue.gd` holds it to
   that.
7. **Commit** on the content branch with `Closes #N` and the handoff below; `pr --execute` only
   when the issue authorizes a push.

## Never

- **Never hand-edit what the bake owns.** That covers `.tscn` patches, `canon/`, `world/locations/*.tres`, `data.pandora` and `data/generated/*`. Change the package and re-bake. Pandora is never written from generated artifacts.
- **Never set labels, milestones or assignees.** The CLI never does, and neither should you. Labelling is Claude's triage act (AI-ROLE-POLICY).
- **Never invent canon.** New or changed canon values, lore prose and deliberate mysteries (`canon/open-questions.md`) need an issue that ratifies them. Lore prose belongs to the Dramgid vault, not to package documents. Surface conflicts between sources; don't resolve them silently.
- **Never write player-facing prose without the POT step.** `lint` reports new strings as a POT delta. Regenerating the POT is the owner's step on the editor machine; list the delta in the PR.
- **Never pass `--force` on your own.** On `bake --write` it overwrites a target that holds neither the source scene nor this bake's output, which means someone else's edit. On `pr` it opens despite an overlap.
- **Never run a package from inside `res://`** for `apply`. Never weaken `OS.is_debug_build()` checks or export exclusions to make a check pass.

## Handoff

In the issue, report:

- the package path
- the final `WEFTLUMIN:` line of each verb
- the PR URL, or the dry-run plan if `--execute` was not authorized
- the POT delta
- any refusal (`pre_state_drift`, `refused_overlap`, lint codes), with the report JSON attached
