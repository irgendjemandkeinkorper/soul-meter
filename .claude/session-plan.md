# Session Plan — Two-week roadmap: re-evaluate, 15 questions, file it

**Created:** 2026-11-08
**Intent Contract:** See `.claude/session-intent.md`
**Window:** 2026-11-09 → 2026-11-22

## What you'll end up with

1. **A re-evaluation table.** Every open issue and PR is put in one of four buckets: lands with
   the chain, live, owner lane, or stale. Each row has one line of evidence.
2. **15 answered design questions.** They target the systems the next two weeks build: Phase 1
   close-out, Phase 2 Soul and the start of Phase 3 enemies. Each question has best guesses and
   one distinct random option. The answers are recorded in `docs/owner-decisions.md`.
3. **`docs/roadmap-2026-11-08.md`.** A dated two-week sequence built on the 2026-10-30 roadmap,
   with your answers applied. It ships as a docs PR.
4. **Filed GitHub issues.** One per bounded task, with scope, acceptance checks, lane label,
   `Blocked by` links and a milestone per slice with a due date.
5. **A stale-items list for you.** Issues to close or retitle; you click.

## How we'll get there

### Phase weights

- **Discover: 15%** — Bucket the 19 issues and ~26 PRs. Read roadmap §4–§6 against `main`
  plus the chain. Find the unruled system choices the next two weeks hit.
- **Define: 35%** — Draft 15 questions. Each one names its system, why it is open, and what it
  blocks, with 2–3 grounded guesses plus a random option. Ask them in four rounds (4/4/4/3),
  then record the answers.
- **Develop: 25%** — Write the roadmap doc. Draft the issue bodies. Create the milestones. File
  the issues and the docs PR.
- **Deliver: 25%** — Check every issue against the definition of ready: scope, acceptance,
  lane, dependencies, "do not decide". Check the dependency order. Confirm nothing ratified was
  reopened and no canon was invented.

The formula weights were 18/18/28/36. Define is raised because the 15 questions are the core
of this pass.

### 🐙 Debate checkpoints (High stakes)

- 🔸 **After Define:** "Do the 15 answers contradict each other or ratified design, and is any
  save-format or core-loop choice left implicit?" 1-round adversarial.
- 🔸 **After Develop:** "Is every issue agent-ready, and does the two-week order hold up against
  20 owner-hours/week and the landing chain?" 1-round collaborative.

### Execution commands

```bash
/octo:embrace "Re-evaluate Soul Meter's open issues/PRs and the 2026-10-30 roadmap, ask the owner 15 game-system design questions (best guesses + a distinct random option each), write docs/roadmap-2026-11-08.md, and file the next two weeks as GitHub issues with milestones, dependencies and existing lane labels"
```

Or by phase: `/octo:discover` → `/octo:define` → `/octo:debate` → `/octo:develop` →
`/octo:debate` → `/octo:deliver`.

## Provider availability (measured 2026-11-08)

🔴 Codex CLI: Available ✓
🟡 Gemini CLI: Available ✓
🧭 Antigravity CLI: Not installed ✗
🟤 OpenCode: Not installed ✗
🟢 Copilot CLI: Available ✓
🟠 Qwen CLI: Available ✓
⚫ Ollama: Available ✓
🔵 Claude: Available ✓
🟣 Perplexity: Not configured ✗

Notes:
- On 2026-10-31 Gemini failed at dispatch and Qwen failed. Codex and Copilot carry any gate.
- The plugin's banner script checks the literal string `need` instead of `$1`. That bug makes
  every CLI read "Not installed". These values come from the corrected check.

## Success criteria (from the intent contract)

1. Every open issue and PR is bucketed with evidence.
2. 15 questions are asked with best guesses plus a distinct random option, and answers are
   recorded with date and wording.
3. The two-week roadmap doc is written with PROVISIONAL numbers kept.
4. Issues are filed agent-ready, with milestones, dependencies and existing labels only.
5. Stale-item proposals are listed for the owner, and nothing is closed by an agent.

## Your involvement

Four question rounds, about 15 minutes in total. Then one look at the filed list in the
final report.

## Time estimate

About 2 hours of agent time:

| Phase | Agent time |
|---|---|
| Discover | 20 min |
| Define | 30 min, plus your answers |
| Develop | 45 min |
| Deliver | 20 min |
| Each debate gate, if run | +15 min |

## Next steps

1. Review this plan.
2. Adjust if needed (re-run `/octo:plan`).
3. Execute with `/octo:embrace` when ready.
