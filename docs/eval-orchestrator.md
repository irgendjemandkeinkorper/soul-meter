# Addon Evaluation — Orchestrator (visual scripting)

**Status:** EVALUATION COMPLETE — recommendation below
**Date:** 2026-08-07 · **Evaluator:** agent, on owner request
**Subject:** `CraterCrash/godot-orchestrator` (Godot asset library id 3209)
**Owner deferred this decision pending a proper evaluation.** This document is that
evaluation.

---

## 0. Correction to the brief

The task framed Orchestrator as "a visual quest/dialogue graph editor." That framing is
**not accurate**. Verified from the project README and asset-library listing:

> "Orchestrator is the ultimate visual scripting solution designed for the Godot 4.2+
> platform... hundreds of nodes to build any game logic."

Orchestrator is a **general-purpose visual scripting tool**. It is a graphical alternative
to writing GDScript, not a quest system and not a dialogue system. It does list "design
complex dialogue conversations for NPCs" as one feature among many, but this is a demo of
general flow-control nodes, not a dedicated dialogue authoring format. It has no notion of
quests at all.

This correction changes the shape of the fit question. Orchestrator does not compete
directly with Dialogue Manager or QuestSystem as a content format. It competes with
**GDScript itself** as a way to write logic.

---

## 1. Maintenance status — VERIFIED (GitHub API, 2026-08-07)

| Signal | Value |
|---|---|
| Latest stable release | `v2.5.stable`, published 2026-07-04 |
| Most recent commit (main) | 2026-08-03 |
| Repo last pushed | 2026-08-04 |
| Open issues | 130 |
| Closed issues | 763 |
| Open pull requests | 11 |
| Stars | 1,604 |
| Archived | No |

Commit cadence in the last release window (2026-08-01 to 2026-08-03) shows multiple commits
per day. The project is **actively maintained** by a small team (commits mostly from one
maintainer, `Naros`, in the sample pulled).

**Conclusion:** maintenance status is healthy. This is not a stale or abandoned addon.

---

## 2. Godot 4.7 compatibility — VERIFIED

The project's own compatibility table (fetched from the README) states:

| Godot version | Orchestrator version | Support level |
|---|---|---|
| 4.8.x | v2.6.x | Active development |
| 4.7.x | v2.5.x | Bug fixes and compatible new features |
| 4.6.x | v2.4.x | Bug fixes only |
| 4.2.x–4.5.x | (older) | No longer supported |

Soul Meter pins **Godot 4.7.1-stable**. `v2.5.stable` (released 2026-07-04) targets exactly
this line. **Compatibility is confirmed, not inferred.**

