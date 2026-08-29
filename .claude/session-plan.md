# Session Plan — Fallout 2 Gameplay Flow Rework

**Created:** 2026-08-28
**Intent Contract:** See .claude/session-intent.md
**Goal (verbatim):** "we need to make this game play flow and function MUCH more like fallout 2"

## What You'll End Up With

Soul Meter playing much more like Fallout 2, production-ready on `main`:
1. **A ratified spec amendment first** — your in-head Fallout 2 spec captured
   verbatim, mapped system-by-system onto the existing architecture
   (what changes / what stays / what is explicitly rejected), and ratified as a
   design-doc/PRD addendum. No silent canon resolution.
2. **The implemented feel shift** — the changed loops playable end-to-end from
   a new game, landed in tested waves with the suite green and quest-audit clean.

Likely Fallout 2 axes the spec will rule on (to be confirmed by YOUR list, not
assumed): open world-map travel with random encounters vs. the current
discovered-hub graph; skill-check-driven dialogue with speech/barter depth;
AP-based tactical combat feel vs. the CT scheduler (Gate-T-ratified — evolve,
don't rewrite); reputation/karma surfacing (Reputation/Renown ledgers already
exist — presentation gap, not data gap); loot/scavenging density; quest
structure with multiple resolution paths.

## How We'll Get There

### Phase Weights
- **Discover: 10%** — Bounded research only where your spec cites Fallout 2
  behavior that needs precise mechanical definition (delegate to Gemini;
  Claude synthesizes). No open-ended study — you have the spec.
- **Define: 20%** — THE CRITICAL PHASE. Elicit your full spec, write the
  amendment, map each item to keep/evolve/replace per system, flag every
  [CANON] collision and Gate-T touch, get your ratification. 🔸 DEBATE GATE.
- **Develop: 40%** — Implement in waves ordered by feel-impact-per-risk;
  Codex takes bounded implementation handoffs after Claude fixes architecture
  per wave. Systems/existing-scenes only until #93 clears region content.
- **Deliver: 30%** — Per-wave: suite + quest audit + screenshot sweep +
  playthrough evidence; final: acceptance against the ratified amendment.
  🔸 DEBATE GATE. (High-stakes constraint → validation-heavy.)

### 🐙 Debate Checkpoints
- **After Define:** "Does this adoption list actually produce the Fallout 2
  feel without breaking the ratified spine?" — 1-round adversarial
  (Claude + Codex + Gemini) before you ratify.
- **After Develop:** "Does this play like Fallout 2 now — and is it ready to
  ship?" — 1-round collaborative on edge cases before final acceptance.

### Execution Commands
To execute this plan, run:
```bash
/octo:embrace "make Soul Meter's gameplay flow and function much more like Fallout 2, per .claude/session-intent.md"
```

Or execute phases individually:
- `/octo:define` (Define ≥ 20%)
- `/octo:develop` (Develop ≥ 20%)
- `/octo:deliver` (Deliver ≥ 20%)

## Provider Requirements
🔴 Codex CLI: Available ✓
🟡 Gemini CLI: Available ✓
🧭 Antigravity CLI: Not installed ✗
🟤 OpenCode: Not installed ✗
🟢 Copilot CLI: Available ✓
🟠 Qwen CLI: Not installed ✗
⚫ Ollama: Not installed ✗
🔵 Claude: Available ✓
🟣 Perplexity: Not configured ✗

## Success Criteria
1. Spec captured verbatim and ratified as a written amendment before code.
2. Game plays differently in hand; changed loops playable from a new game.
3. Every wave on `main` with tests, suite green, quest audit clean.
4. Gate-T semantics evolved, never silently rewritten.

## Boundaries (from intent contract)
- No silent canon resolution; no five-layer architecture rewrite.
- No region-content merges until #93 passes — target systems + existing scenes.
- #93 playtest and FR-904 benchmark stay human-gated, unaffected.

## Ratified Rulings (owner, 2026-08-28)

Both Define-phase hot spots were ruled on before execution ("yes to both"):
1. **CT scheduler may change** — AP-based Fallout 2 combat feel authorized.
   ApRoundScheduler already exists behind the scheduler seam
   (globals/combat; the seam reads `actor.side` live and was built for this),
   so the first Develop wave is a scheduler promotion + feel pass, not a rewrite.
2. **World-map travel supersedes FR-503** — the discovered-hubs-at-a-cost
   design gives way to Fallout 2-style overworld travel (map marker, travel
   time, random encounters interrupting travel). FastTravelRegistry +
   region_map.tscn are the base to evolve.

The Define phase no longer needs to litigate these two; it still needs the
rest of your spec list.

## Next Steps
1. Review this plan
2. Adjust if needed (re-run /octo:plan)
3. Execute with /octo:embrace when ready — its Define phase opens by taking
   down your Fallout 2 spec list item-by-item
