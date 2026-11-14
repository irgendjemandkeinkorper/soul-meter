# Session Intent — Two-week roadmap, 15 system-design questions, issues filed (2026-11-08)

## Job statement

Re-evaluate the open GitHub issues, the open PRs and the roadmap (`docs/roadmap-2026-10-30.md`,
landing in #591). Ask the owner 15 targeted game-system design questions. Each question has
best-guess options plus one "random" option that differs from the others. Then file GitHub
issues that hold the next two weeks of work (2026-11-09 → 2026-11-22), so every lane works from
the same list.

## Intent answers (2026-11-08)

| Question | Answer |
|---|---|
| Goal | Build something: the artifacts are the re-evaluation, the answered questions and the filed issues |
| Knowledge | Well-informed |
| Clarity | Clear requirements |
| Success | Clear understanding + Team alignment + Production-ready |
| Constraints | High stakes |

## Success criteria

1. **Re-evaluation.** Every open issue (19) and open PR (~26) is sorted into one bucket:
   - lands with the 2026-11-07 chain (close after merge);
   - live engineering;
   - owner lane (art, prose, playtest);
   - stale (a milestone or premise that no longer holds).

   Each entry carries one line of evidence (a commit, file or PR).
2. **15 questions.**
   - Each targets a game-system choice the next two weeks need and that is not already ratified.
   - Each has 2–3 grounded best guesses plus one distinct "random" option.
   - They are asked in rounds of ≤4.
   - Answers go to `docs/owner-decisions.md` with the date and the owner's words. Nothing is
     resolved silently.
3. **Roadmap doc.** `docs/roadmap-2026-11-08.md` turns roadmap Phases 1→3 into a dated two-week
   sequence. It applies the answers and keeps every tuning number PROVISIONAL.
4. **Issues (production-ready).**
   - One issue per bounded task: objective, allowed scope, acceptance checks, a "do not decide"
     line and dependencies (`Blocked by #N`).
   - A milestone per phase slice with due dates.
   - Existing labels only: `delegated-to-codex` for Codex, `jules` for Gemini/Jules work;
     Claude-owned design issues stay unlabelled.
5. **Stale items.** Close or retitle proposals are listed for the owner. Agents do not close issues.

## Boundaries

- Do not reopen ratified rulings (`docs/phase-0-ratification.md`, roadmap R1–R16 answered
  2026-10-31, owner-decisions §5). A question may refine a PROVISIONAL number or an unruled
  mechanic, never a ratified one.
- No invented canon. A question touching lore cites `../dramgid-vault` or `canon/`, or is marked
  as needing a canon ruling.
- The owner's graphics lane stays the owner's: `assets/`, `*.gdshader`, `design/`, `ui/theme/`,
  art tools, #538/#539/#565. The plan may schedule it, never assign it to an agent.
- Owner-only actions: merging, closing issues or PRs, deleting branches.
- Labels: never invent one. Workers do not change labels or assignees.
- "Random" options are design-space probes. If one is chosen it is recorded as chosen, and it
  is PROVISIONAL like every other answer.

## Context

- Landing chain (2026-11-07, verified locally): #588, #583, #585, #593 → #586 → #587 → #589 →
  #591, then #590; #592 any time. Merged, it carries Phase 0 + Phase 1 (P1.1–P1.4, P1.2a–f) and
  the roadmap doc. 3,073 cases green in CI order.
- Still open on Phase 1: P1.5 fast-travel verification (#534, `jules`) and P1.6 production
  Zhavar writers (#535).
- Next roadmap phases: Phase 2 Soul (≈7 sessions), Phase 3 Enemies (≈11 sessions), Phase 4
  Company (≈7). Owner capacity: ~20 h/week (2026-10-31).
- Past-due or premise-changed milestones: "Steam PC launch (Ch1) — 2026-10-02" (#282, #301 open);
  Gate T (#93, #175); Visual Alignment M0 (#112, #115).
- Provider notes (2026-10-31): Gemini's CLI was failing at dispatch and Qwen failing; Codex
  and Copilot carried debate gates.
