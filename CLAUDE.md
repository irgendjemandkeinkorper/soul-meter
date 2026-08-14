<!--
  CLAUDE.md — L0 baseline (the MAP + the RULES).
  ALWAYS loaded and prompt-cached. Keep it SMALL, STABLE, DURABLE.
  Edit BETWEEN tasks, never mid-task (edits invalidate the cache rightward).
  Transient/"for this session" understanding goes in the vault (L1), not here.
-->

# Soul Meter

A dialogue-and-consequence-first CRPG built solo in **Godot 4.7** — a consequence-driven RPG
in Era 3 of the Dramgid Cycle. **2D, isometric, rendered from 3D models.** Design-doc-first;
config name `SoulMeter`.

## Status (2026-07-30)
<!-- What actually exists, so a fresh session doesn't re-discover or re-litigate it. -->

The dialogue-and-consequence LOOP IS CLOSED end-to-end: lore vault → Pandora → reputation
ledger → dialogue → visible in-game consequence. Playable: launch, "New Game" now boots into
`world/starting_town.tscn` (Dom, the City of the Four Arms) instead of the field room directly.
Walk up to the tavern facade (E) to open the party-picker (`ui/screens/tavern.gd`) — pick up to
3 of 20 recruits (2 per patron class), re-visitable any time. Some recruits gate on
`globals/renown.gd` (`Renown`, a global reputation/infamy pair, separate from the per-faction
`Reputation` ledger and from the Soul Gauge — see its header comment for why): battle wins and
some dialogue/quest outcomes feed one or the other. Walk through the gap in the town's east wall to travel
(`GameFlow.travel()`) to `world/test_room.tscn`, the original field-room vertical slice — Iris
Illepah (E to talk) is there unchanged, her choices still spend the Soul Meter and write the
ledger live. GLoot-based grid inventory is fully integrated into GameState and wired to the UI
inventory screen. A minimal turn-based Battle scaffold (`globals/battle.gd`) is wired into
GameFlow, with two field encounters (Bog Wight, Loam-Maddened Boar) and the first fetch quest
(Loamroot Sprig, via `QuestRegistry`) — battle wins/losses write to the reputation ledger the
same way dialogue does.
**Testing is now set up:** gdUnit4 (see `docs/testing.md`) — automated suites in `test/unit/`
and `test/integration/` (reputation ledger, inventory screen, field-room movement/collision/NPC
range), plus a manual-checklist convention in `test/manual/`. Run via
`GODOT_BIN=~/.local/bin/godot bash addons/gdUnit4/runtest.sh -a test`.
**Still open / next candidates:** Maaack's setup wizard (editor-interactive, do on the Windows
machine), GodotGAS (store download, no public repo), portrait art PNGs from the DS project,
and `docs/godot-architecture.md`'s one remaining open human question (gamepad-at-ship).

## Status addendum (2026-08-04) — supersedes the 2026-07-30 section above where they conflict
<!-- The section above understates the repo badly. Verified against the tree, not assumed. -->

**Chapter 1 PRD is RATIFIED** (`docs/prd-chapter-one.md`, 2026-08-03, zero ⚑ — see
`docs/phase-0-ratification.md`). Much of what that PRD lists as "remaining" already EXISTS:

- **Phase 1 resolution spine is built:** `globals/skill_check.gd`, `fizzle_table.gd` +
  `default_fizzle_table.tres`, `globals/elements/` (wheel, triads, composition resolver,
  casting gate), `save_game.gd` + `save_migrations.gd`, `ng_plus.gd` (data-only; the Mirror
  Shop is deliberately NOT in it).
- **Most of the Phase 2 combat vertical is built:** `globals/combat/combat_controller.gd`,
  `battlefield_model.gd` + `zone_battlefield_model.gd` (the FR-105 grid-swap seam is honored),
  `combat_style_tracker.gd`, `combat_speech_presenter.gd`, `encounter_catalog.gd`,
  `ui/hud/battle_hud.tscn` + `balance_arcs.gd` + `eclipse_pips.gd`. Battle is an **overlay**,
  not a scene swap.
- **CI is wired** (FR-903 is NOT open): `.github/workflows/test.yml` runs import, acceptance
  gate, Pandora drift check, headless gdUnit4, and a Windows export.

**Implemented ≠ accepted.** Two gates are unproven, and no amount of code closes them:
- **Phase 1.5 comprehension gate has NEVER been run** (PRD line 185 — ratified: it is the
  go/no-go for content production). It needs **3–5 outside human playtesters**; an agent fleet
  cannot execute it. Protocol + evidence template now exist at `docs/playtest-protocol.md`.
  Region content must not merge into `world/locations/` or `LocationRegistry.ALL` until it passes.
- **FR-904 is instrumented but NOT satisfied** — see `docs/performance-benchmark.md`.

