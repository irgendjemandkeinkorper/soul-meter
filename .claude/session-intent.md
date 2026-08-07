# Session Intent Contract

**Created:** 2026-08-07
**Command:** `/octo:plan`
**Project:** soul-meter (Godot 4.7.1, solo dev)

---

## Job Statement

Re-derive the long-horizon milestone map for Soul Meter from the 25-hour isometric-RPG
vision (Fallout 2 tactical combat + Witcher 3 consequential living world), correcting a
stale premise: the owner's planning brief described the repo as "barebones, basic character
movement only," which has not been true for months.

The mandate is **reset the roadmap, not the mechanics**. The milestone map is re-derived
from first principles against the vision; the mechanical decisions confirmed this session
stand as *inputs* to that derivation, not as things to re-litigate.

---

## Premise Corrections (established this session, evidence-backed)

| Brief claimed | Verified reality |
|---|---|
| Barebones repo, movement only | 14 addons; 2 ratified PRDs; CI; 305-case gdUnit4 suite; combat vertical, dialogue loop, reputation ledger, GLoot inventory all built |
| Needs Dialogue Manager | Installed and wired (`dialogue/*.dialogue`, Echo Gate balloon) |
| Needs Godot State Charts | Installed; `ui/flow/game_flow.tscn` is the root chart |
| Needs isometric TileMapLayer | `world/isometric_blockout.gd` extends `TileMapLayer`; 64×32 iso; 4 locations authored |
| Needs Fallout 2 Action Points | **FR-102 RETIRED 2026-08-05** → charge-time economy (`charge_time_scheduler.gd`) |
| Needs grid combat | FR-105a ratified — but **`GridBattlefieldModel` does not exist**; `zone_battlefield_model.gd` is the only implementation. Largest open build item, gated behind "Gate T" |
| Needs Orchestrator | Not installed. QuestSystem + Dialogue Manager cover this today |
| **Gap the brief was right about** | **Zero `AStarGrid2D` / `NavigationServer2D` / `NavigationAgent2D` anywhere.** Movement is direct `CharacterBody2D` velocity. Buildings are walk-through-able |

---

## Owner Decisions Captured (binding for this plan)

### D1 — Mandate: **Full reset of the roadmap**
Re-derive the milestone map from scratch against the vision. Interpreted as a *planning*
reset; D2 confirms mechanics are not being reopened wholesale.

### D2 — Turn economy: **Charge-time holds**
The 2026-08-05 amendment (FR-102a) stands. No Action Point economy.
`charge_time_scheduler.gd` remains the scheduler. Tactical depth comes from
grid + elevation + facing, not an AP budget.

### D3 — Quest tooling: **Evaluate Orchestrator before deciding**
Not adopted, not rejected. Deliverable includes a proper evaluation: maintenance status,
Godot 4.7 compatibility, and fit against Pandora-as-canonical + existing QuestSystem.

### D4 — Overworld movement: **Click-to-move, Fallout 2 style**
`AStarGrid2D` over the isometric `TileMapLayer`; click a tile, path there; obstacles baked
from a collision tile layer. Chosen partly because the tactical grid reuses the same
`AStarGrid2D` for movement range and path cost — one technology, two layers.

### D5 — Soul Meter: **Canon holds — downward-only wound count**
Per `dramgid-vault/cosmology/souls.md`: magic spends the Gauge, it mostly only goes down,
zero = unravelling / husking-while-alive, recovery is slow, partial, and social.
**No high-end penalty.** The brief's "too high or too low" framing is rejected in favour of
canon. No vault amendment required. `clampf(soul_meter, 0.0, 100.0)` stays.

### D6 — Living world: **Middle tier**
World day/night clock + hand-authored routines for ~10–15 named NPCs in the 3 hubs only;
everyone else stays static on flag/rep-keyed reactivity.
⚠ **This partially overturns ratified FR-504** ("no full NPC schedules in v1") and therefore
requires a PRD amendment, not a silent widening of scope.

### D7 — Horizon: **Chapter One to ship quality**
Plan only what ships one complete 15–25h region (8–12 locations, 3 hubs) with Act II hooks.
Later chapters get a sketch, not milestones.

### D8 — Deliverables: **all four**
1. Roadmap markdown doc in `docs/`
2. Real GitHub milestones + issues on `irgendjemandkeinkorper/soul-meter`
3. Architecture doc for the four named systems
4. Orchestrator evaluation writeup

---

## Success Criteria

- [ ] Roadmap is derived from the *verified* repo state, never from the stale brief
- [ ] Every ratified FR is either carried, amended with justification, or explicitly retired —
      nothing changes by silence
- [ ] The two unproven gates (Phase 1.5 comprehension gate, Gate T) appear as blocking
      milestones, not as optional checkpoints
- [ ] Architecture doc gives concrete Godot scene/script structure, not prose
- [ ] GitHub issues are self-contained and labelled per the codex/gemini/jules routing policy
- [ ] D6's FR-504 overturn is filed as a PRD amendment, not smuggled in

## Boundaries — what this plan must NOT do

- Must not re-open FR-102a (charge-time) or FR-105a (grid) — D2 settles these
- Must not resolve open canon questions (#132 three-jobs-vs-ten-patrons, respec, ancestry
  picks) — surface them, do not rule on them
- Must not edit anything under `addons/` (except project-owned `soul_meter_tools`)
- Must not hand-edit `data/generated/*`
- Must not introduce `change_scene_to_file()` — GameFlow events only
- Must not merge region content into `world/locations/` or `LocationRegistry.ALL` before the
  Phase 1.5 comprehension gate passes (3–5 outside human playtesters — an agent fleet cannot
  execute this)
- Must not plan later chapters in milestone detail (D7)

## Context

- **Knowledge level:** Expert on own project; the stale brief reflects delegation to an
  external assistant lacking repo access, not owner unfamiliarity
- **Clarity:** High after this session's 8 decisions
- **Constraints:** Solo dev; two ratified PRDs to respect or formally amend; two unproven
  human-gated quality gates; `godot --headless --script` exits 134 ~20–30% of the time at
  teardown (never gate CI on a tool script's raw exit code)
