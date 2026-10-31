# Roadmap issue packet — 2026-10-30 revision

## 0. Filing boundary and commands

Nothing in this packet is filed until the owner says so. The milestone names below are proposals;
do not assume they exist. Before filing, confirm or create them only with explicit owner
authorization. The checked-in repository label list names `delegated-to-codex` and `jules`
(`docs/fleet-roadmap.md`, `CONTRIBUTING.md`; both verified present with `gh label list` on
2026-10-31): this packet uses the former for the role-policy Codex
implementation route, the latter for bounded research/tests, and no worker label for design,
canon, owner gates or final review. It does not guess a bare `codex` or `gemini` label.

The following commands are deliberately commented out. They are the commands that would file the
issues after the owner approves the packet, confirms the six proposed milestones exist, and
rechecks the labels:

```bash
# gh label list --limit 200
# gh api 'repos/{owner}/{repo}/milestones?state=open&per_page=100' --jq '.[].title'
# body_for() { awk -v prefix="### $1 — " 'index($0,prefix)==1 {on=1} on && /^##/ && index($0,prefix)!=1 {exit} on {print}' docs/roadmap-issues-2026-10-30.md; }
# gh issue create --title '[Roadmap P1.1] Developer-only Soul trace' --milestone 'Roadmap Phase 1 — Fallout-full field' --label delegated-to-codex --body "$(body_for P1.1)"
# gh issue create --title '[Roadmap P1.2] Field coverage audit and authoring pass' --milestone 'Roadmap Phase 1 — Fallout-full field' --label delegated-to-codex --body "$(body_for P1.2)"
# gh issue create --title '[Roadmap P1.3] Visible live barter ratio' --milestone 'Roadmap Phase 1 — Fallout-full field' --label delegated-to-codex --body "$(body_for P1.3)"
# gh issue create --title '[Roadmap P1.4] Equipment effects enter combat' --milestone 'Roadmap Phase 1 — Fallout-full field' --label delegated-to-codex --body "$(body_for P1.4)"
# gh issue create --title '[Roadmap P1.5] Verify region-map fast travel end to end' --milestone 'Roadmap Phase 1 — Fallout-full field' --label jules --body "$(body_for P1.5)"
# gh issue create --title '[Roadmap P1.6] Production Zhavar writers' --milestone 'Roadmap Phase 1 — Fallout-full field' --label delegated-to-codex --body "$(body_for P1.6)"
# gh issue create --title '[Roadmap P2.1] Authored Paradox routes with visible Soul costs' --milestone 'Roadmap Phase 2 — Soul: make the meter mean it' --body "$(body_for P2.1)"
# gh issue create --title '[Roadmap P2.2] Breath sizing against set-piece drain' --milestone 'Roadmap Phase 2 — Soul: make the meter mean it' --label delegated-to-codex --body "$(body_for P2.2)"
# gh issue create --title '[Roadmap P2.3] Soul bands and world read-back' --milestone 'Roadmap Phase 2 — Soul: make the meter mean it' --label delegated-to-codex --body "$(body_for P2.3)"
# gh issue create --title '[Roadmap P2.4] Append-only Soul log and playtest export' --milestone 'Roadmap Phase 2 — Soul: make the meter mean it' --label delegated-to-codex --body "$(body_for P2.4)"
# gh issue create --title '[Roadmap P2.5] Make the hollowing recovery price legible' --milestone 'Roadmap Phase 2 — Soul: make the meter mean it' --body "$(body_for P2.5)"
# gh issue create --title '[Roadmap P2.6] Agreement-route unavoidable spend (R3 curve)' --milestone 'Roadmap Phase 2 — Soul: make the meter mean it' --body "$(body_for P2.6)"
# gh issue create --title '[Roadmap P2.7] PROVISIONAL Hollow negatives package' --milestone 'Roadmap Phase 2 — Soul: make the meter mean it' --label delegated-to-codex --body "$(body_for P2.7)"
# gh issue create --title '[Roadmap P2.8] PROVISIONAL Name-Ledger recovery route' --milestone 'Roadmap Phase 2 — Soul: make the meter mean it' --body "$(body_for P2.8)"
# gh issue create --title '[Roadmap P3.1] Intent-planner performance and legibility spike' --milestone 'Roadmap Phase 3 — Enemies that play the game' --label delegated-to-codex --body "$(body_for P3.1)"
# gh issue create --title '[Roadmap P3.2] Retire the AP scheduler shim' --milestone 'Roadmap Phase 3 — Enemies that play the game' --label delegated-to-codex --body "$(body_for P3.2)"
# gh issue create --title '[Roadmap P3.3] Implement the selected uncapped intent planner' --milestone 'Roadmap Phase 3 — Enemies that play the game' --label delegated-to-codex --body "$(body_for P3.3)"
# gh issue create --title '[Roadmap P3.4] Approved enemy archetype abilities' --milestone 'Roadmap Phase 3 — Enemies that play the game' --label delegated-to-codex --body "$(body_for P3.4)"
# gh issue create --title '[Roadmap P3.5] Encounter templates, spawn breadth and verb coverage' --milestone 'Roadmap Phase 3 — Enemies that play the game' --label delegated-to-codex --body "$(body_for P3.5)"
# gh issue create --title '[Roadmap P3.6] Complete or collapse balance bands' --milestone 'Roadmap Phase 3 — Enemies that play the game' --label delegated-to-codex --body "$(body_for P3.6)"
# gh issue create --title '[Roadmap P3.7] Telegraph the dorthkor-vanguard reinforcement chain' --milestone 'Roadmap Phase 3 — Enemies that play the game' --label delegated-to-codex --body "$(body_for P3.7)"
# gh issue create --title '[Roadmap P3.8] Emit ambient-combat admission events' --milestone 'Roadmap Phase 3 — Enemies that play the game' --label delegated-to-codex --body "$(body_for P3.8)"
# gh issue create --title '[Roadmap P3.9] Show pending reinforcements in the CT strip' --milestone 'Roadmap Phase 3 — Enemies that play the game' --label delegated-to-codex --body "$(body_for P3.9)"
# gh issue create --title '[Roadmap P3.10] Serai-Lun killing-or-mercy reaction data' --milestone 'Roadmap Phase 3 — Enemies that play the game' --body "$(body_for P3.10)"
# gh issue create --title '[Roadmap P4.1] PROVISIONAL four-person Chapter 1 party' --milestone 'Roadmap Phase 4 — Company' --label delegated-to-codex --body "$(body_for P4.1)"
# gh issue create --title '[Roadmap P4.2] Reactive companion bark triggers' --milestone 'Roadmap Phase 4 — Company' --label delegated-to-codex --body "$(body_for P4.2)"
# gh issue create --title '[Roadmap P4.3] TravelPlan banter beats' --milestone 'Roadmap Phase 4 — Company' --label delegated-to-codex --body "$(body_for P4.3)"
# gh issue create --title '[Roadmap P4.4] Auditable companion quest outcomes' --milestone 'Roadmap Phase 4 — Company' --label delegated-to-codex --body "$(body_for P4.4)"
# gh issue create --title '[Roadmap P4.5] Main-ruling companion interjections' --milestone 'Roadmap Phase 4 — Company' --body "$(body_for P4.5)"
# gh issue create --title '[Roadmap P5.1] Kesselford and Ashlaren side-quest set' --milestone 'Roadmap Phase 5 — Hours' --body "$(body_for P5.1)"
# gh issue create --title '[Roadmap P5.2] Three mandatory main-ruling CT set-pieces' --milestone 'Roadmap Phase 5 — Hours' --body "$(body_for P5.2)"
# gh issue create --title '[Roadmap P5.3] Resolve every stub quest' --milestone 'Roadmap Phase 5 — Hours' --body "$(body_for P5.3)"
# gh issue create --title '[Roadmap P5.4] Playtime clock and critical-path estimator' --milestone 'Roadmap Phase 5 — Hours' --label delegated-to-codex --body "$(body_for P5.4)"
# gh issue create --title '[Roadmap P5.5] Talk, Tread or Soul bypass audit' --milestone 'Roadmap Phase 5 — Hours' --body "$(body_for P5.5)"
# gh issue create --title '[Roadmap P6.1] Codex teaching entries and first-spend beat' --milestone 'Roadmap Phase 6 — Teach, test, polish' --body "$(body_for P6.1)"
# gh issue create --title '[Roadmap P6.2] FR-607 accessibility baseline' --milestone 'Roadmap Phase 6 — Teach, test, polish' --label delegated-to-codex --body "$(body_for P6.2)"
# gh issue create --title '[Roadmap P6.3] PROVISIONAL functional presentation and Chapter 1 language menu' --milestone 'Roadmap Phase 6 — Teach, test, polish' --label delegated-to-codex --body "$(body_for P6.3)"
# gh issue create --title '[Roadmap P6.4] Gate T-6 outside-tester evidence' --milestone 'Roadmap Phase 6 — Teach, test, polish' --body "$(body_for P6.4)"
# gh issue create --title '[Roadmap P6.5] Final FR-904 rendered reference run' --milestone 'Roadmap Phase 6 — Teach, test, polish' --body "$(body_for P6.5)"
# gh issue create --title '[Roadmap P6.6] Four viable-build playthrough checklists' --milestone 'Roadmap Phase 6 — Teach, test, polish' --body "$(body_for P6.6)"
```

