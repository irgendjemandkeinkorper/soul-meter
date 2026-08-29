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

## Outstanding for final ratification

- Owner sign-off on this REV 2 document as the PRD addendum (explicitly including the
  Renown/Karma separation affirmation, the Gate-T amendment wording, and the feel gate).
