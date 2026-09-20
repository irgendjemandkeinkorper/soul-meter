# Inherited project status — archived 2026-09-12

Historical notes extracted from CLAUDE.md; the original status heading was dated 2026-09-02 and included later updates. These claims and counts were not rerun or revalidated during the instruction cleanup. For current rules and commands use ../../AGENTS.md and ../agent-verification.md. Do not treat old commands, test counts, or pending-work claims as current instructions.

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

**Save schema is 9** (DRAMGID attribute/skill rename, #392 — 8 was the 2026-09-06 elemental
wheel rename #371, 7 the FR-504a world clock, 6 expert rerolls + the tactical envelope #189);
`equipped_slots` rides as an additive key (no bump; loader defaults `{}`). **Tactical combat is COMPLETE through Gate
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
three encounters currently carry authored weather (`bog-wight: mozh`, `loam-boar: tham`,
`phase2-demon: khash`).

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
addons/gdUnit4/runtest.sh -a test`. Suite: **1729 cases / 0 failures** (2026-09-08 run; a small
known set of headless-flaky pre-existing suites — `test_actor_presentation`, `test_y_sort`,
`test_click_to_move`/`test_click_to_move_input`, `test_field_room`'s sprint case,
`test_consequence_notices` — rendering/navmesh/timing flakiness, not regressions; each passes
when its suite is run alone). Full run takes **50+ minutes** locally: use `timeout 5400`, and
`LP_NUM_THREADS=1`. **Environment gotchas:** `godot --headless --script` exits **134 at teardown
~20–30% of the time** even for trivial scripts — never gate CI on a tool script's raw exit
code, judge the output; applying patches without `--import` leaves new `class_name` globals
unregistered — re-import after adding a script with a `class_name`. gdUnit4 treats
Variant-inference (`:=` from a Variant-returning call, e.g. `auto_free()`) as a parse ERROR
that aborts the whole run with exit 105 — type such vars explicitly. Editing a `.dialogue`
file, or switching branches across one, needs a re-import too — `load()` returns the IMPORTED
resource, so without it the suite reports large clusters of failures that do not exist.
gdUnit4 also **stops running the rest of a suite after some failures**: a full run reporting
one failure in a file may be hiding three, so re-run that suite alone before believing the count.

**Game identity is RATIFIED** (`docs/game-identity.md`, 2026-09-02, ten owner rulings): soul-as-currency
hook; hollowing not death; Soul income only via acts of Agreement; combat = tactical centerpiece with
**Fallout 2 lineage** (4–6 party, ~100 mobs, **same-map combat** — re-scopes the battle overlay,
#211, D4, #175); Fallout-full field verbs; class = identity + **DRAMGID** (dramgid-mono RFC-0001;
**F3a is 7 of 11 surfaces done** — schema, `SkillCheck` + live karma bonus, chargen + character
sheet, advancement, Yothmeru on `Renown`, save schema 9, and every dialogue/code skill id;
what remains is blocked, see `docs/architecture-dramgid.md` §3, #283) = what you can do; XP + skill points
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
