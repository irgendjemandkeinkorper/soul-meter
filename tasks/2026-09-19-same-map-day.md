# 2026-09-19 — same-map combat day plan

Goal: move #281 (same-map combat) from "sessions exist in tests" to "an ambient fight starts on a
real field scene when the party walks into a hostile", and make measurable progress on #285.

## Finding (start of day)

- `Battle.start_session()` / `admit()` / chain alerts / `CombatOverlay` all exist and are tested.
- **No production code opens a session.** `FieldMap._on_hostile_alerted` only re-emits; `Battle`
  connects to it only after a session is live. The only callers of `start_session` are the labs
  and tests.
- **No world scene places a `Hostile`.** All four fields still author `actors/enemy` nodes
  (press-E encounter triggers).
- `Hostile.mark_downed()` has zero callers: session end never marks or despawns downed mobs.

## Slices

| # | Slice | Owner | Worktree | Proof |
|---|---|---|---|---|
| A | First alert opens a session: `FieldMap` calls `Battle.start_session`, then `GameFlow.send_event("enter_battle")`; while live, alerts go through `admit` | Claude | `../soul-meter-samemap` | new integration test: walk a player body into a hostile's sensor on `test_room` → `Battle.session_active`, chart in Battle |
| B | Session end marks downed hostiles `DOWNED`, hides them; survivors return to IDLE (flee) | Claude | same | test: victory → hostile state DOWNED and not visible; flee → IDLE |
| C | Migrate `test_room` bog-wight + loam-boar and `dorthkor_road` breach hound to `Hostile` (unit_id = archetype, group_id = encounter). `dorthkor-muster` (flag-locked) and `jawbrace-empty-post` stay `Enemy` set-pieces | Claude | same | scene loads; defeated flag still written; rendered capture under Xvfb |
| D | Rendered acceptance: Bog Wight ambient fight screenshot, log hidden | Claude | same | `test/manual` capture + inspected PNG |
| E | ~~#285 XP writers~~ **Already shipped in PR #419 (2026-09-08)**: `Advancement.award_xp`, `Battle._award_victory_xp`, quest XP in `resolve_side_quest`, 14+21+22 tests green. #285 is stale except perks. Worktree removed. | — | — | verified by worker, no changes |

Not today: perks (Pandora data design), field verbs (blocked on #349 ← #281), #412 (awaits ruling).

## Checklist

- [ ] A landed green (`test_field_map`, `test_hostile`, `test_combat_session`, new test)
- [ ] B landed green
- [ ] C scenes migrated, `test_deployment_flow` / e2e journeys still green
- [ ] D screenshot inspected
- [x] E: nothing to do, #285 XP already merged (perks remain)
- [ ] Focused suites + `scripts/acceptance_gate.sh` (if runtime allows)
- [ ] PR(s) opened, #281 comment with evidence and what still blocks closure

## End-of-day status (2026-09-19)

- A, B, C landed on `feat/same-map-ambient` (worktree `../soul-meter-samemap`).
- D captured (`docs/qa/same-map-2026-09-19/`); readability acceptance NOT met — stacked seating,
  no visible action beat. That is the next slice.
- Chased a segfault for an hour: it was the new tests touching a fixture hostile that had retired itself (flag left set by the previous test), not production code.
