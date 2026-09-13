# Chapter One field-UX plan — Fallout 2 feel with integrated art

**Created:** 2026-09-13 (Fable, planning). **Status:** DRAFT for owner ratification.
**Goal (owner, verbatim):** finish the first chapter "with more integrated art assets
rather than the … houses and characters disappearing — we are looking for something
that plays and gives similar UX to Fallout 2 first chapter."

This plan supersedes nothing. It sequences existing ratified work (#305, #309,
`docs/fallout2-adoption-spec.md`, `docs/art-gameplay-opening-pass.md`) into a single
opening-route push and adds the two gaps the rendered evidence shows.

## Roles for this push

| Role | Agent | Model | Owns |
|---|---|---|---|
| Planner / architect / final review | Claude Fable | `claude-fable-5-1` | scope, acceptance, merge decision |
| Orchestrator | Codex Sol | `gpt-5.6-sol` | dispatches waves, runs suites, collects handoffs; makes no design decisions |
| Implementation (important) | Codex Astra | `gpt-6-astra` | Waves 1, 2, 4 |
| Research / boilerplate | Codex Luna | `gpt-5.6-luna` | Wave 0 triage capture, Wave 3 texture swaps, contact sheets, test scaffolds |

Handoff contract per `~/AI-ROLE-POLICY.md`: objective, branch, allowed files, deliverables,
acceptance command, do-not-decide list; compact return (changed files, tests + counts,
evidence paths, risks, open questions). Workers never push, never touch labels.

## Evidence baseline (rendered, Xvfb, 2026-09-13)

Command: `GODOT_BIN=~/.local/bin/godot LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR=$(mktemp -d) bash scripts/test.sh -a test/manual/screenshot_sweep.gd` → 32 shots, 0 failures.

| Shot | What it shows | Gap vs. Fallout 2 Ch1 |
|---|---|---|
| `20_town` | Dom exterior: 12 painterly facades on the terrain plate, painted props, named NPCs | Facades are single cutouts; nothing handles the actor walking *behind* one (Fallout 2 fades the roof). Two thin cyan diagonals cross the map (unidentified draw — travel-exit or nav debug). Townsfolk stand still. |
| `16_marshal_conversation` | Dialogue card + option list over dimmed town | Fine. Keep. |
| `22_dorthkor_road` | Memorial road, hostiles, tent, drums, travelers | Good. A yellow square marker sits on "ROADSIDE" (placeholder pickup/interactable?). |
| `30_tavern_interior` | Brick backdrop on flat grey void; Kenney light-wood tables/benches/stools; bar = brown rectangle | Interior reads as a test room. No wall thickness, no darkness outside the room, kit furniture off-palette. This is the largest visible art gap. |

Screenshots retained at the session scratchpad `qa-2026-09-13/`; regenerate with the command above.

Live Kenney-derived references remaining: `world/starting_town.tscn` 17 (all in hidden
kit assemblies behind the facades), `ui/screens/battle_stage.gd` 15, 13 interiors
(1–3 each: floor/wall fallback, stall/bench/stool, sign), `actors/{chest,switch,travel_exit}`.

## "Disappearing" — owner confirmed 2026-09-13

Owner: actors vanish (a) walking behind buildings and (b) on entering interiors.
Not reproduced in static captures. Most likely cause from the scene data: every
`Facade` is a `Sprite2D` with `offset=(0,-384)` and the building's y-sort origin at its
base, so an actor standing north of a building's origin but inside the facade's 768 px
tall alpha box is drawn *under* it — the player and party vanish behind roofs and
walls with no fade. NPCs additionally pop in one frame late (`TownNpcSpawner` populates
via `call_deferred`). Wave 0 confirms or corrects this before Wave 1 builds on it.

## Waves

### Wave 0 — Symptom capture (Luna, ~1 h)
Scripted walk in `test/manual/`: new game → Trial exit → walk the player behind
`FourArmsTavern`, `TownHall`, `TrialHall`; capture every 10 frames; enter the tavern
and exit; reload a save in the town. Deliver a contact sheet + the frame index where any
actor is fully occluded, and the node responsible for the cyan diagonals (`grep` the
`_draw` owners under `world/`, `actors/travel_exit`, `ui/hud`).
Accept: evidence file `docs/qa/ch1-field-ux-wave0.md` with frames; no scene edits.
Do not decide: fixes.

### Wave 1 — Facade occlusion fade + actor guarantees (Astra, ~1 day)
- `world/facade_occluder.gd` (new, attached to each building root by `starting_town.gd`
  at `_ready`, no `.tscn` node changes): when the player, a follower, or a named NPC is
  y-sorted behind the facade and its feet lie inside the facade's opaque footprint,
  tween the facade `modulate.a` to a DS token (proposed `DS.FACADE_OCCLUDED_ALPHA`,
  0.35) and back. Fallout 2 roof-cut behaviour, not a hard toggle.
