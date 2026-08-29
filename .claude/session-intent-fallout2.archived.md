# Session Intent Contract

**Created:** 2026-08-28
**Command:** /octo:plan "we need to make this game play flow and function MUCH more like fallout 2"

## Job Statement

Rework Soul Meter's gameplay flow and function to feel and play much more like
Fallout 2 — as a production-ready implementation effort, not a study. The owner
states the desired changes are **fully specified in their head**; the plan's
first working step is to elicit that spec verbatim and ratify it against the
existing canon/PRD before any implementation.

## Captured Answers

- **Goal:** Build something (rework gameplay systems/flow toward the Fallout 2 feel)
- **Knowledge/Clarity:** Fully specified — owner has the detailed changes in mind; just implement
- **Success:** Production-ready — changes land tested, on main, acceptance-checked
- **Constraints:** Must fit architecture (keep ratified PRD/Gate-T systems; evolve, don't rewrite) · High stakes (this redirects the design; wrong calls are expensive)

## Success Criteria

1. The owner's Fallout 2 spec is captured as a written, ratified amendment
   (design-doc / PRD addendum) before implementation begins — no silent canon
   resolution, per CLAUDE.md.
2. The game demonstrably plays differently in hand: the changed loops are
   playable end-to-end from a new game.
3. Every change lands on `main` with tests, suite green, and quest-audit clean.
4. Ratified Gate-T combat semantics (CT scheduler, Resolution purity,
   forecast==resolution, frozen six-region contract) are evolved, not rewritten,
   unless the owner explicitly ratifies a break.

## Ratified Rulings (owner, 2026-08-28 — "yes to both")

1. **Combat:** the Fallout 2 combat feel MAY touch the Gate-T-ratified CT
   scheduler — AP-based combat is authorized. (ApRoundScheduler already exists
   behind the scheduler seam; this is a promotion/swap, not a rewrite.)
2. **Travel:** Fallout 2-style world-map travel SUPERSEDES FR-503's ratified
   "discovered hubs only, at a cost" design.

These override the corresponding lines under Boundaries/Success Criteria where
they conflict; everything else there stands.

## Boundaries

- Do NOT resolve open canon questions or override [CANON] silently.
- Do NOT rewrite the five-layer architecture (Flow → Presentation → Systems →
  Narrative → Data); Fallout 2 mechanics map INTO it.
- Region-content merges stay barred until the #93 playtest gate passes —
  Fallout 2 flow work must target systems and existing scenes, not new regions,
  until that clears.
- The #93 human playtest and FR-904 hardware benchmark remain human-gated and
  are unaffected by this plan.

## Context

Solo dev + agent fleet (Claude architect/synthesizer, Codex implementation,
Gemini/Jules bounded research). Chapter 1 vertical is code-complete to its
human-gated floor; suite 877/0 as of today.