## Phase 1 — proposed milestone: Roadmap Phase 1 — Fallout-full field

### P1.1 — Developer-only Soul trace

**Title:** [Roadmap P1.1] Developer-only Soul trace

**Milestone:** Proposed `Roadmap Phase 1 — Fallout-full field`; confirm it exists before filing.

**Labels:** `delegated-to-codex`

**Objective:** Open field work with cause-level Soul diagnostics without moving the player-facing
Soul log or band authoring out of Phase 2.

**Scope:** `globals/game_state.gd`, existing Soul mutation call sites, diagnostic output, and
focused unit/e2e coverage.

**Deliverables:** A developer-only trace entry for every Soul mutation containing cause,
before/after value, and an existing band identifier when available.

**Acceptance checks (binary, instrument named):** Run the Phase 1 journey fixture and inspect the
Soul trace: every mutation appears exactly once with cause and before/after values; missing or
duplicate entries fail. Save round-trip and player-facing UI snapshots remain unchanged.

**Do-not-decide boundary:** No saved ledger, player UI, prose, localization, new band names, band
thresholds or NPC reactions.

**Depends on:** Phase 0 / PR #529. No owner ruling.

### P1.2 — Field coverage audit and authoring pass

**Title:** [Roadmap P1.2] Field coverage audit and authoring pass

**Milestone:** Proposed `Roadmap Phase 1 — Fallout-full field`; confirm it exists before filing.

**Labels:** `delegated-to-codex`

**Objective:** Turn proof-of-concept field verbs into measurable shipped-content coverage.

**Scope:** `world/`, `dialogue/`, `globals/loot_table_registry.gd`, `tools/`, `test/`, and the
existing location/encounter templates. Generated data changes must use repository generators.

**Deliverables:** Field-coverage audit (`tools/audit_field_coverage.gd`); authored locks, pockets,
loot-table containers, wild caches and checks; Bellow coverage; loot/item additions approved by R7.

**Acceptance checks (binary, instrument named):** The field-coverage audit must report
PROVISIONAL ≥15/22 distinct skills, Bellow ≥1, every audited field verb PROVISIONAL ≥5, and per
hub PROVISIONAL ≥4 locks / ≥3 pockets / ≥4 containers, per wild PROVISIONAL ≥2 caches, loot tables
PROVISIONAL ≥8 and items PROVISIONAL ≥40. Any lower count fails. Report the earlier PROVISIONAL
≥12/22-at-≥3-checks comparison separately.

**Do-not-decide boundary:** Do not invent canon, hand-edit `data/generated/*`, change skill math,
or silently replace R7/item 11c targets.

**Depends on:** R7; P1.1; Phase 0 / PR #529 audit baseline.

### P1.3 — Visible live barter ratio

**Title:** [Roadmap P1.3] Visible live barter ratio

**Milestone:** Proposed `Roadmap Phase 1 — Fallout-full field`; confirm it exists before filing.

**Labels:** `delegated-to-codex`

**Objective:** Make a live Sway check visibly alter the vendor exchange ratio.

**Scope:** `ui/screens/shop.gd`, `ui/screens/shop.tscn`, `globals/game_state.gd`, and focused shop
tests/captures.

**Deliverables:** Barter interaction, visible before/after ratio, blocked/failure explanation, and
regression coverage for unchanged purchase accounting.

**Acceptance checks (binary, instrument named):** A scripted shop capture must show the same
basket at two approved Sway outcomes with visibly different ratios and matching totals; no visible
movement or mismatched accounting fails.

**Do-not-decide boundary:** Do not retune the economy, invent vendor prose, add currencies, or
change R7 density targets.

**Depends on:** R7; P1.1.

### P1.4 — Equipment effects enter combat

**Title:** [Roadmap P1.4] Equipment effects enter combat

**Milestone:** Proposed `Roadmap Phase 1 — Fallout-full field`; confirm it exists before filing.

**Labels:** `delegated-to-codex`

**Objective:** Give the saved equipment slots in `globals/party_member.gd` an audited combat read
path using approved item data.

**Scope:** `globals/party_member.gd`, `globals/combat/`, approved item resources under `data/`, and
focused unit/integration coverage.

**Deliverables:** One public equipment-to-combat read path, supported effects from existing item
definitions, serialization compatibility, and before/after combat evidence.

**Acceptance checks (binary, instrument named):** The equipment combat fixture must show each
approved equipped effect exactly once, no effect when unequipped, and a save round-trip preserving
slots; any mismatch fails.

**Do-not-decide boundary:** Do not invent item effects, balance values, slots, loot canon or a new
equipment architecture. Return missing design data to the owner.

**Depends on:** R7; P1.1; approved item definitions.

### P1.5 — Verify region-map fast travel end to end

**Title:** [Roadmap P1.5] Verify region-map fast travel end to end

**Milestone:** Proposed `Roadmap Phase 1 — Fallout-full field`; confirm it exists before filing.

**Labels:** `jules`

**Objective:** Verify the shipped region-map journey path end to end and identify any demonstrated
gap between selection, travel and arrival.

**Scope:** `ui/screens/region_map.gd`, `ui/screens/region_map.tscn`,
`ui/screens/region_map_canvas.gd`, `ui/flow/game_flow.gd`, `globals/fast_travel_registry.gd`, and
existing travel tests.

**Deliverables:** One end-to-end capture covering destination selection, existing
cost/eligibility feedback, the shipped `GameFlow.start_journey()` call and arrival; a bounded gap
report if that capture fails.

**Acceptance checks (binary, instrument named):** `test/integration/test_region_map.gd`,
`test/integration/test_travel_flow.gd`, and the chapter-journey capture must select a destination,
pay the approved cost, traverse the normal flow and arrive; any direct scene change or dead end
fails. Existing plan-creation and arrival coverage is evidence, not missing implementation.

**Do-not-decide boundary:** Do not add destinations, alter route costs, bypass `GameFlow`, change
travel canon, or make production changes under this verification label. Return a demonstrated
implementation gap for a separately approved implementation issue.

**Depends on:** R7; P1.1; the shipped region-map and fast-travel registries.

### P1.6 — Production Zhavar writers

**Title:** [Roadmap P1.6] Production Zhavar writers

**Milestone:** Proposed `Roadmap Phase 1 — Fallout-full field`; confirm it exists before filing.

**Labels:** `delegated-to-codex`

**Objective:** `raise_zhavar` is raised in production for the `wilds` zone only
(`globals/quest_registry.gd:542`, `dialogue/sella_varn.dialogue:12`); make the already-authored
toll, telegraph and rumour routes on the other zones reachable through production quest/travel
events.

**Scope:** `globals/save_game.gd`, `globals/quest_registry.gd`, existing travel/quest hooks,
approved dialogue call sites, `tools/quest_audit.gd`, and focused tests.

**Deliverables:** Idempotent production calls to `SaveGame.raise_zhavar()` for the zones that lack
one, persistence coverage,
and journey evidence for each already-authored route.

**Acceptance checks (binary, instrument named):** The chapter-journey harness and
`tools/quest_audit.gd` must reach all three approved route classes and show each rung write once;
an unreachable route, duplicate write or unapproved source fails.

**Do-not-decide boundary:** Do not author new Zhavar beats, rename zones, change rung effects or
resolve lore gaps.

**Depends on:** R7; P1.1 and P1.5; approved main-quest/travel events.

## Phase 2 — proposed milestone: Roadmap Phase 2 — Soul: make the meter mean it

