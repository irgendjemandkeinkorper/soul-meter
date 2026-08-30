# Fallout 2 Adoption Spec — REV 2, RATIFIED (owner, 2026-08-28)

**Created:** 2026-08-28 (octo:embrace Define phase) · **Revised:** same day, after the
define→develop debate gate returned REVISE (`embrace-gate-define-develop-1787961610.md`).
**Sources:** `.claude/session-intent.md`, `.claude/session-plan.md`, Discover probes
`codex-probe-1787960453-{0,4}.md`, `grasp-consensus-1787961315.md`, debate-gate artifact.
**Status:** ⚑ REV 2 DRAFT — becomes the ratified PRD addendum on explicit owner sign-off.
Ratified so far (owner, 2026-08-28): AP combat may evolve Gate-T; world-map travel
supersedes FR-503; plus the four Wave-0 rulings below.

## Goal (verbatim)

> "we need to make this game play flow and function MUCH more like fallout 2"

Adopt Fallout 2's *loop*, not its literal systems:
*explore → notice opportunity → choose a build-specific approach → spend time/resources →
face interruption or failure → loot → see the world remember → choose the next destination*.
No anatomy called shots, no ammo simulation. Discover finding: the subsystems exist; the
connective tissue between them does not.

## Wave 0 — Ratified contract (decisions, not code)

Owner rulings taken 2026-08-28 at the debate gate:

1. **Enemy full-AP: YES, flag-gated.** Wave 1 implements full-AP enemy turns behind a
   `CombatRules` flag; it flips on only after a documented balance pass of the affected
   encounters (evidence: `combat_number_sweep` deltas + per-encounter win/loss sim notes).
2. **Check visibility: TAGGED, NO NUMBERS.** Skill-checked responses carry a
   `[#skill=persuasion]`-style tag rendered like existing cost/consequence tags
   ("[Persuasion]"); success chances stay hidden. Locked/visible behavior follows the
   existing dialogue-balloon convention.
3. **Unused-AP payoff: YES, small capped bonus.** Ending a turn with AP ≥ 1 grants a
   modest defensive/Balance term, hard-capped so turtling never beats acting; the value is
   PROVISIONAL (balance flag, not canon).
4. **Renown/Karma: remain distinct** (spec default carried forward; final ratification of
   this document affirms it explicitly). No merge with each other or the Soul Gauge.