**Wave 1 (2026-08-04) landed:** `globals/load_destination.gd` + a `SaveGame.load_requested`
signal removed SaveGame's 6-site reach into `GameFlow` private state (save schema still 5, legacy
adapter, fixture at `test/fixtures/save_game_schema_5.json`); `tools/quest_audit.gd` (FR-501/403,
reporting-only by default, `SOUL_METER_QUEST_AUDIT_STRICT=1` to enforce — **read its header
limitations before trusting a green result**); FR-904 harness `tools/performance_benchmark.gd` +
`scripts/benchmark_performance.sh`. Suite: **305 cases / 54 suites / 0 failures**.

**Two environment gotchas worth knowing:**
- `godot --headless --script` aborts with **exit 134 at teardown ~20–30% of the time** here,
  even for a 3-line script. Never gate CI on a tool script's raw exit code — judge the output.
- Applying patches without `--import` leaves new `class_name` globals unregistered; re-import
  after adding a script with a `class_name`.

**Real remaining Chapter 1 gaps:** locations 4 of 8–12 and hubs 1 of 3; companions (FR-505,
no `personal_quest` anywhere); region map / fast travel (FR-503 — ratified as "discovered hubs
only, at a cost", so implement, don't redesign); Mirror Shop (FR-801); 9-patch pass (FR-605).

## Status addendum (2026-08-12) — supersedes the two sections above where they conflict

**Two corrections to the gap list directly above:** `ui/screens/shop.tscn`/`shop.gd` + a
`UIManager.SHOP` entry already exist — **the Mirror Shop is not a gap**, contrary to both the
2026-08-04 gap list and line 48–49's "deliberately NOT in it" note (that note is about `ng_plus.gd`
specifically and remains accurate for NG+; the shop screen itself is real). FR-503 (region map /
fast travel) is now implemented — see below — so it's off the gap list too.

**FR-503 landed:** `globals/fast_travel_registry.gd` (a read-only GDScript registry, not a Pandora
entity — Pandora has no ratified hub/travel-cost schema yet; migrate later, see the file's header),
`ui/screens/region_map.tscn`/`region_map.gd` (opened from the pause menu), `GameFlow.fast_travel()`
(purchase + route as one operation, refunds on any failure). `GameFlow._process()` now polls for
scene-load completion/failure every frame instead of relying on a one-shot `call_deferred` off
`SceneLoader.scene_loaded` — that signal fired before Maaack's loader actually swapped
`current_scene`, so completion could be missed permanently; polling fixed it. A failed load
recovers to the last-known-good scene and reopens the region map so the player sees "Travel
failed, no GP was spent" instead of silence. Tests: `test/unit/test_fast_travel.gd`,
`test/integration/test_region_map.gd`.

**FR-505 (companion personal quests) — the promotion-mechanic decision, made by explicit user
directive since `docs/chapter-one-open-questions.md` Q8 leaves it unratified:** there is no
separate "promotion" step. A recruit becomes eligible for their personal quest the moment they
join the active party (`GameState.set_companions()` → `party_changed` →
`QuestRegistry._offer_companion_quests_for_party()`, idempotent). Content is authored per-recruit
via `QuestRegistry.COMPANION_QUESTS`/`COMPANION_QUEST_DIALOGUE` (keyed by `PartyMember.id`) — a
recruit with no entry simply has no personal quest yet, which is visible via
`QuestRegistry.companion_quest_for()`/`companion_quest_dialogue_for()` returning null/empty, not a
silent gap. **One worked example is authored end-to-end:** Serai-Lun
(`quests/serai_lun_mirror_line.tres`, `dialogue/companions/serai_lun.dialogue`). Companions have no
field presence, so her quest is talked through from `ui/screens/party.gd`'s new "Talk to <name>"
button (visible only when `companion_quest_dialogue_for()` is non-empty), not a walk-up NPC —
mirrors `actors/npc/npc.gd`'s `DialogueManager.show_dialogue_balloon()` call. Resolution goes
through `QuestRegistry.resolve_companion_quest()`, which writes exactly one `Renown.gain_reputation()`
event. **The other 5 recruits still have no personal quest authored** — that's the real remaining
content gap, now that the system itself exists. `tools/quest_audit.gd`'s `FLAG_DOMAINS` gained a
`party` domain for this (e.g. `party_serai_lun_resolved`); don't grandfather new flags into
`LEGACY_FLAGS` instead — the script's header explains why. Tests:
`test/unit/test_companion_quest.gd`, `test/integration/test_party_screen.gd`, plus a walkthrough
step in `test/e2e/test_first_chapter_journey.gd`.

Suite: **651 cases / 0 new failures** (4 pre-existing, unrelated failures reproduce on a clean
`main` checkout too — `test_actor_presentation.gd`, `test_y_sort.gd`,
`test_click_to_move.gd`, `test_click_to_move_input.gd` — all headless-rendering/navmesh flakiness,
not regressions).

## Architecture map
<!-- Read THIS instead of grepping to "discover" structure. Load-bearing paths only. -->

- **Engine:** Godot 4.7.1, Forward Plus, Jolt physics. Binary at `~/.local/bin/godot`
  (headless verify: `godot --headless --path . --import` then `--quit-after N`; screenshot
  under xvfb — see DEPENDENCIES.md for the window-size gotcha).
- **Entry:** `run/main_scene` = `ui/screens/main_menu.tscn`.
- **Flow (POLICY):** `ui/flow/game_flow.tscn` — the **Godot State Charts** root chart
  (Boot / Menus / Playing:Loading·Active·Paused·Battle). UI sends `GameFlow.send_event("...")`;
  **no `change_scene_to_file()` in game code, ever.** SceneLoader (Maaack) is the mechanism.
  Moving between gameplay scenes (town ↔ wilds) goes through `GameFlow.travel(scene_path)`
  (Active → Loading → Active on the `"travel"` event), never called directly by an actor —
  see `actors/travel_exit/`. `GameFlow.TOWN_SCENE`/`WILDS_SCENE`/`GAMEPLAY_SCENES` are the
  scene-path constants; `UIManager._in_gameplay()` checks membership in `GAMEPLAY_SCENES`, not
  equality to one scene. GameFlow also mirrors `Reputation` standings into chart expression
  properties (`rep_<faction>`) so transitions can use guards.
- **Global state:** `globals/game_state.gd` (`GameState`) — flags, Soul Meter, party,
  inventory (GLoot-based), settings (persisted). `party_member.gd` is its resource.
  `GameState.recruitable_candidates()` / `set_party()` back the tavern's party-picker (the
  only place `party` is meant to be replaced wholesale — anything else mutating it directly
  must emit `party_changed` itself). `globals/reputation.gd` (`Reputation`, separate autoload)
  — the append-only consequence ledger: `record(actor, faction, delta, cause, scene)` is the
  ONLY write path; `standing()`/`band()`/`why()` are derived reads. See
  `globals/reputation_event.gd`. `globals/renown.gd` (`Renown`, separate autoload) — the
  second, faction-independent consequence ledger (global reputation + infamy, not per-faction
  standing and not the Soul Gauge): `gain_reputation()`/`gain_infamy()` are the only write
  paths; `reputation()`/`infamy()`/`why(kind)` are derived reads.
