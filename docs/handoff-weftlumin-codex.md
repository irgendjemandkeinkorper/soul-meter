# Weftlumin — Codex handoff (2026-09-04)

**Read first:** `docs/architecture-in-game-editor.md` (the spec; §0, §3, §4.2, §4.4, §4.6.2 before any
code) and GitHub index issue **#311**. This file tells Codex what to do next, in what order, and what
not to touch. Claude is paused; the owner reviews PRs. Issues were filed under the working name
"Forge" and renamed to **Weftlumin** — the spec's paths are authoritative (`addons/weftlumin/`,
`weftlumin/` adapter dir, `user://weftlumin/`, `SOUL_METER_WEFTLUMIN=1`, `weftlumin_toggle`).

## 1. Ground rules (non-negotiable)

1. **One issue = one branch = one PR.** Branch name is in the issue (`Branch:`). PR title = issue
   title. PR body: what changed, test evidence (paste the suite summary line), risks, open questions,
   and `Closes #N`. Never set labels, assignees or milestones.
2. **Frozen files until #281 (F1) and #283 (F3) merge:** `ui/flow/game_flow.gd`, `ui/flow/game_flow.tscn`,
   `globals/battle.gd`, `globals/combat/**`, `globals/chargen_data.gd`, `globals/save_migrations.gd`
   (no schema bump), `globals/skill_check.gd` numerics. If an issue seems to need one of these, stop and
   comment on the issue instead.
3. **Stay inside `Allowed scope:`.** Anything outside it is a question in the issue, not a change.
4. **Never decide design.** `Do not decide:` lines are binding. Spec ambiguities → comment on #311 and
   pick the most conservative reading only if the issue cannot proceed otherwise; say so in the PR.
5. **Never write canon:** no edits to `data.pandora`, `dramgid-vault`, `.dialogue` prose, or
   `data/generated/*` by hand (regenerate via the tools). Never invent a `vault_id`.
6. **Never edit `addons/`** except `addons/weftlumin/` (project-owned) and never touch `.godot/`.
7. **Tests before handoff:** `GODOT_BIN=~/.local/bin/godot bash addons/gdUnit4/runtest.sh -a test` must be
   green; `godot --headless --path . --import` after adding any `class_name`; quest audit 0 errors.
   gdUnit4 pitfalls: no `:=` from a Variant-returning call (parse error, exit 105); judge tool-script
   *output*, not its exit code (134 at teardown is normal); re-import after new `class_name`.
8. **Scratch stays scratch.** Tools write under `user://weftlumin/`; only a bake writes repo files.
9. **`.tscn` output is text-patched, never `PackedScene.pack()`** (spec §0.2 finding 2, P5).

## 2. Definition of done (every PR)

Acceptance checks in the issue all pass and are quoted in the PR; new behaviour has a test; the
inert/round-trip/idempotence tests named in the spec §4.14 for that component exist; docs touched only
where the issue says; no unrelated reformatting.

## 3. Work order (take the next unclaimed one; comment "taking" on the issue first)

| Order | Issue | Row | Notes |
|---|---|---|---|
| 1 | #312 | E0.3 interfaces | Transcribe §5's `WeftluminGameAdapter` + §4.2 `WeftluminKind` + §4.5.5 `WeftluminPanel` **verbatim**; stubs only. Everything else codes against these. |
| 2 | #313 | E1.1 layout bake fix | Copy the `_initialize()` pattern from `tools/bake_campaign.gd:21`; report-only default. |
| 3 | #314 | E1.2a tscn parser | Byte-identical round-trip over every repo `.tscn` (excluding third-party `addons/`) is the gate. |
| 4 | #315 | E1.2b tscn ops | Type-aware encoder; refuse unsupported types with an attributed error. |
| 5 | #316 | E1.2c Dom survival tests | `TavernDoor/Facade.visible == false` after a bake; bake twice = identical. |
| 6 | #329 | E1.8 rename → harmonic_accord | Alias only the context dict key; parameter names unchanged; no numeric change. |
| 7 | #331 | E1.10 world_seed + phase_count | Additive save keys, loader defaults, no schema bump. |
| 8 | #317 | E1.3a canon reader + spec amendments | Factions first; zero `data.pandora` diff after re-seed. |
| 9 | #318 | E1.3b CANON-SEED drift stage | After #317 merges. |
| 10 | #319–#324 | E1.4a–f canon migrations | One PR each, stat-free categories only; **not** #325 (blocked by #283). |
| 11 | #330 | E1.9 test-migration plan + inert skeleton | Plan doc + skipped suite. |
| 12 | #326 | E1.5 kind registry refactor | After #312; per-kind `apply`; lossless quest JSON. |

Do **not** take: #327/#328 (DeepSeek math), #325 (blocked by #283), anything E2–E7 (#332–#353) until
#281 and #283 are merged and the owner says go. If everything above is merged and E2 is still blocked,
stop and comment on #311.

## 4. Handoff format (PR body and a one-line comment on the issue)

```
Changed files: …
Tests: <suite summary line>; new tests: …
Acceptance: <each check from the issue, pass/fail>
Risks: …
Open questions: …
```

## 5. Running Codex on this

```
cd ~/projects/soul-meter && git fetch && git switch -c feat/<slug> origin/main
codex exec -s workspace-write -C . "Read docs/handoff-weftlumin-codex.md, then implement GitHub issue #<N> exactly as its body and the spec sections it cites say. Stop and report if you would need to touch a frozen file."
```