### P2.1 — Authored Paradox routes with visible Soul costs

**Title:** [Roadmap P2.1] Authored Paradox routes with visible Soul costs

**Milestone:** Proposed `Roadmap Phase 2 — Soul: make the meter mean it`; confirm it exists before
filing.

**Labels:** None — design/canon-bearing prose stays owner/Claude-owned.

**Objective:** Give each in-scope side quest and main ruling an approved Soul-spending alternative
whose price is visible before commitment.

**Scope:** Authored quest/dialogue sources, existing `outcome_soul_deltas` data, localization
source extraction, and quest/journey tests. Regenerate generated artifacts; do not hand-edit them.

**Deliverables:** PROVISIONAL 14 routes: a reviewed Paradox option on each of the ten Dom side
quests and the Hollowmere stake, and a Soul cost on each of the three main-quest rulings whichever
way it goes; visible PROVISIONAL −4 to −10 costs and one matching outcome delta per route.

**Acceptance checks (binary, instrument named):** `tools/quest_audit.gd` and the chapter-journey
harness must report one visible cost and one equal logged delta for every approved route; any
missing, hidden or unequal pair fails.

**Do-not-decide boundary:** Do not write unapproved quest outcomes, invent canon, change the cost
range, or add Soul income outside acts of Agreement.

**Depends on:** R1; Phase 1 acceptance; P1.1 trace.

### P2.2 — Breath sizing against set-piece drain

**Title:** [Roadmap P2.2] Breath sizing against set-piece drain

**Milestone:** Proposed `Roadmap Phase 2 — Soul: make the meter mean it`; confirm it exists before
filing.

**Labels:** `delegated-to-codex`

**Objective:** Measure and tune approved Breath pools so the overreach decision appears at the R2
planning point without changing refill cadence.

**Scope:** Existing casting economy values, set-piece fixtures, `tools/casting_economy_sweep.gd`,
`docs/casting-economy.md`, and focused tests.

**Deliverables:** Reproducible sweep, smallest approved value changes, and a results table in the
existing economy document.

**Acceptance checks (binary, instrument named):** `tools/casting_economy_sweep.gd` and the Gate T
harnesses (`test/integration/test_gate_t1_clearability.gd`,
`test/integration/test_gate_t2_positional_depth.gd`) must show approved set-pieces exhausting Breath by PROVISIONAL round 3–4 with per-scene refill intact;
outside the band or changed cadence fails.

**Do-not-decide boundary:** Do not change refill cadence, invent new abilities, or ratify economy
numbers; return outlier classes to the owner.

**Depends on:** R2; Phase 1 acceptance.

### P2.3 — Soul bands and world read-back

**Title:** [Roadmap P2.3] Soul bands and world read-back

**Milestone:** Proposed `Roadmap Phase 2 — Soul: make the meter mean it`; confirm it exists before
filing.

**Labels:** `delegated-to-codex`

**Objective:** Route NPC and companion reactions through one authored Soul-band table.

**Scope:** `globals/npc_reactions.gd`, `globals/companion_barks.gd`, approved hub dialogue,
`tools/quest_audit.gd`, and focused tests.

**Deliverables:** Band table using R12's names and thresholds; PROVISIONAL ≥3 approved read-back
NPCs
per hub; one approved companion bark on every downward crossing and recovery.

**Acceptance checks (binary, instrument named):** The NPC read-back report from
`tools/quest_audit.gd`, bark audit, and chapter journey must cover each approved band transition
and PROVISIONAL ≥3 NPCs per hub; missing or duplicate reactions fail.

**Do-not-decide boundary:** No band names or thresholds beyond R12's answer, no NPC lore or
companion voice. Provisional
names remain visibly provisional until owner review.

**Depends on:** R3 and R12; P2.1; Phase 1 acceptance.

### P2.4 — Append-only Soul log and playtest export

**Title:** [Roadmap P2.4] Append-only Soul log and playtest export

**Milestone:** Proposed `Roadmap Phase 2 — Soul: make the meter mean it`; confirm it exists before
filing.

**Labels:** `delegated-to-codex`

**Objective:** Replace the Phase 1 diagnostic trace with the durable, player-readable audit trail
needed by chapter completion and playtests.

**Scope:** `globals/game_state.gd`, `globals/save_game.gd`, existing Soul mutation API,
`ui/screens/chapter_complete.gd`, playtest export, migrations, and focused tests.

**Deliverables:** Append-only serializable entries with cause and before/after values; one public
write path; chapter-complete display; deterministic export.

**Acceptance checks (binary, instrument named):** Soul-log unit tests, save migration/round-trip,
chapter-journey export and chapter-complete capture must agree entry-for-entry; mutation outside
the public write path, lost entries or reordered export fails.

**Do-not-decide boundary:** Do not rename bands, change Soul math, write back to Pandora, or turn
the log into a second mutable ledger.

**Depends on:** R3; P1.1; P2.1.

### P2.5 — Make the hollowing recovery price legible

**Title:** [Roadmap P2.5] Make the hollowing recovery price legible

**Milestone:** Proposed `Roadmap Phase 2 — Soul: make the meter mean it`; confirm it exists before
filing.

**Labels:** None — canon-bearing dialogue stays owner/Claude-owned.

**Objective:** State the existing recovery ceiling at the decision point so hollowing is a known
price rather than a hidden punishment.

**Scope:** Existing hollowing dialogue and conditions, localization sources, Soul-log assertion,
and focused dialogue/journey tests.

**Deliverables:** Owner-approved price text reflecting the existing PROVISIONAL 0.5× ceiling and
a matching logged recovery event.

**Acceptance checks (binary, instrument named):** The dialogue fixture and chapter-journey Soul
log must show the price before commitment and an equal applied result; hidden text or mismatched
math fails.

**Do-not-decide boundary:** Do not change hollowing mechanics, recovery sources, ceiling value,
band terminology or voice without an owner ruling.

**Depends on:** R3; P2.3 and P2.4; owner prose approval.

### P2.6 — Agreement-route unavoidable spend (R3 curve)

**Title:** [Roadmap P2.6] Agreement-route unavoidable spend (R3 curve)

**Milestone:** Proposed `Roadmap Phase 2 — Soul: make the meter mean it`; confirm it exists before
filing.

**Labels:** None — economy sizing is a design call reviewed by Claude; data edits may be delegated
afterwards.

**Objective:** Make the R3 curve reachable on the all-Agreement path: income is up to ~96 at the
ruled +8 per act from a start of 50, so the chapter must carry unavoidable spend near the income
(main-quest ruling costs and set-piece overreach) for that path to end PROVISIONAL 40–50 under R3
`down` (55–65 under `55–65`).

**Scope:** Main-quest ruling outcome data, set-piece Breath pools and overreach costs
(`docs/casting-economy.md`), `globals/quest_registry.gd` outcome arrays, the chapter-journey
harness play script, and the Soul log export.

**Deliverables:** A sized table of unavoidable spends with their causes, the data edits that
implement them, and the journey-harness all-Agreement script that exercises them.

**Acceptance checks (binary, instrument named):** The chapter-journey harness on the all-Agreement
script ends inside R3's band, the Soul log shows each unavoidable spend once with its cause, the
+8 per act of Agreement is unchanged, and no route reaches 100. Any miss fails.

**Do-not-decide boundary:** Do not change the ruled +8 per act, invent new Soul-costing systems or
set the final numbers; R3's answer fixes the band and owner item 5 fixes the costs.

**Depends on:** R1, R3; P2.1 and P2.4; Phase 1 acceptance.

### P2.7 — PROVISIONAL Hollow negatives package

**Title:** [Roadmap P2.7] PROVISIONAL Hollow negatives package

**Milestone:** Proposed `Roadmap Phase 2 — Soul: make the meter mean it`; confirm it exists before
filing.

**Labels:** `delegated-to-codex`

**Objective:** Make active Hollow at Soul exactly zero strongly felt but still playable, while
preserving the permanent scar after the first positive Soul write clears the active state.

**Scope:** `../dramgid-vault/cosmology/souls.md` (the authoritative “Reaching zero —
husking-while-alive” ruling), `globals/game_state.gd`, `globals/elements/casting_gate.gd`,
`globals/npc_reactions.gd`, `globals/companion_barks.gd`,
`ui/hud/consequence_notices.gd`, `ui/hud/soul_gauge.gd`, `ui/screens/tavern.gd`,
`globals/vendor_registry.gd`, `globals/fast_travel_registry.gd`,
`globals/travel/travel_plan.gd`, `ui/screens/journal.gd`, approved dialogue conditions and
focused save, dialogue, vendor and travel fixtures.