- **UI:** `ui/ui_manager.gd` (`UIManager`, mechanism-only screen stack) + `ui/screens/*`
  (Screen base + main_menu/pause/inventory/party/settings/tavern) + `ui/hud/` (`SoulGauge`,
  `field_hud.tscn`) + `ui/dialogue/` (`SMPortrait`, `SMDialogueChoice`, the Echo Gate
  balloon — Dialogue Manager's registered runtime balloon).
- **Design system:** `ui/theme/ds.gd` (token constants) + `theme_builder.gd` (the Theme —
  type variations only, e.g. `HeroLabel`/`DangerButton`; never per-node overrides). Source of
  truth is the synced Claude design-system project — see `design/DESIGN_SYSTEM.md`. Fonts in
  `assets/fonts/soul-meter/` (Cinzel/Cormorant/Fira, OFL).
- **World:** `world/starting_town.tscn` (Dom, the starting town — `GameFlow.TOWN_SCENE`, the
  actual boot destination) + `world/test_room.tscn` (the original field room vertical slice —
  `GameFlow.WILDS_SCENE`, reached via a `TravelExit`, has `FieldHUD` + an NPC) + `actors/player/`
  (CharacterBody2D) + `actors/npc/` (interactable, E to talk — see `dialogue/*.dialogue`) +
  `actors/tavern_door/` (interactable, E opens the tavern) + `actors/travel_exit/` (walk-over,
  scene-to-scene via `GameFlow.travel()`).
- **Data:** `data.pandora` (committed) — canonical game data, seeded from the lore vault by
  `tools/seed_pandora.gd` (idempotent). `tools/generate_gloot.gd` is the one-way Pandora→GLoot
  generator (`data/generated/`: prototree JSON, `ItemIds` constants, `items.pot`); run via
  `Project → Tools → Regenerate GLoot prototypes` (our own `addons/soul_meter_tools`) or
  headless with `SOUL_METER_DRIFT_CHECK=1` for CI. **GLoot is fully wired to GameState and the inventory screen.**
- **Dialogue content:** `dialogue/*.dialogue` (Dialogue Manager text format). Response
  conditions need the self-closing form `[if expr /]` — plain `[if expr]` silently no-ops
  (see DEPENDENCIES.md). Metadata rides tags: `[#tag=X] [#cost=-6 soul] [#consequence=...]`.
- **Addons (14):** see `DEPENDENCIES.md` for pins & quirks — Maaack's template, State Charts,
  Pandora, Dialogue Manager, QuestSystem, GLoot, Phantom Camera, Anima, Juicee, SmartShape2D,
  PixelPen (parked on Linux), gdUnit4. **Never edit anything under `addons/`** (except our own
  `addons/soul_meter_tools`, which is project-owned).
- **Testing:** `docs/testing.md` — gdUnit4, `test/unit/` + `test/integration/` (automated) and
  `test/manual/` (human checklists). Read it before adding either kind.
- **Art:** `assets/kenney/` (CC0, curated; see its ATTRIBUTION.md).
- **Where NOT to look:** `.godot/`, `.git/`, `*.import`, `dramgid-lore-dump.md` (superseded).

## The architecture spec is `docs/godot-architecture.md`
<!-- The full handoff: layers, plugin stack, sync specs, conventions. Read before building systems. -->

Five layers, dependencies point down only: **Flow (state charts) → Presentation → Systems
(GAS/GLoot/reputation) → Narrative (Dialogue Manager/QuestSystem) → Data (Pandora)**.
Load-bearing rules:

- **Pandora is canonical; nothing writes back.** GLoot prototypes / GAS effects / lookup
  tables are *generated* artifacts (`data/generated/`) — never hand-edit; regenerate via
  `tools/generate_gloot.gd`. Entities carry a `Vault Id` property bridging to the lore vault:
  Pandora owns *game data*, the vault owns *lore prose*.
- **Flow:** buttons send events, never name destinations; guards not `if`s; every state pairs
  enter/exit.
- **Reputation:** append-only event log `{actor, faction, delta, cause, scene, timestamp}` —
  **implemented**, see `globals/reputation.gd` above. Faction ids are the lore vault's kebab
  ids (60 factions exist).
- **Theming:** theme type variations, no per-node overrides; 9-patch `StyleBoxTexture` (not
  yet built — corners are currently sharp, tracked as a gap in `design/DESIGN_SYSTEM.md`).
- **Combat collision:** in-house hitbox/hurtbox (Area2D pair), GDQuest pattern — not yet built.
- **Human decisions on record:** localization = PO/gettext; inventory = grid (`Grid Size`
  required on Pandora `Items`); multiplayer = co-op is a live maybe (keep GameState
  serializable, wrap GAS behind a seam, `StateChartSerializer` matters).
- Also read `docs/godot-flow-handoff.md` (statechart tree detail) and `DEPENDENCIES.md`
  (pins; what's pending: Maaack wizard, GodotGAS, and CI drift-hook follow-through).

## The design doc is the spec (game design)

`soul-meter-crpg-design-doc.md` defines [CANON] vs [PROPOSAL]. §6 chassis (field → battle
scene → turn-based) is DECIDED; §9 mandates the serialized game-state singleton (exists:
`GameState`). §10 open canon questions — never resolve silently. ⚠ The doc predates the lore
vault; where they conflict (e.g. Maiiam kidnapped vs withdrawing), flag it — vault wins until
the doc is revised.

## World lore lives in the Dramgid vault (source of truth)

`~/projects/dramgid-vault/` (own git repo): 172 entities incl. `factions/` (60) and
`characters/` (25). **Read `index.json` first**, open only the 2–4 entity files the task
needs, follow `related` ids. `canon/` + `cosmology/` are do-not-contradict;
`canon/open-questions.md` = deliberate mysteries. Load-bearing for the game:
`cosmology/souls.md` (Soul Gauge = the Soul Meter), `systems/magic-system.md`,
`systems/ten-patron-classes.md`, `systems/character-creation.md`. New lore ⇒ edit entity,
rerun `build_index.py` + `validate.py` (venv at `dramgid-vault/.venv`).

## Conventions

- GDScript: static typing, `snake_case` files/vars, `PascalCase` nodes/classes; one script
  per node; signals over polling; autoloads for global state.
- Scenes `.tscn`; hand-edit only surgically; keep `uid://` refs intact.
- `rg` over `grep`, `fd` over `find`.

## Working agreement (token discipline)

- Use the map + specs above before searching; a named file/scene/symbol is your pivot.
- Prefer signatures/headings over full bodies; whole-file reads only when editing.
- Side investigations go to a subagent.
- End-of-task: learned something durable → vault note or CLAUDE.md edit (between tasks).

## Do NOT

- Don't edit this file mid-task. Don't read/edit `.godot/`.
- **Don't edit anything under `addons/`.** Don't hand-edit generated `data/generated/*`.
- Don't call `change_scene_to_file()` in game code — send a GameFlow event.
- Don't resolve open canon questions or override [CANON] in code without asking.
- Don't add mechanics without the relevant design-doc/architecture section first.
- Don't reformat/mass-rename outside the task's scope.