- Spawn townsfolk before first frame (populate in `_ready` after siblings via
  `await get_tree().process_frame` only where the test harness needs determinism).
- Remove the cyan diagonals if Wave 0 shows they are debug draws; if they are
  travel-exit boundaries, move them behind `OS.is_debug_build()` + `SOUL_METER_LAYOUT`.
Accept: new `test/unit/test_facade_occluder.gd` (fade on/off, no fade for props,
save/load neutral); `test_starting_town.gd`, `test_dom_npc_roster.gd`, nav_acceptance
suite green; sweep `20_town` re-captured with the player behind the tavern and visibly
readable through the fade.
Do not decide: alpha value beyond the token, new art, facade repaints.

### Wave 2 — Interior presentation (Astra, ~1.5 days)
- `building_interior.tscn`: replace the flat grey void with a vignette/black surround
  (`CanvasLayer` or a `ColorRect` in DS `INK_0`), wall polygons get thickness + the
  `dom-interior-wall--brick` texture on all four sides, `Counter` becomes a
  `SolidProps` sprite once #309 delivers `dom-interior-counter`.
- Camera: interior camera limits clamp to the room rect (no void visible at 1920×1080).
Accept: `test_building_interiors.gd` contract extended (surround present, camera
limits inside room rect, 4 textured walls); sweep `30–33` re-captured.
Do not decide: furniture layout (Wave AD placements stay), new rooms.

### Wave 3 — Kenney retool batches (Luna generates, Astra swaps) — existing issues
- #305 S10 (17 outdoor kit pieces, hidden assemblies → delete the dead `Sprite2D`
  children once facades are the only renderer; keep node names for door/collision wiring).
- #309 S10b (interior stall/bench/stool/sign/ground/wall; chest/switch/travel-exit sign).
- `ui/screens/battle_stage.gd` 15 refs — audit whether any is live after Wave X
  backdrops; swap or delete.
Accept as written in #305/#309: zero `castle-kit|fantasy-town-kit|nature-kit|kenney3d`
refs under `world/`, `actors/`, `ui/screens/battle_stage.gd`; suites green; owner
approves each contact sheet before merge.

### Wave 4 — Opening-route feel run (Sol runs, Fable reviews, owner plays)
Execute `docs/art-gameplay-opening-pass.md` §"The bounded deliverable" end to end on a
build with Waves 1–3 merged: Trial → Council → Field Debt → Dorthkor → Broken Muster →
ruling → reload. Evidence per row of that table. Owner plays the same route once and
answers exactly: "Did anything vanish, and where?" and "Does Dom read as a place?"

## Progress log
- 2026-09-13 Wave 0 done — root causes confirmed on rendered frames (`docs/qa/ch1-field-ux-wave0.md`).
- 2026-09-13 Wave 1 done — commit `17edf750` on `feat/ch1-facade-occlusion`: facade fade, interior entry in front of door, Waterline removed; 62 rendered cases green (`docs/qa/ch1-field-ux-wave1.md`).
- 2026-09-13 Wave 2 done — commit `8f55b4ef`: dark surround, thick brick walls, room-bounded camera; 56 rendered cases green (`docs/qa/ch1-field-ux-wave2.md`).
- 2026-09-13 Wave 3a (#309) done — Luna art batch + Fable scale/counter/door fixes; 52 rendered cases green (`docs/qa/ch1-field-ux-wave3a.md`).
- 2026-09-13 Wave 3b (#305 partial) done — hidden kit assemblies + dead battle scenery deleted; 91 live outdoor kit sprites deferred to an art batch (`docs/qa/ch1-field-ux-wave3b.md`).
- 2026-09-13 Owner review of 3a: rooms must be ~2× larger for the furniture to be at scale → Wave 3c (room scale) dispatched to Astra.

## Out of scope for this push
World-map travel rewrite, AP-combat changes, new locations (#238/#239), Weftlumin waves,
new dialogue or quests, canon edits. These stay on their existing issues.

## Estimate
Waves 0–3 ≈ 4–5 working days of worker time, review-bounded; Wave 4 ≈ 1 owner session
(~1.5 h) plus half a day of fixes. Content lock per `docs/ship-plan-2026-10.md` is
Sep 21 — Waves 1–3 are asset-swap/bug class and remain mergeable after lock.

## Open questions for the owner
1. Facade fade vs. Fallout-style roof removal (hide the top half of the facade): fade
   is proposed because facades are single sprites with no roof layer.
