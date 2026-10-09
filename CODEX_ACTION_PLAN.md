# Codex action plan — soul-meter (art)

Written 2026-10-02 by Claude (Fable 5.1) as architect. Executor: Codex CLI on **Sol 6.1** (pick it in the model picker). Nobody monitors sessions live. Every milestone ends in a PR for review.

## Read first

1. `AGENTS.md` (repo rules; they win over this file if they conflict).
2. `docs/art-aesthetics-bible.md`, especially Part III.
3. `art-request.md`, `WORLD_ART_BRIEF.md`, `docs/art-generation/chapter-one-prompts.md`, `docs/art-integration-pass-2026-09-18.md`.
4. `tools/render_isometric_sprites.gd` (the render camera contract).
5. Issues #305 and #298.
6. `docs/agent-verification.md`.
7. `/home/adamjroder/projects/_planning/asset-pipeline/CODEX_ACTION_PLAN.md` (the shared pipeline).

## Goal

Produce the first project-authored 3D models for the "2D isometric rendered from 3D" presentation, starting with the 17 Kenney pieces in Dom, and build the icon pipeline from #298.

## Status on 2026-10-02 (verify before relying on it)

- Godot 4.7.1. The Steam Ch1 gold date in `docs/ship-plan-2026-10.md` was 2026-10-02; the launch milestone still has 14 open issues.
- Current branch `feat/ch1-facade-occlusion`, clean, 60 commits ahead of local `main` (local `main` may be stale).
- 598 3D files, all vendored Kenney under `assets/kenney3d/`. No project-authored GLB exists.
- `assets/generated/models/units/*/` (88 folders) holds only `*--imagegen-source.png` reference images.
- `tools/render_isometric_sprites.gd` renders GLB to PNG with a fixed 45° / atan(0.5) orthographic camera and writes a manifest with a drift check.
- A worktree already exists for #305: `../soul-meter-wt/art-dom` on `art/dom-production-batch-1`. Inspect it before starting; continue it if it holds work.
- Bible Part III says the author hand-makes models and commissions no automated pipeline. The ship plan assigns a Codex asset agent. The owner has resolved this (below).

## Decisions

| Decision | Answer | Source |
|---|---|---|
| May Codex generate 3D models | Yes, as drafts the owner approves. Codex drafts the bible amendment for sign-off | Owner |
| Deadline | None. Art must not block the remaining launch issues | Owner |
| First target | #305, the Dom batch | Owner |
| #298 icon pipeline | Build it, using Codex's own image tool instead of Gemini | Owner |
| Meshy spending | Each batch needs owner approval before generating | Owner |
| Git | Commit, push, open PR; never merge | Owner |
| Non-art work | Also cover the open issues in the Steam Ch1 launch milestone that are routed to Codex. Other `delegated-to-codex` issues stay out | Owner |
| Base branch | `feat/ch1-facade-occlusion` | Owner |

## Milestones

M3 onward is blocked until the shared pipeline reaches its P5 milestone.

**M1 — Bible amendment (docs only).** Draft the change to Part III: agent-generated models are allowed as drafts, nothing ships without owner approval. Open the PR and stop. Nothing below merges before this is signed off.

**M2 — Dom inventory and import convention.** List the 17 Kenney pieces from #305, the scenes that use each, and a budget for each. Write the import convention for authored models (folder, naming, scale, origin, how it meets the render camera contract). Propose the folder in the PR; do not move existing assets.

**M3 — Pilot of three pieces.** Batch file with estimate, PR, stop for approval. After approval: generate, clean in Blender, validate, render through `tools/render_isometric_sprites.gd`, and attach a contact sheet next to the Kenney originals.
Done when: the owner approves the look. If not approved, stop; do not continue to M4.

**M4 — Remaining 14 pieces.** Same flow, one approved batch. Replace the Kenney sprites in Dom. Preserve `.tscn` ownership, node paths and `uid://` references. Keep the manifest drift check passing.

**M5 — #298 icon pipeline.** Use Codex's image tool. Reuse `tools/extract_generated_alpha.gd`, `resize_generated_texture.gd` and `measure_image_bounds.gd`. Write provenance manifests in the same shape as `assets/generated/models/world/*.json`. The issue text still says Gemini; note the change in the PR and leave the issue for the owner to edit.

**M6 — Unit models. Not started without a new go-ahead.** Turning the 88 reference PNGs into models is a separate decision after M4.

**L — Launch-milestone issues (separate track, not blocked by the pipeline).** List the open issues in the "Steam PC launch (Ch1)" milestone with `gh`; there were 14 on 2026-10-02. Take the ones labelled `delegated-to-codex`, one PR per issue. Before starting an issue, check `../soul-meter-wt/` and the remote for an existing branch for it and continue that rather than starting again. This track can run in sessions separate from the art milestones and must never wait on them.

## Rules

1. Branch `codex/<topic>` from the base branch above; commit, push, open a PR. Never merge, never force-push, never change issue labels, milestones or assignees.
2. Keep the five-layer architecture. Never call `change_scene_to_file()`. Do not hand-edit `data/generated/*`. Do not modify `addons/*` except `addons/soul_meter_tools`.
3. Styling comes from theme type variations and DS tokens; no per-node theme overrides.
4. Do not invent canon. Do not decide art direction, scope or dates.
5. No Meshy generation without an owner-approved batch. Never commit the API key.
6. Do not touch worktrees under `../soul-meter-wt/` other than `art-dom` and one that already belongs to the launch issue you are working.

## Verification

- `bash scripts/test.sh -a <suite>` for affected suites.
- Full suite: `timeout 5400 bash scripts/test.sh -a test` (about 50 minutes).
- A rendered capture for anything visible; a headless pass does not prove it looks right.

## Stop and ask

- The owner has not signed off M1 or approved the M3 pilot.
- A model cannot match the render camera contract.
- An art change would touch combat or same-map code.
- A launch issue needs a design or canon decision its text does not settle.

## Handoff

In each PR body: what now works and how to see it, changed files, checks run with results, risks, open questions, next milestone.