Orchestrator ships as a **GDExtension** (compiled binary per platform), not pure GDScript.
This is a different distribution model from every other addon in `DEPENDENCIES.md` except
none — all 12 addons currently installed are GDScript or script-only. A GDExtension adds a
new class of risk: binary compatibility across Godot patch releases, and a per-platform
build step for exports (Windows x64, per `DEPENDENCIES.md`'s CI export target).

---

## 3. Fit against what already exists — the decisive section

### 3.1 Measured content inventory

| Artifact | Count | Source |
|---|---|---|
| `.dialogue` files | 7 | `dialogue/*.dialogue` |
| Quest resources (`.tres`) | 15 | `quests/*.tres` |
| `globals/quest_registry.gd` | 475 lines | reachable-by-expression quest const registry |
| Installed addons | 12 | `addons/` directory, matches `DEPENDENCIES.md` table |

Soul Meter already has a working, populated dialogue and quest pipeline. This is not a
greenfield decision.

### 3.2 The existing pipeline

Per `docs/godot-architecture.md` and `DEPENDENCIES.md`:

- **Data:** Pandora is canonical. Nothing writes back to it. Generated artifacts
  (`data/generated/`) are one-way and never hand-edited.
- **Narrative:** Dialogue Manager owns `.dialogue` text files (chosen because they diff
  cleanly in git). QuestSystem owns quest lifecycle and state.
- **Bridge layer:** `globals/quest_registry.gd` exists specifically because Dialogue
  Manager's `do`/`if` expressions cannot `preload()` a `.tres` inline. This is a deliberate,
  narrow glue layer — not a general integration surface.
- **Five-layer rule:** Flow → Presentation → Systems → Narrative → Data. Dependencies point
  down only. Orchestrator, as a general scripting layer, does not map cleanly onto any one
  layer — it could touch all five, which is itself a design smell per the architecture doc's
  own stated test ("if you find yourself wanting an upward reference, that's a design
  smell").

### 3.3 The load-bearing question

**Does Orchestrator conflict with Pandora-as-canonical or with Dialogue Manager +
QuestSystem?**

Answer: **not directly, because Orchestrator does not own data.** It has no resource format
for quests or dialogue lines. It is a node-graph way to write behavior, comparable to
GDScript or Godot's built-in VisualScript (which Godot 4 dropped). It would not create a
second data authority over quest or dialogue content.

The real conflict is different and narrower: **Orchestrator would create a second way to
write logic**, alongside GDScript, in a single-maintainer project. Every existing script in
`globals/`, `actors/`, `ui/`, and the Dialogue Manager mutation/condition callbacks
(`DIALOGUE MANAGER quirks` in `DEPENDENCIES.md`) is GDScript. Introducing a second authoring
format for the same job — control flow, function calls, signal handling — splits searchability
(`rg` cannot grep a binary graph resource), splits code review (`git diff` on a `.tres`
graph is not readable the way `.dialogue` text files were deliberately chosen to be), and
splits the mental model for a solo developer.

**Verdict: no data-authority conflict with Pandora. A real authoring-surface conflict with
plain GDScript, and a real diffability conflict with the "text formats diff cleanly" reason
Dialogue Manager was chosen.**

---

## 4. Migration cost if adopted

Nothing in the current pipeline requires migration — Orchestrator does not replace Dialogue
Manager, QuestSystem, or Pandora. Adoption cost is **additive**, not migratory:

- Add a GDExtension binary dependency, with per-platform builds. This is new to the project;
  every current addon is script-based.
- Add a new file type (`.tres`-backed Orchestrator graphs) to review, that does not diff
  cleanly in git, unlike the text-format choices already made deliberately elsewhere.
- Decide, and document, which logic goes in GDScript vs. Orchestrator graphs — an ongoing
  governance cost with no natural boundary, since Orchestrator can touch any layer.
- Extend `DEPENDENCIES.md` and `docs/godot-architecture.md` with a new addon entry and a new
  rule for where graphs are and are not allowed (e.g., "never for logic Pandora or Dialogue
  Manager already resolves").
- CI: the Windows export workflow (`.github/workflows/test.yml`) would need to confirm the
  GDExtension binary is present for the export target and does not break `--headless --import`.

No existing quest or dialogue file needs to move. No Pandora entity needs to change.

---

## 5. Cost of NOT adopting

**What problem was Orchestrator supposed to solve?** The task brief assumed it would solve
quest/dialogue graph authoring. That assumption does not hold — Orchestrator has no
quest/dialogue-specific data model, so it would not have solved that problem even if
adopted.

**Is the actual problem — visual logic authoring — currently unsolved?** No. GDScript
already covers it, and the project's conventions (`CLAUDE.md`: "GDScript: static typing,
snake_case files/vars... signals over polling") assume GDScript throughout. There is no
recorded pain point in `CLAUDE.md`, `docs/godot-architecture.md`, or `DEPENDENCIES.md` about
logic being hard to author, review, or maintain in GDScript. No open FR in the PRD or
architecture doc names visual scripting as a gap.

**Conclusion: not adopting costs nothing measurable today.** There is no unsolved problem in
this codebase that Orchestrator is positioned to close.

---

## 6. RECOMMENDATION

**REJECT — do not adopt Orchestrator.**

Reasons, in order of weight:

1. It does not do what the brief assumed (quest/dialogue graph authoring). It is a
   general visual-scripting layer with no quest or dialogue data model.
2. It solves no problem this project currently has. GDScript already covers the job it
   would compete for.
3. It would add a GDExtension binary dependency — a new risk class not present in any of
   the 12 addons already installed — for a capability (visual logic graphs) the project has
   not asked for.
4. It would work against a deliberate existing decision: Dialogue Manager's text format
   was chosen specifically because it "diffs cleanly in git." A second, binary-resource
   authoring surface undercuts that reasoning for any logic written in it.

**Strongest argument for the opposite choice (adopt):** Orchestrator is healthy and
well-maintained (confirmed: daily commit cadence, 1,604 stars, active 4.7.x support track),
and a visual graph editor can lower the bar for tuning small pieces of behavior (e.g. simple
NPC state machines or one-off cutscene logic) without touching GDScript files, which could
matter if the owner brings on a non-programmer collaborator later.

**What evidence would change the answer:** a named, current problem GDScript cannot solve
well — e.g. a specific NPC behavior or cutscene-scripting task that is proving slow or
error-prone to hand-write — or a second team member joining who is not comfortable in
GDScript. Absent either, revisit only if that changes; do not re-open this evaluation
without a concrete trigger.

---

## Verified vs. inferred

**Verified** (GitHub API + README fetch, 2026-08-07): release/commit/issue/star counts,
Godot version support table, GDExtension distribution model, dialogue file count (7), quest
resource count (15), installed addon count (12).

**Inferred** (architecture reasoning, not measured): the "authoring-surface conflict" and
"diffability conflict" arguments in §3.3 are this evaluator's analysis against
`docs/godot-architecture.md`'s stated design rules, not a documented incident in this
project.

**Not reachable:** none. Network access was available; all sections above are backed by a
citation.
