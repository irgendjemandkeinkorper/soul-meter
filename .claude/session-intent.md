# Session Intent Contract

**Created:** 2026-08-18
**Command:** /octo:plan

## Job Statement
Review and improve the existing companion quest content in Soul Meter: the six
recruit personal quests (Serai-Lun, Wyneth Hallow-Tide, Old Grumbrand, Ressa
Quickfingers, Korrath Ninefold, Maura Greyfen), their dialogue files in
`dialogue/companions/`, and their quest resources in `quests/` — bringing the
provisional content to canon-review readiness and production quality.

## Context (from intent capture)
- **Goal:** Review/improve existing
- **Knowledge level:** Well-informed (knows options, needs execution)
- **Scope clarity:** Clear requirements
- **Success criteria:** Clear understanding + Team alignment + Working solution + Production-ready
- **Constraints:** Must fit architecture + High stakes

## Known State (from project record)
- All six recruits have authored quests + dialogue (system complete per FR-505,
  user ratified all six over the PRD's 3–5 minimum).
- The three wave-3 dialogue files (ressa_quickfingers, korrath_ninefold,
  maura_greyfen) are marked `PROVISIONAL — CANON REVIEW REQUIRED` (verified
  2026-08-18 — the marker is line 1 of each file).
- None of the six recruit names exist in the lore vault yet — vault entries +
  `Vault Id` bridges are a pending HUMAN canon task.
- Quest audit: 0 errors; new quests emit the same `outcome_count` warning class
  as the accepted quests.
- Resolution path: `QuestRegistry.resolve_companion_quest()` → exactly one
  `Renown.gain_reputation()` event.

## Success Criteria
1. Every companion quest reviewed against the lore vault (do-not-contradict
   check vs `canon/` + `cosmology/`) with findings documented per quest.
2. A concrete canon-review packet the human can act on (per-recruit: proposed
   vault entry stub, contradictions found, prose flagged for revision).
3. Provisional markers resolved or explicitly retained with reasons.
4. Mechanical soundness confirmed: quest audit clean, tests green
   (test_companion_quest.gd, test_party_screen.gd, e2e walkthrough step).
5. No architecture violations introduced (Pandora canonical, ledger write
   paths, Dialogue Manager conventions).

## Boundaries (Do NOT)
- Do not copy provisional prose into the lore vault unreviewed — vault entries
  are a human canon decision; prepare packets, don't commit canon.
- Do not resolve open canon questions (`canon/open-questions.md`) silently.
- Do not add new mechanics; this is content review/improvement within the
  existing companion-quest system.
- Do not edit `addons/` or generated `data/generated/*`.
- High stakes: validation gates (debate/second-perspective review) before any
  content changes merge.