**Deliverables:** PROVISIONAL lost dialogue options, new-recruit gating, loss of the favorable
Sway bargaining benefit, refusal of elective solo travel with companion-supported and explicit
recovery travel preserved, a displayed permanent ceiling, and a journal recovery lead; retain
the existing casting refusal, NPC reaction, witness bark and consequence notice. The ceiling is
PROVISIONAL `0.5 ×` the Soul value immediately before the first zero, pending R13.

**Acceptance checks (binary, instrument named):** `test/unit/test_husked_state.gd`,
`test/unit/test_dialogue_checks.gd`, `test/unit/test_vendor_pricing.gd`,
`test/integration/test_travel_flow.gd` and a rendered Soul-gauge capture must show every listed
restriction at zero, no elective-solo-travel soft-lock, active restrictions clearing on the
first positive write, and the ceiling remaining. A missing restriction, passive-rest recovery,
unreachable recovery travel, peak-Soul ceiling basis or cleared scar fails.

**Do-not-decide boundary:** Do not ratify R13, change what enters or exits active Hollow, add a
new penalty system, invent dialogue, remove the permanent scar, or make passive rest regenerate
Soul.

**Depends on:** R13; P2.3–P2.5; owner approval of blocked choices and journal prose.

### P2.8 — PROVISIONAL Name-Ledger recovery route

**Title:** [Roadmap P2.8] PROVISIONAL Name-Ledger recovery route

**Milestone:** Proposed `Roadmap Phase 2 — Soul: make the meter mean it`; confirm it exists before
filing.

**Labels:** None — the Agreement act and its prose remain owner/Claude-owned until approved.

**Objective:** Give an actively Hollow player a legible, repeatable act of Agreement that can
raise Soul above zero without requiring Wyneth's recruitment or leaving her one-shot companion
quest unresolved.

**Scope:** `../dramgid-vault/cosmology/souls.md` (the authoritative “Reaching zero —
husking-while-alive” and River-Mother Name-Ledger lore),
`globals/combat/class_resources/haeren_name_ledger.gd` as a boundary reference,
`globals/quest_registry.gd`, approved River-Mother NPC dialogue/quest outcomes,
`ui/screens/journal.gd`, the Soul log from P2.4, `tools/quest_audit.gd` and journey/save fixtures.

**Deliverables:** An owner-approved PROVISIONAL NPC-side act in which a River-Mother records the
player's name, or another owner-approved repeatable Agreement act; an Agreement-tagged positive
Soul write through the quest path; a journal lead; persistence and repeat-use coverage. The
combat class resource remains what it is: recording a fallen or saved ally's name returns Breath
to its caster and does not itself mint Soul.

**Acceptance checks (binary, instrument named):** `test/e2e/test_first_chapter_journey.gd`,
`test/unit/test_husked_state.gd`, the Soul-log export and `tools/quest_audit.gd` must take a
zero-Soul save with no recruited Wyneth through the approved Agreement act, record the positive
write once, clear active Hollow, preserve the ceiling, and demonstrate the approved repeatable
cadence. A combat-resource Soul write, passive-rest write, recruitment dependency, one-shot
dead end or missing journal lead fails.

**Do-not-decide boundary:** Do not treat the Name-Ledger class resource as a world ritual, choose
the NPC or alternative Agreement act, set its Soul amount or cadence, write canon prose, require
Wyneth, or add a second non-Agreement Soul-income channel without owner approval.

**Depends on:** R13; P2.4 and P2.7; owner approval of the PROVISIONAL mechanism and prose.

## Phase 3 — proposed milestone: Roadmap Phase 3 — Enemies that play the game

### P3.1 — Intent-planner performance and legibility spike

**Title:** [Roadmap P3.1] Intent-planner performance and legibility spike

**Milestone:** Proposed `Roadmap Phase 3 — Enemies that play the game`; confirm it exists before
filing.

**Labels:** `delegated-to-codex` — an algorithm prototype run on the local benchmark harness;
evidence only, nothing ships from it.

**Objective:** Produce the evidence needed to choose an uncapped planner shape before enemy
authoring or any request to amend ruling 6.

**Scope:** `tools/populated_field_benchmark.gd`, thin planner prototypes under existing combat
boundaries, benchmark fixtures, a scripted legibility capture, and evidence documentation.

**Deliverables:** Comparable reports for uncapped full planning; uncapped tiered/cached planning
with every alerted hostile still in CT; a PROVISIONAL 24-decider comparison fallback; and a
scripted capture of next actor, revealed intent and right response.

**Acceptance checks (binary, instrument named):** The populated-field benchmark must report all
three variants at the ratified capacity of up to ~100 present-and-alerted hostiles against the
declared interim p95 ≤16.67 ms and battle-transition <2 s budget; D9 mean per decision is reported
as advisory. This comparison does not consume or move the official Phase 6 FR-904 rendered gate.
Every comparator must report; a comparator may fail its budget. The phase proceeds only if at
least one owner-permitted uncapped candidate meets the budget and passes the legibility capture
at PROVISIONAL 3/3 named facts (all three). If R10 supplies a number other than 24, that fallback
is measured too. A missing comparator report, or no passing candidate, fails and returns the
measured question to the owner.

**Do-not-decide boundary:** Do not ship a ceiling, admission queue, new HUD rule, enemy content or
permanent planner architecture. The PROVISIONAL 24 fallback is comparison-only.

**Depends on:** R10; Phase 2 acceptance. The official rendered FR-904 evidence remains Phase 6.

### P3.2 — Retire the AP scheduler shim

**Title:** [Roadmap P3.2] Retire the AP scheduler shim

**Milestone:** Proposed `Roadmap Phase 3 — Enemies that play the game`; confirm it exists before
filing.

**Labels:** `delegated-to-codex`

**Objective:** Put authored and ambient encounters under the one CT scheduler already assumed by
ruling 6 and the timeline HUD.

**Scope:** Existing combat scheduler selection, authored encounter flags, timeline integration,
`docs/godot-flow-handoff.md`, and scheduler regression tests.

**Deliverables:** AP shim removal, CT migration for all Chapter 1 encounter entry paths, compatible
save/load handling if needed, and updated flow documentation.

**Acceptance checks (binary, instrument named):** Scheduler integration tests and chapter journey
must observe CT for every authored and ambient fight, preserve same-map alert joins, and leave no
AP selection path; any AP execution or direct scene change fails.

**Do-not-decide boundary:** Do not redesign CT, alter initiative math, add an engaged ceiling or
change encounter prose.

**Depends on:** ruling 6 (fixed; R4 needs no reply); P3.1 passes; Phase 2 acceptance.

### P3.3 — Implement the selected uncapped intent planner

**Title:** [Roadmap P3.3] Implement the selected uncapped intent planner

**Milestone:** Proposed `Roadmap Phase 3 — Enemies that play the game`; confirm it exists before
filing.

**Labels:** `delegated-to-codex`

**Objective:** Turn the passing uncapped spike variant into the production planner while keeping
revealed intent truthful.

**Scope:** `globals/combat/combat_controller.gd`, existing intent/reveal surfaces, Sacred Clarity
integration, focused combat tests, benchmark and legibility fixtures.

**Deliverables:** Per-archetype intent sets (PROVISIONAL strike, hold, flank, guard-ally, call,
flee at a threshold), threat-score selection (lowest HP in reach, caster, isolated, flanked), the
approved cheap-intent tier/cache if selected, `shown_intent` consistency, invalidation rules,
logging and regression coverage.

**Acceptance checks (binary, instrument named):** The populated-field benchmark, intent-vs-strike
mirror harness and scripted legibility capture must reproduce P3.1's passing result; Sacred
Clarity must reveal the action actually executed. A stale/replaced intent, alerted hostile absent
from CT or performance regression beyond the declared budget fails.

**Do-not-decide boundary:** No engaged ceiling, delayed alerted join, new intent prose, ability
design or departure from the P3.1-selected uncapped architecture.

**Depends on:** R10 answered; P3.1; P3.2. Answers `defer` and `no ceiling` both permit the
uncapped implementation. A PROVISIONAL numeric answer pauses this issue until its scope is
revised to the owner-directed fallback and ruling 6 is amended.

