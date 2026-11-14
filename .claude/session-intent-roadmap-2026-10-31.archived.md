# Session Intent Contract

**Created:** 2026-08-29
**Command:** /octo:plan "combat screen is still just blank"
**Prior contract:** archived as `session-intent-fallout2.archived.md` (Waves 1–5, O, P all SHIPPED + gated).

---

## Job statement

Make the battle screen's tactical stage actually render in real play. Root cause is
DIAGNOSED (not speculative): all 12 authored encounters lack a `grid` block, so
`Battle._battlefield_for_definition()` falls back to the zone model; the six-region
stage draws only grid battles (zone models snapshot no tiles) and the legacy zone
presentation is no longer shown — the screen's center is blank and the entire Wave P
tactical layer (click-to-move / LOS / cover / flanking) is unreachable outside tests.

## Owner answers (captured 2026-08-29)

- **Goal:** Build something — make real battles run on the tactical grid.
- **Grid source (design ruling):** DEFAULT GRID FOR ALL — `Battle` synthesizes a
  sensible default grid whenever an encounter authors none; authored
  `grid.dimensions` still override. (Per-encounter authored sizes remain open as a
  later content pass.)
- **Knowledge/Clarity:** Expert / Clear requirements (diagnosis complete; the
  authored-grid synthesis path in `_battlefield_for_definition` already exists to
  extend).
- **Success:** Working solution (launch → battle → units on tiles → click to move)
  AND production-ready (suite green, codex gate, pushed).
- **Constraints:** Must fit architecture — FR-105 seam, frozen six-region contract
  (additive only), zone model remains the working fallback, encounter data changes
  go through the seed pipeline, no hand-edits to `data/generated/*`.

## Boundaries

- No hex (deferred to FR-105 seam, ratified in Wave P).
- Zone model must keep working (tests + fallback path) even though no shipped
  encounter will use it by default.
- Default grid dimensions are PROVISIONAL balance values — flag them.
- No restructuring of battle.gd's region composition beyond what rendering requires.

## Success criteria

1. Entering any authored encounter (e.g. trial-warden) shows terrain tiles and unit
   sprites on the stage; hover/click move works as shipped in Wave P.
2. An integration test reproduces the regression: an encounter WITHOUT an authored
   grid must produce a battlefield whose snapshot carries non-empty tiles.
3. Full suite green; screenshot evidence; codex delivery gate PROCEED.