Also part of Wave 0 (documentation, lands with Wave 1's PR):

5. **Gate-T criterion 10 amendment.** The recorded criterion "AP→CT migration
   completeness" is formally amended to its inverse: *CT→AP promotion completeness* —
   both schedulers remain behind the seam and scheduler-compat tests keep passing, but AP
   is the shipped default for all encounters. `docs/qa/gate-t-current-evidence.md` gets a
   dated amendment note; nothing is silently obsoleted.
6. **Region E under AP.** The six-region topology is frozen; Region E (`CTTimelineRegion`)
   keeps its node and contract but renders AP-round order when the scheduler is AP: seat
   order for the current round with per-actor acted/pending state and remaining-AP pips,
   fed by the same `peek_order`/snapshot channel (payload keys additive; CT rendering
   preserved for CT battles in tests/NG history).

## Keep / Evolve / Replace map

| System | Verdict | What changes |
|---|---|---|
| Five-layer architecture, Resolution purity, forecast==resolution | **KEEP** | Nothing. New mechanics are context in, writes out. |
| Scheduler seam (`TurnScheduler.create_default()`) | **KEEP** | AP already default; seam untouched; CT code stays. |
| Five CT encounter overrides (`encounter_catalog.gd`) | **REPLACE** | Removed *in the same wave* as the enemy-AP balance pass, not before (debate-gate blocking issue 2). |
| `ApRoundScheduler` enemy turns | **EVOLVE** | Full-AP enemies per Wave 0 ruling 1. |
| Battle command surface (`ui/screens/battle.gd`, six regions) | **EVOLVE** | AP cost on every command label; prominent End Turn button; Defining Strike = pick weakness → forecast cost/chance/effect → confirm, selected weakness passed as ordinary context into `Resolution.resolve()`. Additive contract changes only. |
| Forfeited AP | **EVOLVE** | Capped defensive/Balance payoff per Wave 0 ruling 3. |
| `FastTravelRegistry` + `region_map.tscn` (FR-503) | **REPLACE** (ratified) | Geographic overworld: coordinates/routes as data, moving party marker, proportional WorldClock advance, discovery fog, serializable `TravelPlan` owned by GameFlow, encounter interruption + resume. GP toll removed. |
| `EncounterCatalog` | **EVOLVE** | Systems-layer encounter director samples route/terrain/elapsed-time tables; avoidance prompt uses party's best `survival` skill (95% cap semantics from SkillCheck). |
| `SkillCheckService` | **KEEP** | Already correct. |
| Production dialogue | **EVOLVE** | Tagged checks (Wave 0 ruling 2): availability may preview via deterministic `check()`; exactly one committed `resolve()` on selection; authored success AND failure branches. Failure must not soft-lock the campaign; it MAY meaningfully close a path (debate-gate correction — "no dead ends" means no softlocks, not cosmetic failure). |
| `Reputation`/`Renown` ledgers, Standing screen | **KEEP** | Untouched. |
| Consequence surfacing | **EVOLVE** | Compact non-numeric in-moment notice bound to ledger events; consumers: vendor prices, ambient NPC lines, access/hostility, and encounter composition (restored per debate gate). |
| `Pickup` walk-over auto-grab | **EVOLVE** | Interaction-based inspect-and-choose. |
| `Chest` grant-all | **REPLACE** | `LootableContainer`/corpse adapter over GLoot: two-sided view, take-selected/Take All, exactly-once grants, save-persistent state. |
| Location gating / exits | **EVOLVE** | Four existing top-level areas on the overworld; selected hard locks become danger/information warnings; out-of-order evidence tolerated. No new regions until #93. |

## The feel gate (end-to-end acceptance, from the debate gate)

A single scripted-plus-manual acceptance run, first executable after Wave 3 and required
before final Deliver:

> From a **new game**: open the overworld → commit to a route → get an encounter
> interruption → use Survival to **avoid** one and **enter** another → win an AP battle
> using visible costs + End Turn + a confirmed Defining-Strike weakness pick → collect an
> **inspectable post-battle spoil** → resolve a dialogue beat through a **build-gated
> tagged check** (one success, one failure route) → see the ledger change surface as an
> **in-moment notice and a changed vendor price** → choose the next destination.

Run with two contrasting builds (talk-build vs fight-build) and one failed-check route.
Automated where headless allows (e2e suite extension); the remainder is a scripted manual
checklist under `test/manual/`. This gate is what distinguishes the loop from "six
disconnected feature imitations."

## Waves — vertical slices with enumerated acceptance

Reordered per the debate gate: each wave carries a thin slice of its consumers so
intermediate builds are never punitive-without-reward or cosmetic.

**Wave 1 — AP combat rhythm (+ Gate-T/Region E paperwork).**
Scope: AP costs on all command labels; End Turn button; Defining Strike selection flow;
unused-AP payoff (capped, PROVISIONAL); enemy full-AP behind flag + balance pass of the
five ex-CT encounters; CT overrides removed with that pass; Gate-T amendment note;
Region E AP rendering.
Accept: suite green; scheduler-compat tests still pass for CT; `combat_number_sweep`
byte-identical for untouched rules paths; forecast==resolution holds for weakness picks
(unit-tested); screenshot sweep shows costs/End Turn/Region E AP order; six-region
contract diff is additive-only (reviewed against the frozen contract note); balance-pass
evidence file committed.

**Wave 2 — World-map travel loop (+ thin loot beat).**
Scope: TravelPlan (origin/destination/progress/elapsed/seed) serialized in the save
envelope (schema bump + migration + fixture); marker animation from pure travel
snapshots; proportional clock with per-route time formula recorded in data; encounter
director with authored cadence bounds (min/max encounters per route tier) and a seeded
deterministic RNG stream; Survival avoidance prompt; interruption → battle → resume;
cancel/turnaround mid-route; defeat and quit/reload mid-journey; arrival day/night pass-
through. Thin slice from Wave 5: victorious travel encounters yield an inspectable spoils
container (adapter MVP), exactly-once.
Accept: travel round-trip playable from new game; save/reload at every journey state
(en-route, prompt, battle, post-battle) resumes correctly (integration-tested with the
seeded stream); avoidance respects skill and caps; risk display now derives from the real
table; spoils grant exactly once under reload (regression test); suite green.

**Wave 3 — Dialogue checks + quest verbs (+ one reputation consumer).**
Scope: check plumbing per Wave 0 ruling 2; retrofit an enumerated quest set — the ten Dom
side quests (`quests/dom_*`), each gaining ≥2 build-expressive acquisition verbs and
authored failure continuations; softlock audit rule added to `tools/quest_audit.gd`
(every check node reachable→resolvable on both branches). Thin slice from Wave 4: the
exemplar quest's outcome visibly changes one vendor's prices via faction band.
Accept: quest audit clean including the new rule; zero RNG consumed during choice
display (unit-tested); e2e exemplar passes both verb routes and one failure route;
canon: every new branch touching lore facts gets a vault-review line item in the PR
(no unreviewed canon, per boundary).

**Wave 4 — Reputation reactivity.**
Scope: consequence-notice component (ledger-event-driven, no new write paths); consumers:
all existing vendors price by faction band; ≥3 ambient NPC acknowledgements across Dom;
≥1 access/hostility gate; encounter-director composition reads Renown/faction band for
≥1 route table.
Accept: enumerated consumer list demonstrably live (integration tests per consumer);
notice appears once per event, non-numeric; suite green.

**Wave 5 — Lootable world.**
Scope: adapter generalized (containers + corpses); authored drop tables on encounter
data; interaction pickups replace walk-over; scavenging pass across the enumerated
existing-scene set (all 26 current world scenes reviewed, placements recorded in an
evidence file); ownership flag on containers — taking marked-owned goods writes a
Reputation event (theft consequence, no new mechanics beyond the ledger).
Accept: zero grant-all chests remain (repo scan); battle victory yields inspectable
spoils everywhere; exactly-once + persistence regression tests; economy sanity note
(total placed value vs shop prices) committed; suite green.

**Wave 6 — Open structure. ENTRY CONDITION: recorded #93 sign-off** (playtest packet
executed with outside testers). Until then, only order-tolerance work inside existing
scenes may land (hard-lock→warning conversions listed and canon-reviewed; out-of-order
evidence convergence tested by the quest audit's reachability rules).
Accept (for the in-scope part): enumerated lock conversions shipped; quest audit proves
out-of-order completion for the retrofitted quests; no softlocks (audit rule from Wave 3).

**Wave O — Opening sequence (RATIFIED BY OWNER 2026-08-29, added after REV 2).**
The New Game arc must play like Fallout 2's opening: character creation →
intro narration → a diegetic tutorial gauntlet → an elder hands over the
driving quest → released into the hub with the world map live. Owner rulings:
(1) FULL arc; (2) the gauntlet is skippable via a checked speech line at its
entrance; (3) the quest-giver is a Council of Four Arms elder — quest text
drafted from the Chapter 1 PRD and flagged for owner canon review before merge.
Scope: intro-narration screen (text over existing art, skippable, no binary
deps); gauntlet inside the EXISTING Lower Trial Hall interior (movement beat,
one forced encounter, a skill-check door, a keeper you can fight OR talk past —
Wave 3 check convention); council-elder quest handoff in the existing council
chamber; New Game flow reroutes chargen → intro → gauntlet → Dom. No new
macro locations (the #93 region gate is untouched).
Accept: full opening playable end-to-end in an e2e test (both keeper routes);
speech-skip proven; the driving quest live in QuestRegistry with ≥2 routes per
the Wave 3 convention; canon-review flags on all new prose; suite green; quest
audit clean.

**Wave P — Positional combat (RATIFIED BY OWNER 2026-08-29, added after REV 2).**
Battles must stop being stationary slugfests: positioning and line of sight are
the Fallout 2 core. Owner rulings: (1) tactics activate on the CURRENT square
grid now — a hex conversion is a separate later wave through the FR-105
battlefield-model seam; (2) ALL four rules ship: AP-costed click-to-move on the
battle stage, LOS gating ranged actions (existing refusal taxonomy surfaced in
the forecast), real terrain cover (grid model currently hard-returns 0), and
the already-stubbed flank/facing bonus consumed; (3) runs in PARALLEL with
Wave O (disjoint surfaces: combat core vs flow/scenes).
Constraints: frozen six-region battle contract — additive only; Resolution
purity and forecast==resolution preserved (cover/LOS/flank feed the existing
positional-context channel); enemy full-AP flag stays OFF.
Accept: player move action exists and costs AP; a blocked shot is refused with
its reason in the forecast BEFORE commit; cover/flank visibly change forecast
numbers; enemy turns use position (seek cover / flank when cheap); combat
number sweep re-run with a balance evidence file; suite green; gate PROCEED.

Wave P implementation note (subtask 2): battlefield pointer controls are additive
to the COMMAND rail. The stage consumes controller snapshot `movement.reachable`
quotes, preserves destination handles unchanged when committing, previews the
selected attack through `forecast_action`, and ignores clicks outside `ALLY_TURN`.
Cover markers are procedural; refusal, cover, and flank copy comes from controller
payloads rather than UI combat arithmetic.

## Boundaries (binding)

- Five-layer architecture and Resolution purity preserved; forecast==resolution.
- Frozen six-region battle contract: additive changes only (Wave 0 item 6 defines
  Region E's AP behavior inside that constraint).
- No region-content merges until #93 passes; #93 and FR-904 stay human-gated.
- No silent canon resolution — branch-level vault review is a per-PR acceptance item
  (Waves 3/5/6), not a general aspiration.
- Every wave lands on `main` with tests, suite green, quest audit clean.
- Gate-T evolves by written amendment (Wave 0 item 5), never silently.

## Delivery log

- **Wave 1 — SHIPPED 2026-08-28** (`2f9762d` → `6a6abcd`). Suite 887/0; quest audit
  0 errors; develop→deliver gate PROCEED_WITH_RISKS (manual codex dispatch, see
  `embrace-gate-develop-deliver-manual-1787969714.md`); evidence
  `docs/qa/wave1-acceptance-evidence.md` + `docs/qa/wave1-ap-balance-evidence.md`.
  Accepted residuals: cosmetic "CT n" plate label under AP; enemy full-AP flag
  remains OFF pending its own balance pass; branch unpushed (owner decision).

- **Wave 2 — SHIPPED 2026-08-29** (`71b77c0` → `ef98794`). Suite 920/0 (CI-style
  908/908 independently reproduced by the gate); quest audit 0 errors;
  develop→deliver gate REVISE → REVISE (docs-only) → **PROCEED**
  (manual codex dispatch, `embrace-gate-wave2-manual-*.md` r1–r3); evidence
  `docs/qa/wave2-acceptance-evidence.md` + `docs/qa/wave2-world-map.png`.
  Accepted residuals: encounter/spoils tables are PROVISIONAL balance surfaces;
  DOM current-location marker renders faint (cosmetic); an IN_BATTLE reload
  re-offers the encounter prompt (deterministic, not a reroll); branch unpushed
  (owner decision).

- **Wave 3 — SHIPPED 2026-08-29** (`2dd9632` → `3d6c19d`). Suite 938/0; quest audit
  0 errors incl. the new `check_softlocks` rule; develop→deliver gate REVISE →
  **PROCEED** (manual codex dispatch, `embrace-gate-wave3-manual-*.md` r1–r2);
  evidence `docs/qa/wave3-acceptance-evidence.md`. Went beyond the enumerated
  minimum: all ten Dom quests retrofitted, eight distinct skills; vault-review
  items: none (all names/facts pre-exist). DISCOVERY: faction-band vendor
  pricing and the band-gated trade/access gate already exist in production —
  Wave 4's vendor and access consumers are satisfied by test coverage, not new
  code. Accepted residuals: check difficulties PROVISIONAL; `check_softlocks`
  heuristic limits documented; branch unpushed (owner decision).

- **Wave 4 — SHIPPED 2026-08-29** (`65f8866` → `20d87f3`). Suite 948/0 (149 suites);
  quest audit 0 errors; drift check green; develop→deliver gate REVISE → **PROCEED**
  (manual codex dispatch, `embrace-gate-wave4-manual*-*.md` r1–r2); evidence
  `docs/qa/wave4-acceptance-evidence.md`. Shipped: consequence-notice HUD on both
  ledgers; three ambient townsfolk acknowledgements authored via Pandora
  (`Dialogue Hostile`/`Dialogue Warm` schema properties → generator emission into the
  GENERATED `dom_townsfolk.dialogue`; a hand-edit of that file was reverted in favor
  of the pipeline — `351803b`); band-aware travel-encounter weighting
  (schedule-build-time only, determinism preserved, schedule-level regression tests).
  Vendor band pricing and band-gated trade access were pre-existing production paths —
  accepted as satisfied via non-vacuous test coverage (`test_vendor_pricing.gd`,
  `test_vendors.gd`). Accepted residuals: `band_encounter_weights` values, notice
  wording, and reactive-NPC selection are PROVISIONAL balance/content surfaces; band
  reactions re-evaluate at dialogue/schedule start, not mid-conversation; branch
  unpushed (owner decision).

- **Wave 5 — SHIPPED 2026-08-29** (`594a08c` → `b73348c` + follow-ups `d0eebc2`,
  spoils-invariant test). Suite 963/0 (153 suites); quest audit 0 errors;
  develop→deliver gate **PROCEED_WITH_RISKS** (manual codex dispatch,
  `embrace-gate-wave5-manual*-*.md`); evidence `docs/qa/wave5-acceptance-evidence.md`.
  Shipped: shared inspectable `LootPanel` (take/take-all, capacity refusal leaves
  rows in the source); persistent containers via additive `GameState.loot_containers`
  (no schema bump); pickups became E-to-take interactions; `BattleResult.spoils` +
  `EncounterCatalog.roll_spoils` make victory spoils inspectable in ALL battles
  (travel keeps per-slot determinism + exactly-once); `owned_by_faction` theft =
  one `Reputation.record` per opened-panel session; 11 placements across 10 of the
  26 scenes (15 recorded no-place), zero grant-all containers (scan in evidence),
  economy note 225 GP placed vs 250 starting GP. Both gate-recorded drift risks
  were closed same-day: the container-id scan now enumerates `world/` from disk,
  and an invariant test forces every generated encounter to carry an authored
  spoils table. Accepted residuals: contents/values/theft delta PROVISIONAL;
  `roll_spoils` is fixed per encounter id (variety needs an owner entropy ruling);
  no lingering field corpses (battle is an overlay — deliberate).

- **Wave O — SHIPPED 2026-08-29** (`0e754db` intro/flow → `910eeca` gauntlet →
  `44ebea6`/`b0b61a5` elder+quest, gate-r1 revisions `0add5a4`). Suite 988/0 (solo
  run at `0add5a4`); quest audit run in reporting mode: **0 grammar violations,
  0 errors, 18 warnings** (all pre-existing `outcome_count`-class findings shared
  with the accepted Wave 3–5 quests; strict mode by design exits non-zero on any
  warning, so "strict exit 0" is not a claim this log makes). Gate r1 REVISE →
  all five findings closed: LocationRegistry id-only resolution (ExitToDom
  softlock), all flags renamed into the registered `tutorial_` domain (no
  LEGACY_FLAGS additions; no shipped saves carried the old names), e2e now proves
  speech-skip + keeper-TALK + keeper-FIGHT arcs against the REAL TravelExit
  (unlocked AND resolved to Dom), suite health substantiated from solo-run
  reports, chargen → intro made authoritative in this document. Shipped: intro
  narration screen (4 diegetic beats), `Menus/IntroNarration` flow state with
  save-load bypass, Lower Trial Hall gauntlet (aide speech-skip insight-40,
  switch beat, flag-guarded trial-warden encounter, key-or-check skill door,
  keeper TALK/FIGHT, exit gated on `tutorial_gauntlet_complete`), Council elder
  Themka Gaath handing the Dorthkor Road driving quest (insight-40 verb + direct
  route; Coiljaw field offer intact as route 2), first-arrival council nudge.
  All new prose `PROVISIONAL — CANON REVIEW REQUIRED`. Trial encounters grant
  zero reputation (trial, not deed) and carry authored spoils.

- **Wave P — SHIPPED 2026-08-29** (P1 `3ca7512` positional core → P2 `96fb25d`
  click-to-move stage → P3 `56d4523` enemy positional AI, gate-r1 revisions
  following). Evidence `docs/qa/wave-p-acceptance-evidence.md` (rule→proof
  table; the numbers-unchanged claim is stated precisely — the constants sweep
  proves only constant identity, encounter-level invariance rests on the
  zero/OFF-state tests plus the fact no authored encounter carries cover
  terrain yet). All four ratified rules on the current square grid, hex
  deferred to the FR-105 seam: player ACTION_MOVE priced by `move_query`
  (hover quote == commit spend), LOS gating ranged actions at forecast AND
  commit with the FR-606 taxonomy, defender-anchored directional cover,
  flanking via the ratified facing multipliers (flat flank term zeroed under
  positional context — forecast_action's missing guard was gate r1 finding 1,
  fixed by centralizing all three call sites on `_positional_terms()` with
  side/back parity tests). Region D shows the controller-quoted damage number
  (gate r1 finding 2 — it previously recomputed through a Resolution context
  that carries no cover term, so cover never moved the number). Enemy AI
  seeks cover (+750 PROVISIONAL, between adjacency +500 and rear-flank
  +1000), routes around blocked lines, force-passes with the model refusal
  instead of attacking through a refused target_query (grid only; zone
  fall-through preserved); position tie-break made genuinely lexical
  (StringName `<` is interning-pointer order). Command rail unchanged;
  six-region contract additive; scheduler #193 and the enemy full-AP flag
  untouched. Suite after r1 revisions: 996/0 (solo run). Gate: r1 REVISE (three
  findings, all real, fixed at `e8cd925`) -> r2 **PROCEED** (no blocking findings;
  parity, region-D number, and evidence scope all verified against the tree).

- **Wave P follow-up (P4) — "grid by default" — SHIPPED 2026-08-29.** Owner ruling
  after playtest report "combat screen is still just blank": the two trial
  encounters (and any future catalog encounter authoring no grid) fell back to
  the zone model, which the six-region stage does not render — blank center
  stage in real play. Fix: `Battle._battlefield_for_definition()` synthesizes a
  PROVISIONAL default grid `7 × max(5, rows)` for any catalog definition with a
  missing/empty/invalid grid block (invalid grids keep their warning); authored
  `grid.dimensions` still win. Zone stays a live FR-105 fallback two ways: the
  explicit `"battlefield": "zones"` definition hatch and ad-hoc
  `start(BattleActor)` scaffold battles (empty definition — test/debug surface,
  unreachable from authored content). Evidence: 7-case
  `test/test_battle_default_grid.gd`, suite 1004/0 on merged main, xvfb
  screenshot `23_battle_grid.png` visually confirmed (grid tiles + deployed
  units + all six regions). Gate: r1 **PROCEED_WITH_RISKS**, no blocking
  findings; accepted residuals on record: (1) before per-encounter grid
  dimensions move into generated JSON (the later content pass), the catalog
  must normalize a JSON-safe dimensions representation to `Vector2i` — today
  only the GDScript `_FIELD_GRID_DATA` overlay supplies dimensions, already
  typed; (2) the zone-fallback tests assert via capabilities rather than the
  concrete type — deliberate, the zone model's contract forbids consumers
  naming its type; (3) push_warning emission on invalid grids is not
  test-pinned (gdUnit has no warning capture).

- **Wave Q — grid-bound overworld movement — SHIPPED 2026-08-29** (owner request:
  "movement bound to a similar kinda grid in town... WASD/arrow keys but along the
  grid"; ratified via plan questions: 8-direction screen-relative, EVERYTHING on
  the grid, smooth continuous steps). WASD/arrows step cell-to-cell on the shared
  overworld `IsoGrid` (the same lattice click-to-move and the tactical layer use):
  input resolves to the iso neighbor whose world direction best matches, held keys
  glide with no pause, the player always rests exactly on a cell center, blocked
  steps glide along walls via the two angularly-nearest alternatives (corner-cut
  rule for cell-space diagonals). Click paths complete through the same
  authoritative snap. NPC/enemy/routine placements snap at APPLY time
  (`world/nav/grid_placement.gd`: clearance-0 grid — raw painted passability, not
  the mover-dilated pathing grid — and a bounded ≤2-cell snap; the authored stand
  wins when nothing nearby is open; authored coordinates untouched). Party
  followers trail the player's cell history. **Lattice-open semantics**
  (`IsoGrid.is_step_blocked`): the iso lattice extends beyond the painted region —
  unpainted ground is open for stepping/placement (parity with the free-movement
  era; Dom authors 24 of 30 townsfolk on unpainted dirt), while A*/click pathing
  stays region-bounded. Movement is bounded by camera-bounds ∪ painted-map world
  extent (+64px), with a re-entry escape valve. Keyboard steps carry bounded
  wedge recovery (progress-toward-target, 0.35s, snap back to the exact begin
  position); `Player.rest_on_grid()` normalizes spawn/loaded positions with a
  `test_move` collision sweep (a stored legal position beats normalizing through
  a wall). Suite 1019/0; town screenshot verified (townsfolk clustered naturally
  on centers). Gate: r1 REVISE (wedge, load normalization, test hardening — all
  fixed, plus the painted-rect discovery above) → r2 REVISE (swept load snap,
  movement bounds, occupancy root-scoping, progress-based wedge — all fixed;
  camera-bounds-only clamp corrected after the full suite caught negative-x
  painted cells refused) → r3 **PROCEED_WITH_RISKS**, no blocking findings.
  Accepted residuals: static NPC/enemy placement is not physics-swept (2-cell cap,
  stable authored data); bounds regression covers one side + re-entry (coverage
  debt, geometry verified); **pre-existing product bug, now issue-tracked: a
  LOCKED travel exit does not physically close its boundary-collider gap** (free
  movement could always walk through; movement is now at least bounded). Step
  speed/PROVISIONAL values: `speed` 260, sprint ×2, stuck threshold 0.35s,
  bounds margin 64px, MAX_SNAP_CELLS 2.

- **Wave R — battlefield authoring pass — SHIPPED 2026-08-29** (owner direction: the
  battle map "definitely needs expanding and fleshing out"). All 12 catalog encounters
  now carry authored boards in `EncounterCatalog._FIELD_GRID_DATA` (7×5–9×6, replacing
  the ten Gate-T-era 2×4 overrides; trial-warden + trial-keeper added) with 2–5 themed
  cover cells and 0–4 elevation cells (bog tussocks, Dorthkor wagon cover/embankments,
  jawbrace barricades, trial-hall pillars); deployment columns 0 and last stay clear by
  convention AND by test. `Battle._apply_authored_terrain()` applies cover/elevation
  with warn-and-skip validation (malformed or out-of-bounds cells never abort a battle)
  and clamps elevation to `DS.ELEVATION_MAX`; authored cliffs are deliberately
  unsupported until the stage has a cliff visual (invisible walls are a UX bug).
  `_WEATHER_DEFAULTS` gained its first three entries (bog-wight: molm, loam-boar:
  terra, phase2-demon: scor). `test/test_battlefield_authoring.gd` enforces the data
  invariants directly (bounds, elevation range 1..MAX, no duplicates, clear deployment
  columns, every encounter deploys a full 5-member party on distinct cells, weather ids
  valid + warning-free). Consequence-flow suites (test_battle, field-debt and
  first-chapter journeys) pin their encounters to the FR-105 `"battlefield": "zones"`
  hatch — their subjects are authored outcomes, not grid tactics — and every
  strike-until-ended loop is now budgeted (40 swings) after an unbudgeted one hung a
  30-minute run when the new boards deployed melee at range. Suite 1023/0; trial-warden
  screenshot verified (pillars, cover badges, clear columns). Gate: r1
  **PROCEED_WITH_RISKS**, no blocking findings; the sharpest risk (catalog typos
  warning-skipped without test failure) was closed same-session by the invariant test.
  Accepted residuals: zone-pin fixtures erase rather than snapshot-restore the
  `battlefield` key (safe while generated definitions never author one); ~~no test yet
  walks a real authored board through legal movement into combat~~ — closed same
  evening: `test_bog_wight_board_supports_movement_into_melee_victory` plays the real
  bog-wight board (live molm weather) through snapshot-driven legal moves into melee
  victory via the facade; `tools/combat_number_sweep.gd` cannot see weather defaults (it
  is a static sweep that does not read EncounterCatalog) — before/after was
  byte-identical, recorded honestly in the table comment. ALL board dimensions, terrain
  placements, and weather picks are PROVISIONAL balance content awaiting the owner
  balance pass; `EncounterCatalog._WEATHER_DEFAULTS` remains the authoring surface for
  the other nine encounters.

- **Wave S — chargen wizard + painterly likeness gallery — SHIPPED 2026-08-30** (owner
  mandate: "keep improving the graphics and developing the character creation flow";
  rulings: illustrated multi-step wizard, painterly portrait gallery, Seven Measures
  header stays — DRAMGID-7 planned/unratified, see `docs/chapter-one-open-questions.md`).
  The Register of Persons is now a seven-page wizard (Ancestry → Calling → Elements →
  Attributes → Skills → Identity → Summary) with per-step gating from `ChargenData`,
  step rail, keyboard/gamepad focus wiring, and unchanged accept semantics (player
  boot flow + tavern RECRUIT mode). `ChargenArtResolver` prefers painterly plates and
  falls through to the paired crowd field sprite at the TEXTURE level (a corrupt plate
  can never blank the gallery or the member — gate r1 required finding, fixed).
  `ChargenData.LIKENESSES` pairs ten new plates (2 per ratified ancestry, image_gen per
  the aesthetics bible; canon notes in `assets/generated/chargen/_contact_sheet.md`)
  with crowd sprites; legacy unit-id likenesses keep resolving. Five ancestry panel
  illustrations landed at `assets/generated/chargen/ancestry_<id>.png`. Screenshot
  sweep photographs three wizard pages (`02a/02b/02c`). Suite **1034/0**; gate r1
  REVISE (corrupt-plate fallback, production-path cancel test, real gallery-selection
  parity — all fixed) → r2 **PROCEED**. Residuals: one teardown-time
  `test_battle_pointer_controls` flake observed once (passed 3/3 solo + clean full
  rerun; pre-existing suite, untouched); Vaerin/Kaan physical canon gaps are flagged
  interpolations in the contact sheet — HUMAN canon review before treating the plates
  as ancestry-defining.

- **Wave T — painterly battle cover props — SHIPPED 2026-08-30** (graphics campaign,
  "Battle terrain art" priority). Five 512×512 transparent painterly cover props
  (`assets/generated/sprites/terrain/cover_{bog,road,barricade,pillar,generic}.png`,
  image_gen per the aesthetics bible, upper-left light) now stand on authored cover
  cells in the battle stage: `BattleStageRegion._sync_cover_props()` maintains
  bottom-anchored TextureRects in UnitsLayer, theme-mapped per encounter prefix
  (dorthkor→road, bog/loam→bog, jawbrace→barricade, trial→pillar, else generic) with a
  per-theme texture cache and themed→generic fallthrough. Depth is painter's order over
  units AND props (`_apply_painter_order()`), re-invoked from every movement-tween
  waypoint/finish and on prop-only snapshots (gate r2 required finding, fixed); ground
  overlays (reachable/path tints) stay in the ground pass; the legacy gold badge draws
  only when no prop art resolves. Art existence gates are export-safe —
  `ResourceLoader.exists(path) or FileAccess.file_exists(path)` plus post-load
  Texture2D validation — in the stage AND retrofitted into `ChargenArtResolver`
  (`_art_exists`), which had the identical PCK-remap gap (gate r1 required finding,
  fixed). The screenshot sweep suppresses the modal `RewardReveal` before every capture
  (it had photobombed two shots). Suite **1037/0**; gate r1 REVISE → r2 REVISE
  (painter-order staleness) → r3 **PROCEED_WITH_RISKS**. Residual (non-blocking,
  r3): the movement test asserts only the final index flip, so it would not catch
  removal of just the intermediate-waypoint callbacks. All prop placement/sizing values
  (`COVER_ART_TILE_WIDTHS` 1.35) are PROVISIONAL balance/feel surfaces.

- **Wave U — lived-in townscape — SHIPPED 2026-08-30** (graphics campaign, the owner's
  own added priority "Townscape needs to feel more lived in"). Tangle-built, salvaged
  from `octopus/run/1788070276-1999336`. `world/starting_town.tscn` gains
  `TownscapeDressing` (GroundDetails flats at z −2 / SoftDetails y-sorted / SolidProps
  with street-scale collision): ~40 decorative instances wiring all 13 previously
  unused dom-* sprites with intent (market clutter, braziers along streets, trees on
  wall lines, puddles+mud at the waterline, grates on roads). `AmbientTownsfolk` adds
  8 non-interactable wandering crowd figures (`actors/ambient_villager/`, group-tagged,
  PAUSABLE, waypoint-bounded, no physics body); `world/ambient_prop_motion.gd` sways
  lanterns and flickers braziers deterministically. Braziers sprite-scaled 0.45 after
  visual QA (full-frame cauldron art towered over facades at native size). Suite
  **1039/0** + new lived-in suite 3/0 (instantiation, 360-frame containment, and a
  wander/motion-actually-happens test closing gate risk 2); sweep 11/0 with the town
  shot visually verified. Gate r1 **PROCEED_WITH_RISKS** (both risks addressed:
  additive startup pause documented as deliberate stagger; movement/motion test
  added). All placements/routes/counts PROVISIONAL owner-balance surfaces.
  CORRECTION (same session): the white rectangles in the town shot were first
  misread as legacy NPC-plate debt; they are actually FOUR OF THIS WAVE'S OWN
  ground decals — dom-{puddle--shallow,mud-edge--transition,stone-paving--tile,
  wet-road--tile}.png were authored on opaque white backgrounds (which is why no
  scene had ever wired them). Regenerated in place with true transparency via an
  art lane; town shot re-verified.

- **Wave V — Wound Lip visual build-out — SHIPPED 2026-08-30** (graphics campaign,
  world/field polish). Tangle-built, salvaged from `octopus/run/1788073176-2037152`.
  The ColorRect blockout became a dressed scene: `WoundLipDressing` layers damp-stone/
  ash ground, the wound-seam + void-cut band with fractured ledges and brace-metal,
  and the four jawbrace props with collision — all 10 previously-unused jawbrace/*
  assets wired. `ambient_prop_motion.gd` gained WOUND_BREATH (slow modulate pulse —
  the wound breathes). Root y-sort added at gate r1 (actors depth-sort with props);
  `test/integration/test_wound_lip.gd` pins the gameplay contract AND a dressing
  contract that fails against the old blockout. The QA sweep gained `24_wound_lip`
  plus a structural fix: the seeded save restores the player's TOWN position into
  every cold-loaded field scene and earlier runner scenes' cameras stayed current, so
  Dorthkor photographed an empty corner and Wound Lip photographed void — `_shoot`'s
  `player_anchor` now repositions the player and reclaims the camera; both field
  shots re-framed on real content. Wound Lip's player also gained the `camera_bounds`
  the other field scenes had. Suite **1041/0**; sweep 11/0; gate r1 REVISE (root
  y-sort, blockout-proof tests) → r2 **PROCEED**. Placements PROVISIONAL. Composition
  note for the owner: the ledge reads as separated floating plates over the void —
  deliberate oppression vs. denser walkable stone is an open feel call.

- **Wave W — quest-giver portraits — SHIPPED 2026-08-30** (graphics campaign, portrait
  gaps). Nine painterly 512×512 neutral portraits for the Dom quest givers (Droma
  Flintjaw, Irka Stonebreath, Jorun Ashmantle, Keth Varr, Orren Chainwake, Pell
  Hammersong, Senn Brinehook, Vaara Cisternhand, Veska Ruun), matching the existing
  five majors' format; wired through the canonical pipeline only (seed_town_npcs
  PORTRAIT_PATHS → Pandora migration → generate_gloot). Also fixed en route:
  `NpcRoster.load_portrait_texture` used bare `FileAccess.file_exists` (portraits
  would vanish in exported builds — same class as the Wave T finding; now the
  export-safe OR-gate). ⚠ All nine designs are canon INTERPOLATIONS (no vault
  physical descriptions) — flagged in `_contact_sheet_wave_w.md`, joins the
  Vaerin/Kaan pile for human canon review. The remaining 47 roster speakers keep the
  intentional monogram card — extending portraits further is an owner scope call.
  Suite **1042/0**; gate r1 **PROCEED**.

- **Wave X — themed battle backdrops — SHIPPED 2026-08-30** (graphics campaign,
  battle terrain art). Every encounter family now fights somewhere: four new
  painterly backdrops (bog-marsh, jawbrace-ledge, trial-hall, wound-touched-field)
  join dorthkor-road, keyed off the encounter prefix by
  `BattleStageRegion._backdrop_theme()` exactly like the cover-prop theming, with a
  per-theme cache and the export-safe existence gate. Missing art degrades to the
  hidden backdrop (prior non-dorthkor behavior). Stage test transitions through all
  five themes without clearing the cache and asserts every committed backdrop
  resolves non-null (gate r1 risk closed same session). Suite **1043/0**; sweep
  11/0 — the trial-warden board renders inside the trial hall. Gate r1
  **PROCEED_WITH_RISKS** → risk closed. All four backdrops PROVISIONAL owner-review
  surfaces (`assets/generated/backgrounds/combat/_contact_sheet.md`).

## Outstanding for final ratification

- Owner sign-off on this REV 2 document as the PRD addendum (explicitly including the
  Renown/Karma separation affirmation, the Gate-T amendment wording, and the feel gate).
