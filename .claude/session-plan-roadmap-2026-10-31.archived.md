# Session Plan — Blank Combat Stage: Grid by Default

**Created:** 2026-08-29
**Intent Contract:** See .claude/session-intent.md
**Goal (verbatim):** "combat screen is still just blank"

## What You'll End Up With

Real battles that render and play on the tactical grid: terrain tiles, unit sprites,
hover AP quotes, click-to-move, LOS/cover/flank — the Wave P layer, reachable in
actual play instead of only in tests. Verified by a regression test, a screenshot,
a green suite, and a codex delivery gate.

## Root cause (diagnosed, not speculative)

All 12 authored encounters lack `grid` → `Battle._battlefield_for_definition()`
returns the ZONE model → the six-region stage draws only grid battles (zone
snapshots carry no tiles) and the legacy zone presentation is gone from the unified
screen → blank center. Confirmed against `data/generated/encounters.json` (0 of 12
with grid) and the screenshot (all six regions render; stage empty).

## How We'll Get There

### Phase Weights
- Discover: 5% — DONE (root cause pinned this session; no further research).
- Define: 10% — default-grid sizing rule (PROVISIONAL): derive dimensions from
  combatant counts (e.g. max(6, needed) × max(4, rows)), authored `grid.dimensions`
  always wins; decide where the synthesis lives (extend
  `_battlefield_for_definition`'s existing else-branch — the TileMapLayer synthesis
  code is already there for authored grids).
- Develop: 55% — implement default-grid synthesis in `globals/battle.gd`; keep zone
  reachable for tests/fallback (a `use_zone` escape hatch in the definition, or the
  invalid-grid warning paths keep returning zones); regression test (encounter with
  no authored grid → snapshot tiles non-empty → stage `rendered_tile_count() > 0`);
  check the enemy-AI/deployment interplay on synthesized grids.
- Deliver: 30% — full suite; xvfb screenshot of a real battle; strict-audit
  reporting run; codex delivery gate (REVISE-loop to PROCEED); push + delivery-log
  note under Wave P ("grid by default" follow-up ruling).

### Execution Commands
To execute this plan, run:
```bash
/octo:embrace "make real battles run on the tactical grid by default so the combat stage renders (see .claude/session-intent.md)"
```
Or (session's established pattern) Claude dispatches a bounded tangle for Develop
and a manual codex gate for Deliver.

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
(From intent contract) 1. tiles+units render in any authored encounter, pointer
moves work; 2. regression test for the no-authored-grid path; 3. suite green +
screenshot + gate PROCEED + pushed.

## Next Steps
1. Review this plan
2. Adjust if needed (re-run /octo:plan)
3. Execute when ready
