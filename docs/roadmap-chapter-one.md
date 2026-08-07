# Roadmap — Chapter One to Ship Quality

**Status:** **RATIFIED 2026-08-07** — owner sign-off. The milestone order is binding
**Date:** 2026-08-07 · **Owner:** Adam (solo dev)
**Language rule:** ASD-STE100. Game content is excluded. See
`docs/architecture-tactical-and-navigation.md` §7.
**Horizon:** D7 — Chapter One only. Later chapters get a sketch, not milestones.
**Session decisions:** `.claude/session-intent.md` (D1 to D8)
**Companion documents:** `docs/architecture-tactical-and-navigation.md` (the how),
`docs/prd-chapter-one.md` and `docs/prd-amendment-tactical-layer.md` (the what, both ratified)

---

## 0. Purpose and method

This roadmap replaces the 2026-08-07 planning brief. That brief described the repository as a
movement prototype. That description was wrong by approximately one year of work.

D1 asked for a reset of the roadmap. This document therefore derives the milestones from the
measured state of the repository. It does not derive them from `docs/prd-chapter-one.md` §7.

§7 of the ratified PRD stays valid as a statement of *scope*. Its *sequence* is now partly
obsolete. §1.3 below explains why, and §6 lists each divergence.

---

## 1. Measured state, 2026-08-07

### 1.1 What exists

| System | State |
|---|---|
| Flow, screens, save/load | Complete. State Charts root chart. Save schema 5 with migrations |
| Dialogue and consequence loop | Closed end to end. 7 dialogue files |
| Reputation, Renown | Both ledgers built and wired |
| Inventory | GLoot, integrated with `GameState` and the UI |
| Combat vertical | `CombatController`, `TurnScheduler`, `ChargeTimeScheduler`, `CombatRules`, action and identity catalogs, battle HUD |
| Turn economy | Charge time. FR-102a. Deterministic, serialized, tested |
| Locations | 4 top-level, 20 Dom interiors |
| Quests | 15 total. 10 are Dom side quests |
| Tests | 305 cases, 54 suites, 0 failures |
| CI | Import, acceptance gate, Pandora drift check, headless gdUnit4, Windows export |

### 1.2 What does not exist

| Gap | Evidence | Milestone |
|---|---|---|
| Pathfinding of any kind | `AStarGrid2D`, `NavigationServer2D`, `NavigationAgent2D`: **0 occurrences each** | M1 |
| Obstacle data in the world | `IsometricBlockout` generates ground only | M1 |
| `GridBattlefieldModel` | Only `zone_battlefield_model.gd` exists | M2 |
| Cells, elevation, facing, occupancy, LOS, path cost in the interface | The interface speaks `StringName` zone ids only | M2 |
| Companions | `personal_quest`: **0 occurrences**. FR-505 | M6 |
| Locations 5 to 12, hubs 2 and 3 | 4 of 8 to 12 locations. 1 of 3 hubs | M7 |
| Day/night clock, NPC routines | No clock. No routine. D6 wants both | M8 |
| Region map, fast travel | FR-503 | M9 |
| Mirror Shop | FR-801. `ng_plus.gd` holds data only | M10 |
| 9-patch styleboxes | FR-605. Corners are sharp | M10 |
| Soul Meter zero state | Canon defines it. No code implements it | M4, design first |

### 1.3 The gate — corrected 2026-08-07

**An earlier version of this section is withdrawn.** It claimed to find an unrecorded sequence
defect between Phase 1.5 and Gate T, and it proposed merging the two gates. The ratified
amendment had already recorded the defect and already made the merge. Amendment §5, line 471:

