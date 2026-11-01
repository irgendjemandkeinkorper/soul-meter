# Session Plan — Roadmap revisit 2: the vision, aligned

**Created:** 2026-10-31
**Intent Contract:** See `.claude/session-intent.md`
**Subject:** `docs/roadmap-2026-10-30.md` on PR #528 (`58f15e22`), `docs/owner-decisions.md`,
`docs/roadmap-issues-2026-10-30.md`, and a proposed addendum to `docs/game-identity.md`

## What you'll end up with

A second roadmap revision that:

1. Names the **vertical-slice beat**: a same-map fight where alerted mobs stream into the CT
   order and (if it can be grounded in companion data without new canon) a companion turns on
   you mid-fight. It says which phase proves it and how the field-first order survives, or why it
   changes.
2. Records your three new rulings with your words: **Hollow is permanent and playable, with
   negatives that push the player to un-hollow**; **three unavoidable combat set-pieces, one per
   main-quest ruling, everything else bypassable**; **polish bar is prose-first, readable, not
   cinematic**. They go to `docs/owner-decisions.md` §5 as answered, and the ones that bind design
   are proposed as game-identity additions for you to ratify, not written in by an agent.
3. Re-sizes every phase at **20 owner-hours/week**: prose load turns into a calendar, Phase 6
   drops presentation work that the prose-first bar does not need.
4. Adds a Hollow-state design note under ruling 3 (negatives, the un-hollowing route through
   Agreement, what the 0.5× ceiling means), PROVISIONAL and sourced from `cosmology/souls.md`.
5. Updates the issue packet (deltas only) and keeps everything unfiled until you say so.

## The designer's starting position (to be tested in Define, not assumed)

- **The slice beat cuts across phases.** "C" needs Phase 3 (enemies that play the game) and
  ruling 6's alerted joins, which already work; "D" needs Phase 4 (company) and a betrayal
  trigger that does not exist. The cheapest honest slice is C with a companion *reacting* (a bark
  and a refusal), and D as a Phase 4 payoff. If you want D in the first proven beat, Phase 4's
  bark and outcome work moves up beside Phase 3. Field-first still holds for the *player's first
  hour*; the slice is the *first thing proven to be worth playing*.
- **Hollow as a playable state is already half-built**: Soul at zero sets a permanent *husked*
  recovery ceiling (0.5× the pre-zero value) in `globals/game_state.gd`. Your "UnHollowed" either
  means climbing back under that ceiling, or you rule that the ceiling can lift through Agreement;
  Define poses that as one line. The negatives must come from systems that exist (read-backs, companion barks, vendor
  ratios, recruit gating by Renown) so no new canon is needed; the un-hollowing route is already
  "acts of Agreement" by ruling 3.
- **20 h/week changes the shape of the plan.** The previous plan treated prose as the
  bottleneck; at 20 h/week the bottleneck is agent throughput and your rulings. The roadmap can
  now carry dates again, which the 2026-10-30 draft refused to do.

## How we'll get there

### Phase weights

- **Discover: 10%** — three bounded reads: `cosmology/souls.md` and `canon/` on hollowing;
  companion data and barks for a grounded "turn" (loyalty, refusal, desertion lines); the
  set-piece inventory against "three unavoidable". No new order proposed here.
- **Define: 35%** — the slice beat and its phase; the Hollow-state note; the three rulings
  drafted in the owner's words; the 20 h/week calendar; Phase 6 re-scope. Owner checkpoint.
- **Develop: 30%** — edit the roadmap, owner-decisions §5, the packet deltas, and a proposed
  game-identity addendum file for ratification. Codex may draft issue bodies; Claude owns wording.
- **Deliver: 25%** — multi-LLM review against the ten rulings, the three new statements, PRD §3,
  and the "nothing invented" rule. High stakes: debate gates on.

### 🐙 Debate checkpoints

- 🔸 **After Define:** "Is 'the fight where the company turns' the right first-proven beat, and
  does proving it in Phase 3 (with Phase 4 moved up only for the bark/outcome work) keep the
  field-first first hour honest?" 1-round adversarial.
- 🔸 **After Develop:** "Is this revision ratifiable: three new rulings recorded verbatim, Hollow
  note sourced, calendar at 20 h/week, nothing ratified reopened?" 1-round collaborative.

### Execution commands

```bash
/octo:embrace "Revise the 2026-10-30 roadmap (PR #528 @ 58f15e22) a second time as a senior game designer: name the vertical-slice beat (same-map fight with alerted joins, companion turn if grounded), record the owner's 2026-10-31 rulings (playable Hollow state with strong negatives, three unavoidable set-pieces, prose-first polish bar), re-size at 20 owner-hours/week, Hollow-state note under ruling 3, packet deltas"
```

Or by phase: `/octo:discover` (10%) → `/octo:define` (35%) → `/octo:debate` → `/octo:develop` (30%)
→ `/octo:debate` → `/octo:deliver` (25%).

## Provider availability (measured 2026-10-31)

🔴 Codex CLI: Available ✓
🟡 Gemini CLI: Available ✓
🧭 Antigravity CLI: Not installed ✗
🟤 OpenCode: Not installed ✗
🟢 Copilot CLI: Available ✓
🟠 Qwen CLI: Available ✓
⚫ Ollama: Available ✓
🔵 Claude: Available ✓
🟣 Perplexity: Not configured ✗

Known from this morning's run: Gemini's CLI is on a sunset free tier and fails at dispatch; Qwen
fails; the plugin's claude-sonnet agent fails on `thinking.type.enabled`. Codex and Copilot carry
the run; set `OCTOPUS_AGENT_TIMEOUT=900` and `CLAUDE_MODEL=claude-sonnet-4.6` for the gates.

## Success criteria (from the intent contract)

1. Three new owner statements recorded as rulings in the owner's words; design-binding ones
   proposed for game-identity, not written by an agent.
2. One named vertical-slice beat with its proving phase; field-first kept or re-sequenced with reasons.
3. Phases sized at 20 h/week with a calendar; Phase 6 re-scoped prose-first.
4. Hollow-state note under ruling 3, PROVISIONAL, sourced, no invented canon.
5. Packet deltas only; nothing filed.
6. Both gates run; Deliver verdict "ratifiable".

## Your involvement

Two reads of ~15 minutes: after Define (the slice beat, the Hollow note, the three rulings as
drafted) and after Develop (the packet). At 20 h/week you could also take the Hollow negatives
list yourself; say so and Define will leave it as a blank for you.

## Time estimate

Four working sessions: Discover ½, Define 1, Develop 1½, Deliver 1. Owner time ~30 minutes.

## Next steps

1. Review this plan.
2. Adjust if needed (re-run `/octo:plan`).
3. Execute with `/octo:embrace` when ready.