### P3.4 — Approved enemy archetype abilities

**Title:** [Roadmap P3.4] Approved enemy archetype abilities

**Milestone:** Proposed `Roadmap Phase 3 — Enemies that play the game`; confirm it exists before
filing.

**Labels:** `delegated-to-codex`

**Objective:** Give each approved archetype a non-strike tactical question from the enemy-curve
packet.

**Scope:** Approved enemy-curve packet rows, existing combat action data, planner integration,
generated-data workflow where required, and focused tests.

**Deliverables:** PROVISIONAL at least one approved non-strike ability per archetype, planner
eligibility/scoring, truthful telegraph, and deterministic tests.

**Acceptance checks (binary, instrument named):** Archetype ability audit and intent fixtures must
show each approved archetype selecting, revealing and resolving its packet ability legally; a
missing archetype, invented effect or intent/result mismatch fails.

**Do-not-decide boundary:** Do not invent ability names/effects, vary named enemies, hand-edit
generated data or resolve #412 beyond R5.

**Depends on:** R5; P3.3; approved enemy-curve packet.

### P3.5 — Encounter templates, spawn breadth and verb coverage

**Title:** [Roadmap P3.5] Encounter templates, spawn breadth and verb coverage

**Milestone:** Proposed `Roadmap Phase 3 — Enemies that play the game`; confirm it exists before
filing.

**Labels:** `delegated-to-codex`

**Objective:** Author enough mechanically varied encounters for the new planner to carry the PRD
verb target in shipped content.

**Scope:** `docs/templates/encounter.md`, authored encounter sources, spawn tables through their
generator, world encounter placement, PR #529's verb audit, and encounter tests.

**Deliverables:** Template verb requirements, content toward PROVISIONAL ~24 encounters,
PROVISIONAL ≥4 spawn-table archetypes reported by a new `tools/audit_spawn_tables.gd`, and
audit-ready speech/context hooks where already approved.

**Acceptance checks (binary, instrument named):** `tools/audit_encounter_verbs.gd` must report the
ratified ≥80% target; spawn-table read must report PROVISIONAL ≥4 archetypes; every new encounter
must instantiate and finish in its fixture. Any miss fails.

**Do-not-decide boundary:** Do not invent enemy lore, locations, abilities, dialogue or canon
encounter outcomes. Do not edit `data/generated/*` by hand.

**Depends on:** R5; P3.3 and P3.4; Phase 0 / PR #529 audit.

### P3.6 — Complete or collapse balance bands

**Title:** [Roadmap P3.6] Complete or collapse balance bands

**Milestone:** Proposed `Roadmap Phase 3 — Enemies that play the game`; confirm it exists before
filing.

**Labels:** `delegated-to-codex`

**Objective:** Remove empty balance states so enemy decisions interact coherently with Breath and
Soul while Soul remains one combat resource among several.

**Scope:** Existing balance-band definitions/effects, approved combat packet, planner scoring,
HUD read-back, and balance tests.

**Deliverables:** An owner-approved complete band set or approved collapse to three, effects on
existing resources, and deterministic transition/read-back coverage.

**Acceptance checks (binary, instrument named):** Balance-band fixtures must reach every retained
band, apply each approved effect once, render its state, and leave no empty band; unreachable,
empty or duplicated effects fail.

**Do-not-decide boundary:** Do not choose between five and three bands, invent effects, alter Soul
identity or create a new combat resource without owner approval.

**Depends on:** R5 answered `approve, five` or `approve, three`; P3.3 and P3.4.

### P3.7 — Telegraph the `dorthkor-vanguard` reinforcement chain

**Title:** [Roadmap P3.7] Telegraph the dorthkor-vanguard reinforcement chain

**Milestone:** Proposed `Roadmap Phase 3 — Enemies that play the game`; confirm it exists before
filing.

**Labels:** `delegated-to-codex`

**Objective:** Stage the first proven beat as the ambient `dorthkor-vanguard` fight on Dorthkor
Road, with successive alerted groups readable before they enter the same CT combat session.

**Scope:** `world/dorthkor_road.tscn`, `actors/hostile/hostile.gd`, `world/field_map.gd`, existing
alert and chain radii, project-owned presentation surfaces, `test/integration/test_dorthkor_road.gd`
and rendered field evidence.

**Deliverables:** Approved same-map hostile placement, a pre-alert telegraph for each group, a
readable propagation boundary, and colour-independent warning cues that preserve the existing
one-hop-per-measure ambient admission behavior.

**Acceptance checks (binary, instrument named):** `test/integration/test_dorthkor_road.gd` and a
rendered slice capture must show the player seeing each warning before contact, the first alert
opening one CT session, and later groups joining without a combat restart. An invisible warning,
AP deployment, chained set-piece path, hue-only cue or restarted session fails.

**Do-not-decide boundary:** Do not invent Dorthkor canon, alter enemy abilities or alert math,
turn this ambient proof into Dorthkor Dead Muster, or claim a headless fixture proves rendered
legibility.

**Depends on:** R15; P3.3; Phase 2 acceptance; approved staging direction. P3.5 runs in parallel and
is needed for Phase 3 acceptance, not for this proof.

### P3.8 — Emit ambient-combat admission events

**Title:** [Roadmap P3.8] Emit ambient-combat admission events

**Milestone:** Proposed `Roadmap Phase 3 — Enemies that play the game`; confirm it exists before
filing.

**Labels:** `delegated-to-codex`

**Objective:** Give presentation code an authoritative event when an alerted actor joins an
already-running ambient CT session.

**Scope:** `globals/battle.gd`, `world/field_map.gd`, `actors/hostile/hostile.gd`, the existing
`Battle.admit()` path and `test/integration/test_combat_session.gd`.

**Deliverables:** A typed admission signal carrying the admitted actor and CT placement needed by
consumers, emitted once from the existing admission path without restarting or duplicating the
combatant.

**Acceptance checks (binary, instrument named):** `test/integration/test_combat_session.gd` must
record one admission event per admitted actor, matching the actor and resulting CT order while
the original session identity remains unchanged. A missing or duplicate event, mismatched actor,
duplicate combatant, reordered existing actor or session restart fails.

**Do-not-decide boundary:** Do not replace CT scheduling, create a second admission path, change
alert propagation, expose mutable battle state through the signal, or route deployed AP
set-pieces through this slice.

**Depends on:** P3.3 and P3.7.

### P3.9 — Show pending reinforcements in the CT strip

**Title:** [Roadmap P3.9] Show pending reinforcements in the CT strip

**Milestone:** Proposed `Roadmap Phase 3 — Enemies that play the game`; confirm it exists before
filing.

**Labels:** `delegated-to-codex`

**Objective:** Let a player distinguish combatants already in CT from alerted reinforcements
that are still pending, then understand an admitted enemy's intent through Old Grumbrand's
existing Sacred Clarity.

**Scope:** `ui/hud/regions/ct_timeline/ct_timeline_region.gd`, `world/field_map.gd`,
`globals/battle.gd`, P3.8's admission event,
`globals/combat/class_resources/stuid_clarity.gd`, existing DS/theme tokens,
`test/integration/test_combat_presentation.gd` and `test/integration/test_enemy_intents.gd`.

**Deliverables:** A pending-reinforcement row, deterministic transition into the live CT order,
shape/text or position cues independent of hue, and intent read-back for admitted enemies when
Sacred Clarity is active.

**Acceptance checks (binary, instrument named):** A rendered CT-strip capture,
`test/integration/test_combat_presentation.gd` and `test/integration/test_enemy_intents.gd` must
identify the next actor, distinguish every pending actor without colour, remove the pending row
entry on admission, preserve CT order, and show the admitted enemy's revealed intent under
Sacred Clarity. A stale/duplicate row, hue-only state, order mismatch or hidden revealed intent
fails.

**Do-not-decide boundary:** Do not invent enemy intents, expose unrevealed intent, change Sacred
Clarity, set a new forecast horizon, add per-node theme overrides or redesign the CT scheduler.

**Depends on:** R15; P3.8; existing Sacred Clarity behavior.

### P3.10 — Serai-Lun killing-or-mercy reaction data

**Title:** [Roadmap P3.10] Serai-Lun killing-or-mercy reaction data

**Milestone:** Proposed `Roadmap Phase 3 — Enemies that play the game`; confirm it exists before
filing.

