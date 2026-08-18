# Session Plan

**Created:** 2026-08-18
**Intent Contract:** See .claude/session-intent.md

## What You'll End Up With
A per-recruit canon-review packet for all six companion quests (contradiction
findings vs the Dramgid vault, proposed vault-entry stubs for human sign-off,
prose flagged for revision), plus agreed prose improvements applied to
`dialogue/companions/` — with `tools/quest_audit.gd` clean and the
companion-quest test suites green.

## How We'll Get There

### Phase Weights
- Discover: 20% — Cross-check each of the six quests against the Dramgid vault
  (`canon/` + `cosmology/` are do-not-contradict; follow `related` ids from
  `index.json`). Output: per-quest findings list.
- Define: 15% — Lock per-quest "canon-ready" criteria; enumerate anything that
  touches `canon/open-questions.md` so nothing gets resolved silently.
- Develop: 30% — Author the six canon-review packets (vault entry stub +
  contradiction findings + prose flags per recruit); revise flagged dialogue
  prose where it doesn't require a canon decision.
- Deliver: 35% — High-stakes validation: debate gate, quest audit
  (`SOUL_METER_QUEST_AUDIT_STRICT=1`), gdUnit4 suites
  (test_companion_quest.gd, test_party_screen.gd, e2e walkthrough step).

### 🔸 Debate Checkpoints (high-stakes constraint → enabled)
- After Define: "Are the canon-ready criteria right, and do any quests conflict
  with do-not-contradict lore?" (1 round, adversarial)
- After Develop: "Is this content ready for human canon sign-off?" (1 round,
  adversarial)

### Execution Commands
To execute this plan, run:
```bash
/octo:embrace "Review and improve the six companion quests to canon-review readiness"
```

Or execute phases individually:
- `/octo:discover` (Discover ≥ 20%)
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
1. Every companion quest reviewed against the lore vault with findings
   documented per quest.
2. A concrete canon-review packet the human can act on per recruit.
3. Provisional markers resolved or explicitly retained with reasons.
4. Quest audit clean; companion-quest tests green.
5. No architecture violations (Pandora canonical, ledger write paths,
   Dialogue Manager conventions).

## Hard Boundaries
- No writes to the Dramgid vault — packets only; canon is a human decision.
- No silent resolution of `canon/open-questions.md`.
- No new mechanics; no `addons/` or `data/generated/*` edits.

## Next Steps
1. Review this plan
2. Adjust if needed (re-run /octo:plan)
3. Execute with /octo:embrace when ready