> **Phase 1.5 (#93) is superseded by Gate T, not cancelled.** Its slice text explicitly
> exercises "AP + at least one Defining Strike + zone facing + Balance Gauge" — three of those
> four no longer exist as written. Running it against a chassis being replaced would buy
> little; deleting it would leave content production ungated. Gate T inherits its go/no-go
> authority and its outside-playtester requirement.

The correct statement is therefore simple. **One gate exists: Gate T. It has ten criteria.**
Phase 1.5 is not a second gate and is not a second session.

**A second correction, larger in effect.** The earlier version treated the whole gate as
human-gated and built a schedule risk around it. Amendment §5.0 audited each criterion:

> **Exactly one criterion requires people who are not the author.**

Criterion 6, comprehension, needs 3 to 5 outside playtesters. The other nine are evidenced
headless: integration tests, fixed seeds, a save round trip, a benchmark script, and in one case
a grep. Recruitment blocks one criterion, not the gate.

### 1.4 Scope this roadmap omitted

An earlier version of this document did not mention the elemental tactical layer at all. That
was an omission, not a decision. The amendment puts it inside Gate T: criterion 3 requires
weather bias to visibly change the board, and criterion 8 requires tile charge and weather phase
to survive a save.

The work exists as GitHub issues in milestone **Tactical Layer T1**: `tile_state` (#139),
Weather (#140), attunement and jobs (#141), resolution as a pure function (#142), and
`element_matrix` (#136).

**`element_matrix` authoring is BLOCKED.** Amendment §10.1 says so directly: do not author
multipliers. Treat #136 as blocked until the owner unblocks it.

---

## 2. Milestone map

Eleven milestones. One blocking gate. §5 converts the sizes to calendar time.

```
M1 Navigation        S   ~1 wk    no gate
M2 Battlefield seam  M   ~1.5 wk  no gate
M3 Consequence tools S   ~0.5 wk  no gate
T1 Elemental layer   L   3-4 wk   tile_state, weather, jobs, pure resolution
M4 Slice assembly    M   ~1 wk    incl. Soul zero state (decided 2026-08-07)
─────────────────────────────────────────────────────────
M5 GATE T            L   3-4 wk   BLOCKING. 10 criteria. 1 needs outside humans
─────────────────────────────────────────────────────────
M6 Companions        L   ~3 wk    after M5. Needs the 3x10 sheet first
M7 Region content    XL  7-11 wk  after M5
M8 Living world      M   ~2 wk    FR-504a RATIFIED 2026-08-07
M12 World-state evo  M   3-4 wk   FR-507 RATIFIED. Blocked on vault lore
M9 Region map        S   ~0.5 wk  after M5
M10 Polish and NG+   M   ~2 wk    after M7
M11 Acceptance       S   ~1 wk    last
─────────────────────────────────────────────────────────
TOTAL                    25-38 wk at 28 h/week
```

M1 to M4 need no gate. They carry low risk. Together they are **3.5 to 5 weeks** of de-risked
work that you can start today.

---

## M1 — Navigation foundation

**Size:** S · **Risk:** Low · **Gate:** none · **Fleet:** Codex
**Requirements:** D4. Architecture doc §2.

Build the isometric pathfinding that the project has never had.

### Epic M1.1 — `IsoGrid`

Build the shared `AStarGrid2D` substrate. See architecture §2.2 for the full listing.

Definition of done:
- [ ] `world/nav/iso_grid.gd` exists. It builds from a `TileMapLayer`.
- [ ] The heuristic is `HEURISTIC_OCTILE`. Euclidean ranks isometric diagonals incorrectly.
- [ ] `diagonal_mode` is `DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES`. No path cuts a corner.
- [ ] `world_to_cell()` and `cell_to_world()` round-trip across the full map rect. Tested.
- [ ] `IsoGrid` has **no** dependency on `globals/combat/`.

### Epic M1.2 — Obstacle authoring layer

Definition of done:
- [ ] `starting_town.tscn` holds a `Blocking` `TileMapLayer` under `YSortRoot`.
- [ ] The blocking layer is the single source of truth. Both the `AStarGrid2D` bake and the
      physics collision derive from it.
- [ ] Buildings in Dom occupy blocking cells.
- [ ] A test proves that a path cannot cross a blocking cell.

### Epic M1.3 — Click-to-move controller

Definition of done:
- [ ] `actors/player/click_move_controller.gd` exists. `player.gd` keeps `CharacterBody2D`.
- [ ] A click paths the player around a building in `starting_town.tscn`.
- [ ] An unreachable click returns the refusal shape. It does not return silence.
- [ ] The controller recalculates the path when an obstacle changes.
- [ ] Footsteps still work. `facing_direction` still works.
- [ ] WASD still works as a debug path and an accessibility path.

### Epic M1.4 — Y-sort correctness

Definition of done:
- [ ] `y_sort_enabled` is true on the common parent. It is false on each sprite.
- [ ] The ground keeps `z_index = -10` and stays outside y-sorting.
- [ ] Each sortable sprite has its origin at the feet.
- [ ] A prop hides the player when the player stands above it.
- [ ] The player hides the prop when the player stands below it.
- [ ] The existing field-room movement, collision, and NPC-range tests still pass.

---

## M2 — Battlefield seam and the grid model

**Size:** M · **Risk:** Low · **Gate:** none (the grid stays inactive) · **Fleet:** Codex
**Requirements:** FR-105a. Amendment §2.1, §2.3, §8.1. Architecture doc §1.

Widen the interface. Add the grid model. Do not activate it.

**Boundary for the fleet: do not author grid maps or grid encounters in this milestone.**
Amendment §8.1 forbids that work before M5.

### Epic M2.1 — Widen `BattlefieldModel`

Definition of done:
- [ ] The interface adds `capabilities()`, `describe_position()`, `reachable_positions()`,
      `path_query()`, `facing_of()`, `set_facing()`, `line_of_sight()`, `occupant_of()`,
      `elevation_delta()`.
- [ ] Each new method returns the refusal shape or a safe default in the base class.
- [ ] `zone_battlefield_model.gd` has **zero** changes.
- [ ] All 305 tests pass. No test was modified.

### Epic M2.2 — `GridBattlefieldModel`

Definition of done:
- [ ] `grid_battlefield_model.gd` exists. It owns one `IsoGrid` from M1.
- [ ] Movement range uses a flood fill bounded by the CT budget.
- [ ] Elevation scales the path weight. A cliff is impassable, not expensive.
- [ ] Occupancy updates after each move and each death. Nothing caches across a turn.
- [ ] Line of sight uses cells and elevation. High ground sees across low cover.
- [ ] `line_of_sight()` separates `&"blocked_by_elevation"`, `&"blocked_by_occupancy"`, and
      `&"blocked_by_range"`. A single `&"no_los"` fails this epic.
- [ ] The model passes the behavioural suite that the zone model passes.

### Epic M2.3 — Prove the seam holds

This epic is the §8.1 stop-loss in test form. If it fails, stop and report.

Definition of done:
- [ ] `rg` proves that no consumer outside the model files builds or reads a position handle.
- [ ] No consumer calls `is_grid()`. No consumer casts to `GridBattlefieldModel`.
- [ ] The battle HUD branches on `capabilities()` only.
- [ ] A test proves `path_query().ct_cost == scheduler.quote()`. Test it as an invariant.
- [ ] A test proves that position, facing, elevation, and CT survive a mid-battle save.
- [ ] Path selection uses no RNG. Equal-cost paths resolve by lowest cell index.
- [ ] `CombatRules.use_grid_battlefield` exists and defaults to **false**.

---

## M3 — Consequence tooling

**Size:** S · **Risk:** Low · **Gate:** none · **Fleet:** Codex, or Gemini for the lint
**Requirements:** FR-501, FR-403, FR-802. Architecture doc §3.

The consequence system scales to hundreds of flags. Its diagnostics do not. Fix the
diagnostics before M7 multiplies the content.

### Epic M3.1 — Flag grammar

Definition of done:
- [ ] The grammar `<domain>.<subject>.<predicate>` is documented.
- [ ] `tools/quest_audit.gd` enforces the grammar.
- [ ] The audit fails on a flag that the code writes but never reads.
- [ ] The audit fails on a flag that the code reads but never writes.
- [ ] The audit passes on the existing 15 quests.
- [ ] The report states each limitation of the audit. Read that header before you trust green.

### Epic M3.2 — Dialogue condition lint

This epic has the highest value for its cost in the whole roadmap.

`DEPENDENCIES.md` records the defect: a response condition needs `[if expr /]`. The form
`[if expr]` silently does nothing. A broken consequence check therefore looks exactly like a
working one.

Definition of done:
- [ ] A lint scans each file in `dialogue/`.
- [ ] The lint finds each `[if]` in response position that is not self-closing.
- [ ] CI fails on a match.
- [ ] The lint runs against the existing 7 dialogue files and reports the result.

---

## M4 — Slice assembly

**Size:** M · **Risk:** Medium · **Gate:** one design decision blocks part of it
**Requirements:** PRD §7 Phase 1.5, amended by §1.3 above. Amendment §5.

Assemble the 45 to 90 minute slice that M5 tests. Build it from parts that already exist.

### Epic M4.1 — Update the slice definition

The ratified gate text names AP and zone facing. Both are retired. Correct the text.

Definition of done:
- [ ] The slice exercises: exploration with click-to-move, one dialogue skill check, one
      consequence-bearing side quest, one full tactical encounter, a save and load in the
      middle, and a mock NG+ rollover.
- [ ] The encounter uses **charge time, grid, elevation, and facing**. It does not use AP. It
      does not use zones.
- [ ] `use_grid_battlefield` is true for the slice build only.
- [ ] The change to the gate text is recorded as an amendment. Do not edit the ratified PRD
      silently.

### Epic M4.2 — Refusal coverage (FR-606)

FR-606 requires each blocked action to name the system that blocked it. The slice must show
this, because M5 asks the playtesters "why did that fail?".

Definition of done:
- [ ] Each refusal reaches the UI with a distinct `blocked_by`.
- [ ] The taxonomy separates Vär, Breath, CT, span cap, elevation, facing, occupancy, range,
      and weather bias. Amendment §2.2 lists these nine.
- [ ] Each refusal states the nearest unblock condition.
- [ ] A blocked cast that lacks Soul reports `blocked_by = &"soul"`.

### Epic M4.3 — Soul zero state ✅ DECIDED 2026-08-07

**This epic is unblocked.** The owner ruled: **husking-while-alive is a playable state.** Death
is not the outcome at zero.

Canon offered two readings — death, or husking-while-alive. The second was chosen because
FR-905 requires a failure-forward route, and because death at zero makes the Gauge a health bar
with extra steps. That teaches the player to hoard a resource the design intends them to spend.

The vault is the source of truth for this, so `cosmology/souls.md` carries the ruling. Read it
before implementing.

Definition of done:
- [ ] The ruling is written into the vault. `build_index.py` and `validate.py` are green.
- [ ] Reaching zero sets a husked state. It does not end the run.
- [ ] Casting is refused while husked, with `blocked_by = &"husked"`. FR-606 applies: the
      refusal names the system and the nearest unblock condition.
- [ ] A subset of NPCs reacts to the husked state. The reaction is authored, not generic.
- [ ] A recovery route exists. It is slow, partial and social, which is what canon says
      recovery is. It is not a potion.
- [ ] Recovery is partial by construction. The Gauge does not return to its pre-zero value.
- [ ] The husked state survives save and load.
- [ ] **No husked state can soft-lock the main quest.** FR-905. This is the criterion most
      likely to fail, because quest authoring can break it silently.

---

## M5 — GATE T ⛔ BLOCKING

**Size:** not sized · **Risk:** the highest in the project
**GitHub:** milestone `Gate T — Tactical vertical slice (BLOCKING)`
**Source of record:** amendment §5. This roadmap does not restate the criteria; it points at
them. The amendment is ratified and this document is not.

Ten criteria. All ten must pass. Each is binary and externally observable: it either passed or
it did not, and someone other than the author can check which.

| # | Criterion | Outside humans? | Issue |
|---|---|---|---|
| 1 | Five archetype encounters, four build archetypes | No | #168 |
| 2 | Falsifiable positional-depth test | Borderline | #169 |
| 3 | Three orphaned P0s work | No | #170 |
| 4 | CT-queue integrity, 8 or more combatants | No | #171 |
| 5 | Speech-interrupt determinism | No | #172 |
| **6** | **Comprehension** | **YES — the only one** | **#93** |
| 7 | Determinism | No | #173 |
| 8 | Save and load round trip | No | #174 |
| 9 | FR-904 performance floor | No | #175 |
| 10 | Migration completeness | No | #176 |

**Only criterion 6 needs outside humans.** `docs/playtest-protocol.md` holds the protocol and
the evidence template. Recruit 6 to 8 people to net 3 to 5 after dropout. Frame the ask as
"one 45-minute encounter and five questions".

Criterion 6 asks four questions. The pass threshold is a majority correct **per question, not
averaged**. Averaging lets one well-understood system carry a badly-understood one, which is
the exact failure the complexity budget exists to catch.

### If a criterion fails

Amendment §8.1 gives the stop-loss rules. Apply them. Set `use_grid_battlefield` back to
`false`. The zone model still works, because M2.1 never changed it. That is the whole reason
for the constraint.

**Do not merge region content into `world/locations/` or `LocationRegistry.ALL` before
criterion 6 passes.**

---

## M6 — Companions

**Size:** L · **Risk:** Medium · **Gate:** after M5 · **Fleet:** Claude writes, Codex wires
**Requirements:** FR-505.

`personal_quest` has zero occurrences in the repository. This system does not exist.

Definition of done:
- [ ] 3 to 5 of the 20 tavern recruits become full companions.
- [ ] Each companion has one personal quest.
- [ ] Each companion has battle barks.
- [ ] Each companion has abilities that matter to the Balance Gauge.
- [ ] At least one companion matches each ending-family temperament.
- [ ] Each personal quest writes to a ledger. The M3.1 audit passes.

---

## M7 — Region content

**Size:** XL · **Risk:** Medium · **Gate:** after M5 · **Fleet:** content waves, Claude reviews
**Requirements:** FR-501, FR-502, FR-506.

The largest milestone. It is also the most parallel.

Definition of done:
- [ ] Locations reach 8 to 12 top-level. The count is 4 today.
- [ ] Hubs reach 3. The count is 1 today.
- [ ] The main quest completes Act I and sets the Act II hook.
- [ ] Side quests reach 10 or more, each with 2 or more genuinely different outcomes. The count
      of Dom side quests is 10 today, so audit them against FR-502 before you author more.
- [ ] No side quest is a pure fetch. The resolution must involve a choice.
- [ ] The thinning gradient shifts encounter tables and fizzle toward the front (FR-506).
- [ ] The M3.1 audit passes on every quest.
- [ ] A per-wave human playtest pass runs against the world-state matrix (FR-906).

**Fleet-reality clause, from the ratified PRD §7:** ten agents do not give ten times the
output. Claude's review is the limit. Size each wave to review capacity. Ship wave N before
you start wave N+1.

---

## M8 — Living world ⚠ AMENDMENT FIRST

**Size:** M · **Risk:** Medium · **Gate:** none. The amendment is ratified
**Requirements:** **FR-504a, RATIFIED 2026-08-07.** Supersedes FR-504.

FR-504 said "No full NPC schedules in v1." FR-504a replaces it with tier 1.5: a four-phase
clock plus hand-authored lookup routines for 10 to 15 hub NPCs.

**`docs/prd-amendment-living-world.md` is RATIFIED as of 2026-08-07.** Read §2 before starting
any of this work. §2.2 lists what stays cut, and the boundary there is binding, not advisory:
routines are a lookup table, with no pathfinding, no continuous simulation, and a hard cap of 15
NPCs. Routine 16 needs a further amendment.

**Tracker note: issue #104 is written against the retired FR-504 text.** Update its scope to
FR-504a before starting it.

Definition of done:
- [ ] A world clock exists with four phases. It advances on declared events, never on a timer.
- [ ] The clock serializes into the save. Schema 5 becomes 6, with a migration and a fixture.
- [ ] A schema 5 save still loads and receives the default phase.
- [ ] 10 to 15 named hub NPCs follow authored routines. A count above 15 fails.
- [ ] Every other NPC keeps flag-keyed and rep-keyed reactivity only.
- [ ] Dialogue can read the time of day.
- [ ] No quest-critical interaction is reachable in fewer than two phases (FR-905).
- [ ] The clock does not break quest flags, encounters, or save migration.

---

## M9 — Region map and fast travel

**Size:** S · **Risk:** Low · **Gate:** after M5
**Requirements:** FR-503.

The PRD ratified the shape: **discovered hubs only, at a cost.** Implement that shape. Do not
redesign it.

Definition of done:
- [ ] A region map screen shows the travel graph.
- [ ] Fast travel reaches discovered hubs only.
- [ ] Fast travel has a cost.
- [ ] Travel routes through `GameFlow.travel()`. No code calls `change_scene_to_file()`.

---

## M10 — Polish and New Game Plus

**Size:** M · **Risk:** Low · **Gate:** after M7
**Requirements:** FR-801, FR-803, FR-605, FR-904, FR-607.

Definition of done:
- [ ] The Mirror Shop offers carry-over purchases at chapter end (FR-801).
- [ ] Prices let one strong run afford 2 to 3 picks.
- [ ] A few dialogue lines acknowledge the NG+ echo (FR-803).
- [ ] The 9-patch `StyleBoxTexture` pass replaces the sharp corners (FR-605).
- [ ] Field scenes hold 60 fps with the full HUD. Battle transitions take under 2 seconds
      (FR-904). `tools/performance_benchmark.gd` measures this.
- [ ] The accessibility baseline is met: input remapping, text scaling, hue-independent gauges,
      reduced motion, dyslexia-friendly font (FR-607).

---

## M11 — Chapter acceptance

**Size:** S · **Risk:** Low · **Gate:** last

Definition of done:
- [ ] Four build archetypes each complete a full playthrough.
- [ ] Every row of the PRD §3 metrics table passes.
- [ ] The full test suite passes in CI.
- [ ] The playtime reaches 15 to 25 hours.

---

## 3. Fleet routing

The global role policy governs this table.

| Milestone | Fleet | Boundary |
|---|---|---|
| M1, M2, M3 | Codex | The architecture doc fixes the design. Make no design decisions. Provide tests with each handoff |
| M4 | Codex, with Claude on the gate text | Do not start M4.3. It is design-blocked |
| M5 | **None** | Outside humans only. No agent may execute or simulate this gate |
| M6 | Claude writes the companions. Codex wires them | Companion voice is narrative. Keep STE away from it |
| M7 | Content waves, Claude reviews each one | Give a template and a canon excerpt in each prompt. Every output is a draft |
| M8 | Claude writes the amendment. Codex builds the clock | Do not start before the amendment is ratified |
| M9, M10 | Codex | FR-503 is already designed. Implement it. Do not redesign it |
| Research, tests, first-pass visuals | Gemini, Jules | Bounded questions. Compact evidence-backed handoffs |

Label the GitHub issues per the policy. Use `codex` for implementation. Use `gemini` or `jules`
for research and test generation. Leave architecture and canon issues unlabelled.

**No worker may change a GitHub label or an assignee without your authorisation.**

---

## 4. Risk register

| Risk | Effect | Control |
|---|---|---|
| Gate T criterion 2 fails | The grid was the wrong trade. It becomes sunk cost | Amendment §5 escalates this to the owner immediately. #164 never edits the zone model, so setting `use_grid_battlefield` to `false` restores the old behaviour |
| Gate T criterion 6 fails | Content production cannot start | The slice is small. Repair comprehension, then re-run. Do not author content in the meantime |
| Outside playtesters are hard to find | Criterion 6 stalls, and it blocks 5 milestones | Recruiting runs in parallel with the other nine criteria, so start it during T1. Recruit 6 to 8 to net 3 to 5. See §5.3 |
| The roadmap and the tracker drift | Work happens twice, or not at all | §6.5 maps every milestone to its issues. Issue #177 is the index. Update both, or neither |
| M7 review becomes the bottleneck | Content waves stall | Size each wave to review capacity. Check template conformance mechanically before human review |
| A flag rename breaks a shipped save | Save corruption | A shipped flag ID is permanent. A rename is a migration. See architecture §3.3 |
| `godot --headless --script` exits 134 | A false CI failure | Never gate CI on the raw exit code of a tool script. Judge the output. This happens 20 to 30 percent of the time |
| A `[if expr]` condition silently does nothing | A broken consequence looks correct | M3.2 lint. Run it before M7 multiplies the content |

---

## 5. Schedule

The ratified PRD §7 Phase 0 asked for a person-hour estimate for each phase. It recorded the
reason: "no deadline is not a plan". The estimate sizes the cut list.

**Capacity, recorded 2026-08-07:** 4 or more hours per day. This document plans against
**28 hours per week**. That figure is deliberately conservative. It assumes seven days at four
hours and reserves nothing, so any week that loses a day still lands inside the range.

### 5.1 Effort and elapsed time

| Milestone | Effort (h) | Weeks at 28 h | Confidence |
|---|---|---|---|
| M1 Navigation | 18 to 25 | 0.7 to 0.9 | High. Scope is known and small |
| M2 Battlefield seam | 35 to 50 | 1.3 to 1.8 | High. The interface list is fixed |
| M3 Consequence tooling | 12 to 18 | 0.4 to 0.6 | High |
| T1 Elemental tactical layer | 80 to 120 | 2.9 to 4.3 | Low. Omitted earlier. See §1.4. Excludes blocked #136 |
| M4 Slice assembly | 25 to 40 | 0.9 to 1.4 | Medium. Excludes M4.3 |
| **M5 GATE T** | **78 to 122** | **2.8 to 4.4** | Medium. Corrected. See §5.3 |
| M6 Companions | 70 to 100 | 2.5 to 3.6 | Medium. Blocked by question #132 |
| M7 Region content | 200 to 320 | 7 to 11 | Low. See §5.4 |
| M8 Living world | 40 to 55 | 1.4 to 2.0 | Medium |
| M9 Region map | 12 to 18 | 0.4 to 0.6 | High. The design is ratified |
| M10 Polish and NG+ | 45 to 65 | 1.6 to 2.3 | Medium |
| M11 Acceptance | 20 to 30 | 0.7 to 1.1 | Medium. Playthroughs are wall-clock heavy |
| FR-507 world-state evolution | 72 to 114 | 2.6 to 4.1 | Low. Ratified 2026-08-07. Blocked on vault lore |
| **Total** | **702 to 1074** | **25 to 38 weeks** | — |

**Chapter One ships in approximately 6 to 9 months at this capacity.**

This total rose twice on 2026-08-07, and the two rises are different in kind.

**First rise, 480-730 to 630-960 hours: corrections, not new scope.** The elemental tactical
layer was missing entirely (§1.4), and Gate T was estimated as a scheduling wait rather than as
ten criteria of real work (§5.3). Both were already ratified and already on the issue tracker;
this document had simply not counted them.

**Second rise, 630-960 to 702-1074 hours: genuinely new scope.** FR-507 world-state evolution
was ratified on 2026-08-07 and adds 72 to 114 hours. That is a deliberate purchase, not a
correction. Its authoring row dominates and grows fastest if the three-state cap slips.

### 5.2 The de-risked block you can start today

M1 to M4 total **90 to 133 hours**. At 28 hours per week that is **3.5 to 5 weeks**.

No gate blocks this block. No open question blocks it, with one exception: M4.3 waits on the
Soul zero-state decision. Remove M4.3 and the block is fully unblocked.

Order the work M1 → M2 → M3 → M4. M3 does not depend on M1 or M2, so move it earlier if a
Codex handoff on M1 or M2 stalls.

### 5.3 Gate T — corrected 2026-08-07

An earlier version of this section said that M5 costs 6 to 10 hours and 2 to 4 weeks of elapsed
time, because outside humans gate it. **That was wrong, and it understated the gate badly.**

Amendment §5.0 shows that nine of the ten criteria are evidenced headless. Those nine are real
engineering work, not a scheduling wait. They include five archetype encounters cleared by four
build archetypes, queue integrity at 8 or more combatants, and a save round trip covering tile
charge and weather phase.

Corrected estimate:

| Part | Effort (h) | Notes |
|---|---|---|
| Criteria 1, 3, 4, 5, 7, 8, 10 — build and test | 60 to 90 | The bulk. Encounter authoring dominates |
| Criterion 2 — positional-depth evidence | 8 to 14 | A scripted AI comparison satisfies it |
| Criterion 9 — performance | 4 to 8 | `scripts/benchmark_performance.sh` already exists |
| Criterion 6 — comprehension | 6 to 10 of **your** time | Plus 2 to 4 weeks of recruiting, in parallel |
| **Total** | **78 to 122** | **2.8 to 4.4 weeks at 28 h** |

Recruiting is the only part that effort cannot compress. It runs **in parallel** with the other
nine criteria, so it adds no weeks of its own — provided you start it early.

**Start recruiting during the T1 work, not after it.** You do not need the slice to exist
before you ask a person to play it in three weeks.

### 5.4 Why M7 stays uncertain

M7 has the widest range in the table, at 200 to 320 hours. The content templates do not exist
yet, so no measured rate exists.

Replace the estimate with a measurement. Author **one** complete location and **one** complete
side quest under the M7 templates. Record the hours. Multiply by the remaining count. The M7
range then narrows to approximately plus or minus 15 percent, and the cut list becomes real.

Do this at the start of M7. Do not do it earlier, because the templates do not exist before M5
passes.

### 5.5 What the estimate assumes

- Codex delivers M1, M2, M3, M9, and M10 with your review, not with your keyboard. Your hours
  are specification hours and review hours.
- Each estimate holds review time. It does not hold rework time from a failed gate.
- M6 and M7 assume that question #132 is answered. If it is not, M6 stalls at ability
  authoring.
- No estimate holds the Soul zero-state design work, because the scope is unknown until you
  decide the shape.

---

## 6. Divergences from the ratified PRD

Each divergence is listed. Nothing changes by silence.

| Item | Ratified text | This roadmap | Action needed |
|---|---|---|---|
| ~~Phase 1.5 slice content~~ | ~~"AP + zone facing"~~ | **WITHDRAWN.** Amendment §5 already superseded Phase 1.5 with Gate T | None. See §1.3 |
| ~~Phase 1.5 and Gate T~~ | ~~Two separate gates~~ | **WITHDRAWN.** The amendment already merged them | None. See §1.3 |
| FR-504 NPC schedules | "No full NPC schedules in v1" | Clock plus hub-only routines | Amendment WRITTEN 2026-08-07 as FR-504a. **Owner must ratify §8 before M8 starts** |
| Phase ordering | Phase 2 combat, then Phase 4 content | Navigation first, then the seam, then the gate | This document. Ratify or reject it |
| FR-502 side quests | "≥ 10 side quests" | 10 Dom side quests may already satisfy this | Audit before you author more (M7) |

---

## 6.5 Where this roadmap lives on GitHub

Created 2026-08-07. This roadmap did **not** get its own M1 to M11 milestones. The repository
already carried a ratified execution spine (T0, T1, T2), and forking it would have split the
backlog. The missing work was grafted into that spine instead.

**Index issue: #177.** It holds the execution order in one place. Read that before you read the
milestone list.

| Roadmap | GitHub milestone | Issues |
|---|---|---|
| M1 Navigation | Tactical Layer T0.5 — Isometric navigation foundation | #160 #161 #162 #163 |
| M2.1, M2.3 Seam | Tactical Layer T1.5 — Seam widening and stop-loss prove-out | #164 #165 |
| M2.2 Grid model | Tactical Layer T1 (pre-existing) | #137 |
| T1 Elemental layer | Tactical Layer T1 (pre-existing) | #136 (blocked) #139 #140 #141 #142 |
| M3 Consequence tooling | Consequence Tooling — flag grammar and dialogue lint | #166 #167 |
| M5 Gate T | Gate T — Tactical vertical slice (BLOCKING) | #168 #169 #170 #171 #172 #93 #173 #174 #175 #176 |
| M6 Companions | Ch1 Phase 4 (pre-existing) | #103 |
| M7 Region content | Ch1 Phase 4 (pre-existing) | #102 |
| M8 Living world | Ch1 Phase 4 (pre-existing) | #104 |
| M10 Polish, NG+ | Ch1 Phase 5 (pre-existing) | #105 |
| M11 Acceptance | Ch1 Phase 5 (pre-existing) | #106 |

Two tracker changes were made at the same time:

- The milestone **Ch1 Phase 1.5 — Integrated Slice Gate** is closed as superseded. Amendment §5
  requires this. Its one issue, #93, moved to Gate T as criterion 6.
- **#138** (charge-time scheduler) is flagged as possibly stale, because
  `globals/combat/charge_time_scheduler.gd` exists and is tested. The owner decides.

## 7. Open questions

This roadmap does not answer these. The architecture document §6 holds the full list.

1. **The Soul zero state.** Blocks M4.3.
2. **Does `Renown` feed Gauge recovery?** Canon makes recovery social. Not ratified.
3. **#132** — three combat disciplines against the Ten Patron Classes. Blocks companion and
   ability authoring in M6.
4. **FR-701** — which 4 to 5 vault peoples are playable.
5. **FR-907** — the respec policy.
6. **Gamepad at ship.**
7. **The elevation authoring format.** Decide during M2.2.

Questions 1 and 3 block real work. Answer those two first.