**Labels:** None — Serai-Lun's reaction and voice remain owner/Claude-owned until approved.

**Objective:** Complete the Phase 3 C+reaction proof with Vex, ungated Serai-Lun and Old
Grumbrand: Serai records and reads back the approved killing-or-mercy outcome without becoming
hostile to Vex.

**Scope:** `dialogue/companions/serai_lun.dialogue`, `globals/companion_barks.gd`,
`globals/game_state.gd`, `globals/save_game.gd`, approved trigger data, localization extraction,
the chapter journey and save round-trip fixtures.

**Deliverables:** Owner-approved killing and mercy reaction data, one trigger at the resolved
slice outcome, a save-compatible durable result, and a later read-back; no ally-to-enemy side
transfer or hostile companion turn.

**Acceptance checks (binary, instrument named):** `test/e2e/test_first_chapter_journey.gd`, save
round-trip coverage and the rendered slice capture must exercise both approved outcomes, fire
only the matching Serai reaction once, preserve it after load, and keep Serai allied. A missing,
duplicate, wrong-outcome or non-durable reaction, a gated-party dependency, or any hostile side
switch fails.

**Do-not-decide boundary:** Do not write Serai's voice, choose a refusal/departure consequence,
invent a loyalty system or hostile-turn cause, change her recruitment gate, or move broader
Phase 4 companion work into this issue.

**Depends on:** R15; P3.7–P3.9; owner approval of the reaction prose and durable outcome.

## Phase 4 — proposed milestone: Roadmap Phase 4 — Company

### P4.1 — PROVISIONAL four-person Chapter 1 party

**Title:** [Roadmap P4.1] PROVISIONAL four-person Chapter 1 party

**Milestone:** Proposed `Roadmap Phase 4 — Company`; confirm it exists before filing.

**Labels:** `delegated-to-codex`

**Objective:** Make PROVISIONAL Vex plus three companions work through recruitment, HUD, travel
and scripted deployment.

**Scope:** `ui/screens/tavern.gd`, `ui/screens/party.gd`, party state/public APIs, follower scenes,
HUD/deployment integration, the Gate T-1..T-5 harnesses and party tests.

**Deliverables:** PROVISIONAL three-of-six tavern recruitment chosen by the player (the hint
"Choose exactly two" becomes three), PROVISIONAL four-member layout/placement, serialized party
state and compatible travel/combat flow.

**Acceptance checks (binary, instrument named):** The Gate T-1..T-5 harnesses
(`test/integration/test_gate_t1_clearability.gd`, `test/integration/test_gate_t2_positional_depth.gd`,
`test/integration/test_wavec_tactical_gates.gd`, `test/unit/test_combat_speech.gd`), party
integration tests and the chapter journey must pass at PROVISIONAL party size four with one party-changed notification per
mutation; overflow, overlap, lost member or bypassed `GameState.set_party()` fails.

**Do-not-decide boundary:** Do not raise the PROVISIONAL Chapter 1 party above four, rewrite
companion canon, or change the ratified later-chapter ceiling of six.

**Depends on:** R6; Phase 3 acceptance.

### P4.2 — Reactive companion bark triggers

**Title:** [Roadmap P4.2] Reactive companion bark triggers

**Milestone:** Proposed `Roadmap Phase 4 — Company`; confirm it exists before filing.

**Labels:** `delegated-to-codex`

**Objective:** Let approved companion voice read back Soul bands, faction bands, hub arrivals and
quest outcomes.

**Scope:** `globals/companion_barks.gd`, existing event signals, approved companion dialogue,
localization extraction, bark audit and tests.

**Deliverables:** Trigger routing, suppression/deduplication, approved bark data and a new
`tools/audit_companion_barks.gd` report.

**Acceptance checks (binary, instrument named):** Bark audit and chapter journey must report
PROVISIONAL ≥12 reactive lines per companion and exactly one appropriate bark per scripted event;
missing coverage, duplicate firing or wrong-companion context fails.

**Do-not-decide boundary:** Do not write companion voice, invent reactions, choose faction/Soul
interpretations or change band thresholds; wire only owner-approved lines.

**Depends on:** R6; P2.3; P4.1; owner prose approval.

### P4.3 — TravelPlan banter beats

**Title:** [Roadmap P4.3] TravelPlan banter beats

**Milestone:** Proposed `Roadmap Phase 4 — Company`; confirm it exists before filing.

**Labels:** `delegated-to-codex`

**Objective:** Give selected journey legs one approved pairwise exchange without disrupting
encounter scheduling.

**Scope:** `globals/travel/travel_plan.gd`, travel events, approved companion dialogue, journey
fixtures and localization extraction.

**Deliverables:** Banter event, deterministic eligible-pair selection, seen/suppression state,
approved pair pool and save coverage where state persists.

**Acceptance checks (binary, instrument named):** The chapter-journey harness must emit one
approved beat on every leg selected for banter, never interrupt combat/avoid prompts, and avoid
repeating a consumed beat under the approved policy; any violation fails.

**Do-not-decide boundary:** Do not write companion voice, set new relationships, alter travel
timing or require banter on a leg outside the approved leg list; the leg list and the pair pool
(PROVISIONAL two exchanges per pair, 15 pairs) go to the owner with the banter prose.

**Depends on:** R6; P4.1; owner prose approval.

### P4.4 — Auditable companion quest outcomes

**Title:** [Roadmap P4.4] Auditable companion quest outcomes

**Milestone:** Proposed `Roadmap Phase 4 — Company`; confirm it exists before filing.

**Labels:** `delegated-to-codex`

**Objective:** Give each companion `FlagQuest` an explicit, serialized consequence that existing
ledgers and read-back systems can observe.

**Scope:** Companion quest resources, `globals/quest_registry.gd`, public Reputation/Renown/Soul
write methods, `tools/quest_audit.gd`, save tests and approved read-back hooks.

**Deliverables:** Outcome arrays, already-ruled +8 Agreement path, ledger writes, save round-trip
and read-back coverage.

**Acceptance checks (binary, instrument named):** `tools/quest_audit.gd` in strict mode
(`SOUL_METER_QUEST_AUDIT_STRICT=1`) and a journey fixture must both show at least one approved
outcome and read-back for every companion quest (the audit's own header documents false passes,
so the fixture is required); the journey/save fixture must apply each write once. Zero-outcome quests, direct ledger mutation or duplicate reward fails.

**Do-not-decide boundary:** Do not invent outcomes, change the ruled +8 Agreement consequence,
merge Reputation with Renown or write companion prose.

**Depends on:** R6; Phase 2 acceptance; P4.1; owner-approved quest outcomes.

### P4.5 — Main-ruling companion interjections

**Title:** [Roadmap P4.5] Main-ruling companion interjections

**Milestone:** Proposed `Roadmap Phase 4 — Company`; confirm it exists before filing.

**Labels:** None — companion voice and ruling interpretation stay owner/Claude-owned.

**Objective:** Place approved companion reactions at the three main-quest rulings without changing
the rulings or their outcomes.

**Scope:** The three existing main-ruling dialogue sources, approved companion prose,
localization extraction and dialogue/journey fixtures.

**Deliverables:** Approved interjection branches for the selected companions, correct party/state
conditions and no outcome mutation.

**Acceptance checks (binary, instrument named):** Dialogue fixtures and the chapter journey must
show the approved interjection only when its companion/state is present at each of the three
rulings; a missing, unconditional or outcome-changing interjection fails.

**Do-not-decide boundary:** Do not rewrite main rulings, choose companion positions, invent voice,
or change Soul/Reputation/Renown consequences.

**Depends on:** R6; P4.2 and P4.4; owner prose approval.

## Phase 5 — proposed milestone: Roadmap Phase 5 — Hours

### P5.1 — Kesselford and Ashlaren side-quest set

**Title:** [Roadmap P5.1] Kesselford and Ashlaren side-quest set

**Milestone:** Proposed `Roadmap Phase 5 — Hours`; confirm it exists before filing.

**Labels:** None — quest design and canon stay owner/Claude-owned.

**Objective:** Add enough consequential side-quest play in Kesselford and Ashlaren to advance the
held playtime floor through choices rather than filler.

**Scope:** `docs/templates/side-quest.md`, approved Kesselford/Ashlaren canon, authored quest and
dialogue sources, existing ledgers, generators, `tools/quest_audit.gd`, and journey fixtures.

