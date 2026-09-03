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

## Status (2026-09-02)
<!-- What actually exists, so a fresh session doesn't re-discover or re-litigate it. -->

The dialogue-and-consequence LOOP IS CLOSED end-to-end: lore vault → Pandora → reputation
ledger → dialogue → visible in-game consequence. Playable: launch, "New Game" boots into
`world/starting_town.tscn` (Dom, the City of the Four Arms). Walk up to the tavern facade (E)
to open the party-picker (`ui/screens/tavern.gd`) — pick up to 3 of 20 recruits (2 per patron
class), re-visitable any time. Some recruits gate on `globals/renown.gd` (`Renown`, a global
reputation/infamy pair, separate from the per-faction `Reputation` ledger and from the Soul
Gauge). Walk through the gap in the town's east wall to travel (`GameFlow.travel()`) to
`world/test_room.tscn`, the field-room vertical slice — Iris Illepah (E to talk) is there
unchanged, her choices still spend the Soul Meter and write the ledger live. GLoot-based grid
inventory is fully integrated into GameState and wired to the UI inventory screen. Battle is
an **overlay**, not a scene swap; wins/losses write to the reputation ledger the same way
dialogue does. **Chapter 1 PRD is RATIFIED** (`docs/prd-chapter-one.md`, zero ⚑ — see
`docs/phase-0-ratification.md`).

**Save schema is 6** (expert rerolls + tactical envelope, #189); `equipped_slots` rides as an
additive key (no bump; loader defaults `{}`). **Tactical combat is COMPLETE through Gate
T-10:** CT scheduler with ratified wait semantics (#193), grid battlefield + deterministic
pathing, pure `Resolution.resolve()` (forecast==resolution), six-region battle interface
(`ui/hud/battle_interface.*` + `ui/hud/regions/*`, event-driven with replay, contract frozen),
deployment chart states; the #202 PLACE gap is closed (`GameFlow._on_deployment_entered()`
wires `configure_placement()`). **#209 (live Weather + per-cell TileState) is IMPLEMENTED:**
CombatController owns a `Weather` + per-cell `TileState`s, weather ticks ride the scheduler's
`ticks_elapsed` so the two 16-tick clocks can't drift, and
`Battle.forecast_context()` → `BattleInterface.set_forecast_context()` gives region D the SAME
context live resolution uses — forecast==resolution by construction. Which encounters get
weather is still a **PROVISIONAL owner-authoring surface** (`EncounterCatalog._WEATHER_DEFAULTS`);
three encounters currently carry authored weather (`bog-wight: molm`, `loam-boar: terra`,
`phase2-demon: scor`).

**FR-503 fast travel is implemented:** `globals/fast_travel_registry.gd` (read-only GDScript
registry), `ui/screens/region_map.tscn`/`region_map.gd` (from the pause menu),
`GameFlow.fast_travel()` (purchase + route as one operation, refunds on any failure).
**FR-505: all six companion personal quests are authored** (user ratified all six, overriding
the PRD's 3–5 minimum), and **canon review is DONE** — all six recruits have vault entries +
`PartyMember.vault_id` bridges; no `PROVISIONAL — CANON REVIEW REQUIRED` markers remain
anywhere. Two ratified canon facts: **Serai-Lun is a namesake, not the founder** (Mirror-Veil
Mirrorblades take Serai of Lun's name as a devotional name); **NG+ stays deliberately in-world
ambiguous** (the three echo lines stay; no vault cosmology for it). **FR-605 (9-patch pass) is
DONE.** **FR-905 manual save slots (≥ 3) are DONE** (`SaveGame.MANUAL_SLOT_COUNT` = 3, pause-menu
slot buttons + `ui/screens/load_game.*`; no schema change). The Mirror Shop exists
(`ui/screens/shop.tscn`/`shop.gd`, `UIManager.SHOP`) — only NG+ itself deliberately excludes it
(`ng_plus.gd` is data-only).

**#98/#100 are NOT human-gated** — their ⚑s were ratified in `docs/phase-0-ratification.md`;
they are ordinary Codex implementation work. **Real remaining human gates:** #93 playtest gate
(needs 3–5 outside testers; recruit 6–8 — protocol/packet at `docs/playtest-protocol.md` +
`docs/playtest-packet.md`), FR-904 performance runbook on real hardware
(`docs/fr-904-runbook.md`), and Windows-machine chores (Maaack wizard, PixelPen, GodotGAS,
asset issues #112/#115). Counting note: `LocationRegistry.ALL.size()` is NOT the FR-501 metric
(it counts 20 interiors too); macro locations are 4 of 8 (Dom, Wilds, Dorthkor Road, Wound
Lip), hubs 1 of 3.

**Testing:** gdUnit4 (see `docs/testing.md`) — `test/unit/` + `test/integration/` automated,
`test/manual/` human checklists. Run via `GODOT_BIN=~/.local/bin/godot bash
addons/gdUnit4/runtest.sh -a test`. Suite: **1221 cases / 187 suites / 0 failures** (2026-09-02 run; a small
known set of headless-flaky pre-existing suites — `test_actor_presentation`, `test_y_sort`,
`test_click_to_move`/`test_click_to_move_input` — rendering/navmesh flakiness, not
regressions). **Environment gotchas:** `godot --headless --script` exits **134 at teardown
~20–30% of the time** even for trivial scripts — never gate CI on a tool script's raw exit
code, judge the output; applying patches without `--import` leaves new `class_name` globals
unregistered — re-import after adding a script with a `class_name`. gdUnit4 treats
Variant-inference (`:=` from a Variant-returning call, e.g. `auto_free()`) as a parse ERROR
that aborts the whole run with exit 105 — type such vars explicitly.

**Game identity is RATIFIED** (`docs/game-identity.md`, 2026-09-02, ten owner rulings): soul-as-currency
hook; hollowing not death; Soul income only via acts of Agreement; combat = tactical centerpiece with
**Fallout 2 lineage** (4–6 party, ~100 mobs, **same-map combat** — re-scopes the battle overlay,
#211, D4, #175); Fallout-full field verbs; class = identity + **DRAMGID** (dramgid-mono RFC-0001;
the build still runs the old six-stat system, migration = #283) = what you can do; XP + skill points
+ class perks; elegiac-and-wry tone. Wave F issues #280–#287 carry these consequences.

**Wave A/B magic-combat work merged 2026-09-02:** ClassResource seam v2 (#275: `on_any_action`
broadcast, deferred entries fired at CT tick/AP round and persisted under
`class_resources.__deferred__`, `request_cancel` with `resolving` guard, top-level `reveal`
context key, deterministic `hidden_draw`, `dot`/`soul_refund` write kinds, `deep_merge` for
overrides); all ten patron class resources (#277 B1–B5, #276 B6–B10, `globals/combat/class_resources/`,
`docs/class-resources.md`); Aftertone/Tempo state + ten Triad effects (#278; rulings PROVISIONAL in
code comments; leftovers #279). Suite after these merges: **1335 cases / 0 failures / 0 orphans**.
Process rule learned the hard way: a worker PR that adds state needs a `submit_action`-path test
per effect, or the state ships with no live consumer.

Fleet roadmap: docs/fleet-roadmap.md (issues #215–#265, Wave F #280–#287).

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
