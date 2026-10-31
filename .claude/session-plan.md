# Session Plan — Roadmap revisit, senior game designer lens

**Created:** 2026-10-30
**Intent Contract:** See `.claude/session-intent.md`
**Subject:** draft PR #528 (`docs/roadmap-2026-10-30.md`) and its Phase 0 PR #529

## What you'll end up with

A ratifiable revision of the 2026-10-30 roadmap that:

1. Leads with **Fallout-full freedom** (rulings 7–9) instead of Soul-first, with the designer's
   one-paragraph argument for the order and what it costs.
2. Re-sequences Phases 1–5 so the cheapest-per-feeling, least-prose work lands first, and every
   phase shows its owner rulings, agent work and **prose load** separately (solo-dev capacity).
3. Argues the **~100-mob challenge (ruling 5)** from evidence and ends in one owner line:
   keep ~100 as a *presence* floor on the map, bound the *engaged* set in the CT order
   (recommendation R10, PROVISIONAL, never a ruling until the owner answers).
4. Keeps the ship posture the owner chose: playable and polished before gold, 8–12 h held (R8),
   Gate T-6 and FR-904 untouched.
5. Ships as: the revised roadmap doc, an updated owner-list item 26 (R1–R10 as one-line answers),
   and a file-ready issue packet with acceptance checks and do-not-decide boundaries. Nothing is
   filed, labelled or merged without the owner's go.

## The designer's starting position (to be tested in Define, not assumed)

- **Why field-first fits this owner.** The field verbs exist once each as proofs (one lock, one
  pocket, two loot tables, barter with no screen). Making them dense is scene authoring and data,
  not dialogue prose, so it is the loop a solo dev can fill fastest. It is also the loop that makes
  DRAMGID visible outside conversation, which rulings 8–9 promise and the build does not deliver.
- **What it costs.** PR #528 put Soul first because rulings 1–3 are the identity. Moving Soul to
  second means the Paradox routes (prose-heavy) are written against a denser world, which is a
  gain, but the identity hook ships later in the sequence. The Soul log and level-up notice from
  Phase 0 (PR #529) stay first regardless; they are instruments, not content.
- **Ruling 5 evidence.** Headless frame p95 0.29–0.46 ms (holds). AI decision mean 11.2 ms against
  a 2 ms advisory. Spawn tables draw on 2 of 6 archetypes. Any intent planner must be batched to
  survive 100 deciders. Fallout 2's big fights were tens of combatants, not a hundred. A presence
  floor with an engaged ceiling keeps ruling 6's "alerted mobs join" and frees Phase 2 to make
  enemies smart instead of merely numerous.

## How we'll get there

### Phase weights

- **Discover: 15%** — The inventories exist (PR #528, today). Fill three gaps: the field-verb
  authoring surface per shipped hub (Dom, Kesselford, Ashlaren, Long Verge, Hollowmere), the
  engaged-set numbers behind ruling 5 (alert radius, leash, admitted-per-round from the benchmark),
  and whether anything in the 2026-08-02 Obsidian demo roadmap is still live. Bounded reads;
  delegate to Explore/Gemini.
- **Define: 30%** — The vision paragraph, the re-sequence, per-phase prose load, R10 argued, and
  the acceptance numbers per phase (an audit tool or harness for each). Owner checkpoint at the end.
- **Develop: 30%** — Write the revision into `docs/roadmap-2026-10-30.md` on PR #528's branch
  (`roadmap-2026-10-30`), update `docs/owner-decisions.md` item 26 with R1–R10, draft the issue
  packet (`docs/roadmap-issues-2026-10-30.md`). Codex may draft issue bodies from a template;
  Claude owns sequence and wording.
- **Deliver: 25%** — Multi-LLM review of the revised roadmap against the ten rulings and PRD §3,
  acceptance-criteria audit (every phase has a number and an instrument), and the final owner
  ratification packet. High stakes: debate gates on.

### 🐙 Debate checkpoints

- 🔸 **After Define:** "Is field-first the right order for a solo dev shipping a high-stakes first
  release, and does R10 (presence floor + engaged ceiling) honour rulings 5 and 6?" 1-round
  adversarial, Claude plus Codex/Gemini/Kimi.
- 🔸 **After Develop:** "Is this roadmap revision ratifiable as written: every phase gated by a
  number, every ruling posed as one line, nothing ratified reopened except ruling 5?" 1-round
  collaborative.

### Proposed phase order to test (PR #528 → revision)

| PR #528 | Revision | Why |
|---|---|---|
| 0 Quick wins | 0 Quick wins (PR #529, unchanged) | Instruments first |
| 1 Soul | **1 Fallout-full field** (was 4) | Chosen first feeling; least prose; makes stats visible |
| 2 Enemies | **2 Soul: make the meter mean it** (was 1) | Paradox routes now attach to a dense world; Soul-costing field shortcuts become possible |
| 3 Company | **3 Enemies that play the game**, scoped by R10 | Intent planner sized to the engaged set, not to 100 deciders |
| 4 Field | 4 Company | Prose-heaviest systems phase; sequenced after the world it reacts to |
| 5 Hours | 5 Hours | Unchanged; content written against fixed economy and enemy grammar |
| 6 Teach, test, polish | 6 Teach, test, polish | Unchanged; owner gates 13 and 14 |

### Execution commands

```bash
/octo:embrace "Revise the 2026-10-30 roadmap (PR #528) as a senior game designer: field-first order, R10 on the 100-mob floor, per-phase prose load, ratifiable packet"
```

Or by phase:
- `/octo:discover` (bounded gap-fill, 15%)
- `/octo:define` (vision + re-sequence + R10, 30%) → `/octo:debate` checkpoint
- `/octo:develop` (doc + item 26 + issue packet, 30%) → `/octo:debate` checkpoint
- `/octo:deliver` (multi-LLM review + ratification packet, 25%)

## Provider availability (measured 2026-10-30)

🔴 Codex CLI: Available ✓
🟡 Gemini CLI: Available ✓
🧭 Antigravity CLI: Not installed ✗
🟤 OpenCode: Not installed ✗
🟢 Copilot CLI: Available ✓
🟠 Qwen CLI: Available ✓
⚫ Ollama: Available ✓
🔵 Claude: Available ✓
🟣 Perplexity: Not configured ✗

Roles per the global policy: Claude designs and synthesises; Codex drafts issue bodies and any
audit-tool changes; Gemini/Explore do the bounded reads; Kimi is the non-Anthropic, non-OpenAI
reviewer at the debate gates.

## Success criteria (from the intent contract)

1. Field-first order argued in one paragraph, with its cost stated.
2. Every phase lists rulings, agent work and prose load separately.
3. R10 argued from evidence; ends in one owner line; ruling 5 unchanged until answered.
4. Every phase has binary acceptance criteria and an instrument that reports the number.
5. Issues file-ready and labelled per policy; none filed without the owner's go.
6. Nothing ratified reopened except ruling 5; nothing in `docs/owner-decisions.md` resolved silently.

## Your involvement

Checkpoints. Two owner reads of ~15 minutes each: after Define (order + R10) and after Develop
(the packet). Everything else runs without you.

## Time estimate

About five working sessions: Discover 1, Define 1, Develop 2, Deliver 1. Owner time ~30 minutes
total across the two checkpoints.

## Next steps

1. Review this plan.
2. Adjust if needed (re-run `/octo:plan`).
3. Execute with `/octo:embrace` when ready.