**Deliverables:** PROVISIONAL ≥4 side quests in each hub, two approved meaningful outcomes per
quest, Agreement/Paradox routes using the Phase 2 economy, and complete read-backs.

**Acceptance checks (binary, instrument named):** `tools/quest_audit.gd` (strict mode) must report
PROVISIONAL ≥4 new Kesselford and ≥4 new Ashlaren quests, two outcomes and at least one read-back
each, and the chapter total still meeting the PRD's ratified ≥10 side quests with ≥2 outcomes,
every main-quest resolution and ≥60% of side-quest resolutions read back; chapter-journey fixtures must reach both
outcomes without dead ends. Any lower count, missing consequence or soft lock fails.

**Do-not-decide boundary:** Do not invent canon, select quest outcomes without owner approval,
hand-edit generated data or change the Phase 2 Soul economy.

**Depends on:** Fixed R8 = `hold`; Phase 1 and Phase 2 acceptance; owner-approved quest packets.

### P5.2 — Three mandatory main-ruling CT set-pieces

**Title:** [Roadmap P5.2] Three mandatory main-ruling CT set-pieces

**Milestone:** Proposed `Roadmap Phase 5 — Hours`; confirm it exists before filing.

**Labels:** None — main-quest and set-piece design stay owner/Claude-owned until approved.

**Objective:** Hold exactly three unavoidable CT entries (count agreed 2026-10-31; identities
PROVISIONAL, R14): the existing quest-required Dorthkor Dead Muster for The Broken Muster and Empty
Post for The Deep Trial, and a newly authored Hollowmere set-piece tied to The Unanswered Roar
(PROVISIONAL working name; bridge needs owner approval).

**Scope:** `canon/dom/encounters/dorthkor-muster.json`,
`canon/dom/encounters/jawbrace-empty-post.json`, `world/dorthkor_road.tscn`,
`world/wound_lip.tscn`, `world/hollowmere.tscn`, `quests/main/the_unanswered_roar.tres`,
`globals/quest_registry.gd`, Phase 3 CT encounter grammar, `tools/quest_audit.gd` and journey
fixtures.

**Deliverables:** Verified unavoidable entry, CT-order play and retained non-kill resolutions for
the existing Dorthkor Dead Muster (`dorthkor-muster`) and Empty Post (`jawbrace-empty-post`), which
`quests/dorthkor_road.tres` and `quests/deep_trial.tres` already require; an owner-approved narrative bridge
and new Hollowmere set-piece tied to The Unanswered Roar; explicit entry/exit state,
non-kill resolutions where approved, consequences and read-back. The Hollowmere encounter has
only a PROVISIONAL working name until its bridge is approved; no encounter ID is assumed here.

**Acceptance checks (binary, instrument named):** `test/e2e/test_first_chapter_journey.gd`, the
encounter-catalog fixture and `tools/quest_audit.gd` must show exactly these three production
main-ruling entries as unavoidable, each opening and resolving under CT at its approved quest
beat with its consequence recorded. Promoting any other ambient encounter to mandatory, AP-only deployment,
invented Hollowmere identifier, unreachable entry, extra mandatory fight or missing read-back
fails.

**Do-not-decide boundary:** Do not call the Hollowmere encounter “Drowned Watch,” introduce
`hollowmere-roar-consequence`, invent its bridge to The Unanswered Roar, reuse
`dorthkor-vanguard` as Dorthkor Dead Muster, choose unapproved resolutions, or alter ruling 6's
ambient/set-piece boundary.

**Depends on:** R14; fixed R8 = `hold`; Phase 3 and Phase 4 acceptance; owner-approved beats and
Hollowmere bridge.

### P5.3 — Resolve every stub quest

**Title:** [Roadmap P5.3] Resolve every stub quest

**Milestone:** Proposed `Roadmap Phase 5 — Hours`; confirm it exists before filing.

**Labels:** None — finish/cut decisions are product/canon decisions.

**Objective:** Remove ambiguous stub scope from Chapter 1 by naming an owner-approved finish/cut
disposition for each existing `stub_*` quest and carrying it out.

**Scope:** The six stub quest resources (`stub_compromised_message`, `stub_forbidden_ledge`,
`stub_hidden_condition`, `stub_impossible_cadence`, `stub_incomplete_tally`,
`stub_two_muster_rolls`), `docs/owner-decisions.md` only if a new unresolved choice
must be recorded, relevant approved dialogue/quest sources, generators and quest audit.

**Deliverables:** Six explicit finish/cut records and the corresponding approved removals or
finished quest structures.

**Acceptance checks (binary, instrument named):** Stub scan and `tools/quest_audit.gd` must report
every former `stub_*` quest finished or cut, zero undecided stub resources and no dangling
references; any retained unfinished stub, silent promotion, orphaned ID or unrecorded disposition
fails.

**Do-not-decide boundary:** Do not choose a disposition, invent missing canon, delete referenced
content or move an open choice to Answered without the owner.

**Depends on:** Fixed R8 = `hold`; R11 answered for each of the six stubs; P5.1/P5.2 where
content overlaps.

### P5.4 — Playtime clock and critical-path estimator

**Title:** [Roadmap P5.4] Playtime clock and critical-path estimator

**Milestone:** Proposed `Roadmap Phase 5 — Hours`; confirm it exists before filing.

**Labels:** `delegated-to-codex`

**Objective:** Replace playtime estimates with reproducible session and modeled critical-path
evidence.

**Scope:** Existing playtest recorder/session state, chapter journey events, measured dialogue and
combat timing, report export, save/pause behavior, and focused tests.

**Deliverables:** Monotonic active-play session clock, exclusions for pause/loading as approved,
critical-path estimator using measured inputs, and deterministic report.

**Acceptance checks (binary, instrument named):** Clock tests, estimator fixtures and a timed
chapter run must agree within the declared calculation rules; the final report must show a
PROVISIONAL critical path ≥6 hours and a measured completionist path inside the ratified 8–12
hours. Clock drift, pause inflation or an out-of-band result fails Phase 5.

**Do-not-decide boundary:** Do not pad content, change R8, use constants other than PROVISIONAL
200 wpm reading and measured round times, collect personal telemetry or treat a modeled estimate
as a completed human playthrough.

**Depends on:** Fixed R8 = `hold`; P5.1, P5.2 and P5.3; Phase 4 acceptance.

### P5.5 — Talk, Tread or Soul bypass audit

**Title:** [Roadmap P5.5] Talk, Tread or Soul bypass audit

**Milestone:** Proposed `Roadmap Phase 5 — Hours`; confirm it exists before filing.

**Labels:** None — route choice, thresholds, costs and prose remain owner/Claude-owned.

**Objective:** Make every production encounter outside P5.2's three unavoidable set-pieces
bypassable through an authored talk, Tread or Soul route, with a quest result rather than
physical skirting or post-contact flight.

**Scope:** `data/generated/encounter_ids.gd` as generated catalog evidence,
`globals/quest_registry.gd`, existing production placements and dialogue, Phase 2 Soul routes,
`test/unit/test_encounter_catalog.gd`, `test/e2e/test_first_chapter_journey.gd` and
`tools/quest_audit.gd`.

**Deliverables:** The per-encounter bypass matrix from the roadmap's Phase 5 item 5, one row per production encounter with its approved route, whether it exists now and the evidence path, kept current as routes land; verification of `trial-keeper`'s existing
talk/Sway route; approved authored routes for `dorthkor-vanguard`, `bog-wight`, `loam-boar` and
`trial-warden`; and an explicit test-only disposition for every `phase2-*` fixture until it gains
a qualifying route.

**Acceptance checks (binary, instrument named):** The encounter-bypass matrix,
`test/unit/test_encounter_catalog.gd`, `test/e2e/test_first_chapter_journey.gd` and
`tools/quest_audit.gd` must account for every catalog encounter and complete each production
encounter outside P5.2 through at least one authored pre-contact talk, Tread or Soul route with a
recorded outcome. Physical skirting, fleeing after contact, an unplaced fixture promoted to
production, a route without outcome state or any unaccounted encounter fails.

**Do-not-decide boundary:** Do not introduce a separate Stealth stat, choose Tread thresholds or
Soul prices, write dialogue/canon, turn an ambient encounter into a fourth mandatory set-piece,
hand-edit `data/generated/*`, or count skirting/fleeing as a qualifying bypass.

**Depends on:** R14; P2.1; P3.5; P5.2's approved three-set-piece boundary; owner-approved routes.

## Phase 6 — proposed milestone: Roadmap Phase 6 — Teach, test, polish

### P6.1 — Codex teaching entries and first-spend beat

**Title:** [Roadmap P6.1] Codex teaching entries and first-spend beat

**Milestone:** Proposed `Roadmap Phase 6 — Teach, test, polish`; confirm it exists before filing.

**Labels:** None — canon wording and tutorial design stay owner/Claude-owned.

**Objective:** Teach the finished core vocabulary and let the player experience a first informed
Soul spend in the Lower Trial Hall.

**Scope:** Existing codex/journal surfaces, approved entries for Soul, Breath, Agreement,
Hollowing, Accord, Loom and bands, Lower Trial Hall dialogue/flow, localization and journey tests.

**Deliverables:** PROVISIONAL seven owner-approved entries, one approved first-spend beat, unlock
conditions, and re-openable journal access.

**Acceptance checks (binary, instrument named):** Codex coverage scan, Lower Trial Hall fixture and
chapter journey must unlock every approved entry once, show the price before the tutorial spend,
and preserve later access; missing, early, duplicate or unapproved text fails.

**Do-not-decide boundary:** Do not define canon, rename bands, change Soul/Breath mechanics or
invent tutorial fiction.

**Depends on:** Phase 2 and Phase 5 acceptance; owner approval of all wording.

### P6.2 — FR-607 accessibility baseline

**Title:** [Roadmap P6.2] FR-607 accessibility baseline

**Milestone:** Proposed `Roadmap Phase 6 — Teach, test, polish`; confirm it exists before filing.

**Labels:** `delegated-to-codex`

**Objective:** Ship the ratified non-controller FR-607 baseline across gameplay and menus.

**Scope:** `ui/screens/settings.gd`, `ui/screens/settings.tscn`, shared theme/accessibility
surfaces, input actions, animation toggles, approved fonts, representative screens and rendered
captures/tests.

**Deliverables:** Text scaling, colour-independent state cues, input remapping, reduced-motion
toggle, approved font option, persistence and regression coverage.

**Acceptance checks (binary, instrument named):** FR-607 checklist and rendered capture set must
demonstrate every option on representative field, combat, dialogue and menu screens; settings
round-trip must persist. Hue-only information, clipped scaled text, unmapped required action or
ignored reduced-motion setting fails.

**Do-not-decide boundary:** Do not add controller scope, screen-reader claims, new visual
direction, per-node theme overrides or unapproved fonts.

**Depends on:** Phase 5 acceptance; existing FR-607 ratification. No R9 dependency.

### P6.3 — PROVISIONAL functional presentation and Chapter 1 language menu

**Title:** [Roadmap P6.3] PROVISIONAL functional presentation and Chapter 1 language menu

**Milestone:** Proposed `Roadmap Phase 6 — Teach, test, polish`; confirm it exists before filing.

**Labels:** `delegated-to-codex`

**Objective:** Meet the prose-first polish bar with only functional FR-109 battle feedback,
minimum FR-308 Zhavar signaling and an honest Chapter 1 language menu.

**Scope:** Existing casting/hit presentation,
`actors/zhavar_telegraph/zhavar_telegraph.gd`, `actors/zhavar_toll/zhavar_toll.gd`,
`ui/screens/settings.gd`, `locale/es.po`, rendered captures and regression tests. The PROVISIONAL
R16 cut removes ambient beds, new combat stingers and WorldClock tint from this issue and shrinks
casting/hit VFX to functional coverage.

**Deliverables:** Readable casting and hit feedback required by FR-109, minimum Zhavar ambient
signaling and one tolling event required by FR-308, R9-compliant menu visibility, and preserved
Spanish assets; no ambient-bed, new-combat-stinger or WorldClock-tint deliverable.

**Acceptance checks (binary, instrument named):** Rendered presentation captures,
`test/integration/test_combat_presentation.gd`, a Zhavar journey fixture and the localization
source scan must show readable functional casting/hit feedback, the required ambient signal and
tolling event, no Chapter 1 Spanish selector after R9, and an intact `locale/es.po`. Missing
functional feedback or Zhavar signaling, inaccessible state, deleted translation asset or stale
menu entry fails; omitted cinematic polish does not.

**Do-not-decide boundary:** Do not implement the PROVISIONAL cuts before R16, add cinematic
scope, compose ambient beds or new combat stingers, add WorldClock tint, invent VFX direction,
change gameplay timing, translate prose, delete `locale/es.po` or weaken P6.2's FR-607 scope.

**Depends on:** R16; R9 = `defer`; P6.1 and P6.2; approved functional presentation direction.

### P6.4 — Gate T-6 outside-tester evidence

**Title:** [Roadmap P6.4] Gate T-6 outside-tester evidence

**Milestone:** Proposed `Roadmap Phase 6 — Teach, test, polish`; confirm it exists before filing.

**Labels:** None — this is a human ship gate, not delegable test generation.

**Objective:** Collect the unchanged Gate T-6 evidence from real outside testers against the
finished chapter.

**Scope:** `docs/playtest-recruitment.md`, `docs/playtest-protocol.md`,
`docs/playtest-packet.md`, approved build packaging and attached Soul/playtime reports.

**Deliverables:** 3–5 valid owner-run outside-tester packets from a 6–8-person recruitment pool,
the protocol's four questions unchanged, Soul log and playtime reports attached as unscored
context, consolidated failures and traceable fixes/retests.

**Acceptance checks (binary, instrument named):** Gate T-6 passes only when every unchanged
criterion in the playtest protocol is supported by 3–5 valid real packets (majority correct per
question, not averaged); simulated, agent-filled or incomplete evidence fails.

**Do-not-decide boundary:** Agents may prepare materials and summarize evidence but may not act as
outside testers, soften criteria, fabricate sessions or declare the human gate passed.

**Depends on:** Phases 1–5 accepted; P6.1, P6.2 and P6.3; owner item 13 and recruited testers.

### P6.5 — Final FR-904 rendered reference run

**Title:** [Roadmap P6.5] Final FR-904 rendered reference run

**Milestone:** Proposed `Roadmap Phase 6 — Teach, test, polish`; confirm it exists before filing.

**Labels:** None — this is an owner-hardware ship gate.

**Objective:** Produce the unchanged final performance verdict on declared reference hardware
after planner and presentation work is complete.

**Scope:** `docs/fr-904-runbook.md`, `tools/populated_field_benchmark.gd`, the finished build,
declared reference hardware and benchmark evidence paths specified by the runbook.

**Deliverables:** Complete rendered runbook output, hardware/build declaration, raw report and
verdict; advisory decision-time metrics remain separately labeled.

**Acceptance checks (binary, instrument named):** The FR-904 runbook must report steady-state
frame-time p95 ≤16.67 ms with full HUD and battle transitions <2 s on reference hardware. Headless
output, missing samples or a threshold miss fails; the D9 2 ms decision line remains advisory.

**Do-not-decide boundary:** Do not substitute headless/WSLg evidence, change thresholds, hide
outliers, introduce an engaged ceiling or declare a pass without owner-hardware evidence.

**Depends on:** P3.1/P3.3 planner evidence; P6.2 and P6.3 complete; owner item 14.

### P6.6 — Four viable-build playthrough checklists

**Title:** [Roadmap P6.6] Four viable-build playthrough checklists

**Milestone:** Proposed `Roadmap Phase 6 — Teach, test, polish`; confirm it exists before filing.

**Labels:** None — manual playthroughs are owner-run evidence; agents prepare the checklists.

**Objective:** Close PRD §3's "distinct viable builds" metric: four archetypes (martial, caster,
talker, balanced/refusal) complete Chapter 1 without debug tools, separately from Gate T-6.

**Scope:** `docs/playtest-packet.md` checklist templates, the four archetype build definitions,
the session clock from P5.4, and the Soul log export.

**Deliverables:** Four completed playthrough checklists with build, path, session time, Soul
trajectory and any blocker, plus traceable fixes for blockers found.

**Acceptance checks (binary, instrument named):** All four checklists are complete with zero
critical-path blockers and each records a measured session time; an incomplete archetype or a
check simulated by an agent fails.

**Do-not-decide boundary:** Agents may not play as the owner, soften a checklist or merge this
with Gate T-6's outside-tester evidence.

**Depends on:** Phases 1–5 accepted; P5.4 (session clock); P6.1–P6.3.
