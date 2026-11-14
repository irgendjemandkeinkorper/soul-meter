# Engineering handoff to Codex (2026-11-04)

The owner is moving to graphics work for a while. Codex takes the engineering queue below, and Claude reviews every result before anything is marked ready. This file covers:

1. The rules for this handoff
2. How to verify
3. What is already done
4. The task queue
5. What is waiting on the owner

`AGENTS.md` still applies in full; this file adds to it.

## 1. Ground rules

### The owner's graphics lane: do not touch

The owner is working on these files. If a task seems to need one of them, stop and write it under "Open questions" in your PR body.

- `assets/` (sprites, `assets/generated/sprites/building-kit/`, `generated-art`, icons, UI art)
- `*.gdshader`
- `design/`
- `ui/theme/`
- `tools/render_building_kit.gd`, `tools/render_isometric_sprites.gd`, `tools/gen_art.py`
- The art PRs #538, #539 and #565

### Do not decide

- Owner items in `docs/owner-decisions.md` stay open until the owner answers. If you find something new for the owner, add a row there. Never resolve a row yourself.
- Any number marked PROVISIONAL stays as it is.
- Do not invent canon. New player-facing prose gets the header `PROVISIONAL — CANON REVIEW REQUIRED`.
- No new mechanics, and no changes to rulings recorded in `docs/owner-decisions.md` §5.

### Git

- Start one branch per task from `origin/main`, named `codex/<topic>`, and open a **draft** PR.
- Do not merge, force-push another agent's branch, retarget, close PRs, or change labels and assignees.

### Memory on this machine

- This WSL machine can run out of memory on large test runs, so run suites in batches (recipe in §2).
- If a run is killed for low memory, stop and report it. Do not restart it without the owner's go.

## 2. Verification

| Step | Command |
|---|---|
| After adding any `class_name` script | `godot --headless --path . --import` (without it, `--script` runs cannot resolve the new class) |
| One suite | `bash scripts/test.sh -a test/unit/test_<name>.gd` (prefix `SOUL_METER_HEADLESS=1` only for headless-safe suites) |
| A batch | `bash scripts/test.sh -c -a <suite> -a <suite> ...`, 5–10 suites per batch (see the memory cap below) |
| Generated data | `GODOT_BIN=godot bash scripts/check_generated_data.sh` must report no drift. Never hand-edit `data/generated/*`; regenerate with the tools named in `DEPENDENCIES.md`. |
| Blocking paint | `godot --headless --path . --script res://tools/paint_blocking.gd -- --check` must report 0 stale |
| Rendered behaviour | Under Xvfb, per `docs/agent-verification.md`. Headless output does not prove visuals. |

### Memory cap for batches

Run batches under a memory cap: the wrapper below watches resident memory and kills any test Godot process above `CAP_MB`.

```bash
# usage: CAP_MB=3500 LOG=/tmp/batch1.log bash capped.sh res://test/unit/test_a.gd res://test/unit/test_b.gd
args=(); for p in "$@"; do args+=(-a "$p"); done
LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d)" timeout 900 \
  bash scripts/test.sh -c "${args[@]}" > "$LOG" 2>&1 &
runner=$!; peak=0
while kill -0 $runner 2>/dev/null; do
  for pid in $(pgrep -f "GdUnitCmdTool|gdUnit4/bin"); do
    rss=$(awk '/VmRSS/{print int($2/1024)}' /proc/$pid/status 2>/dev/null || echo 0)
    [ "${rss:-0}" -gt "$peak" ] && peak=$rss
    [ "${rss:-0}" -gt "$CAP_MB" ] && { echo "WATCHDOG killed $pid at ${rss} MB" >> "$LOG"; kill -9 $pid; }
  done; sleep 1
done
wait $runner; echo "exit=$? peak_rss_mb=$peak"
```

CI's `test` job has a 60-minute limit; it was raised from 15 minutes on 2026-11-04.

## 3. Where things stand (do not redo)

### `main` at `136955dd`

All 19 stacked PRs (#552, #556, #564, #567–#582) were merged through #552 on 2026-11-04, with CI green. That stack brought in:

1. Combat: the one command bar, the 8-slot hotbar, motion polish, and the 5v5 class demo (AI against AI, fresh dice).
2. The icon command bar, with hover cards.
3. The hex grid wave (H0–H4), with the setting on.
4. Maps: grid walls and full art bases on all 7 maps, plus the ground blend.
5. Buildings and seating:
   - Walk-in buildings (`world/buildings/walk_in_building.gd`): the Kesselford Wayhouse, plus four text-grid layouts (tavern, shop, cottage, warehouse).
   - Set-piece seating now fails fast (#582).

### Draft PR #583: Lower Trial Hall rooms

Branch `claude/trial-hall-rooms`, CI green. **Leave it alone**: it waits on the owner's playtest (owner item 36).

The new-game hall is ten rooms on one 28 × 28 plan (`world/buildings/layouts/trial_hall.tres`), placed by a `WalkInBuilding` with the new `roofed = false`. It contains:

- **Side rooms:** three ambient warden pairs. Each pair sleeps until its tutorial beat, and a cleared room stays cleared through a hall flag.
- **Store door:** SLIP 40 opens it quietly; forcing it wakes the pair.
- **Blast door:** the new item `tools/blasting_charge` opens it on a 3 s fuse.

It also adds a reusable pattern: `DialoguePoint` (`actors/interactable/dialogue_point.gd`). A door or mechanism opens a dialogue title, so its skill checks and item use live in a `.dialogue` file.

Review page: https://claude.ai/artifact/NRP9MhH7LVUWAyT61QM2xC

### Lesson from #583

On the iso maps a `Hostile`'s alert sensor is a circle in screen pixels, so it hears through walls. #583 handles this by placement: every mob sits more than its 128 px radius from any other room's floor, and a test enforces it. Do not change sensors (see §5).

## 4. Task queue

Work in order. Each task gets its own branch and draft PR.

### T1. A set-piece seat must not land across a wall (bug fix)

**Problem.** `Battle._seat_set_piece` (`globals/battle.gd`) seats the enemy a fixed number of screen steps right of the player's anchor cell (`SET_PIECE_ENEMY_SCREEN_STEPS`). It then calls `GridBattlefieldModel.seat_near(wanted, taken)` (`globals/combat/grid_battlefield_model.gd`). This goes wrong in two ways inside tight interiors such as walk-in buildings and the Trial Hall:

1. **`wanted` is free but on the far side of a wall.** `seat_near` returns `wanted` itself, so the foe is seated in the next room.
2. **`wanted` is a wall cell.** `_nearest_free_cell` starts its search inside the wall, and its first ring holds cells on both sides, so it can pick the next room.

Today only careful trigger placement avoids this (#583); the code does not.

**Objective.** Every enemy seat is reachable from the party's anchor cell, through passable cells and without crossing a walled edge, within `PLACEMENT_SEARCH_RADIUS` of `wanted`. When no such cell exists, seating fails fast through `_set_piece_seat_failure`, as #582 does now.

**Scope.**
- `globals/combat/grid_battlefield_model.gd` (`seat_near`, `_nearest_free_cell`, or an optional reach-from argument)
- `globals/battle.gd` (`_seat_set_piece`, `_open_line`)
- Tests in `test/unit/test_party_placement.gd` and `test/unit/test_grid_battlefield_hex.gd`, or a new unit suite

**Acceptance.**
1. New unit tests, square and hex grids:
   - `wanted` across a wall line from the anchor → the seat is on the anchor's side.
   - `wanted` inside a wall → the seat is on the anchor's side.
   - No reachable free cell in radius → `{"ok": false}`.
2. These suites stay green:
   - unit: `test_party_placement`, `test_grid_battlefield_hex`, `test_battle`, `test_campaign_encounters`, `test_combat_lab`
   - integration: `test_class_demo`, `test_combat_session`, `test_hex_combat`, `test_game_flow_battle_transitions`
   - integration: `test_walk_in_buildings`, `test_building_interiors`, `test_hex_grid_maps`
   - anything else `git grep -l -E 'set_piece|seat_near' test` lists
3. The 5v5 demo still seats both lines on every map it runs on.

**Do not decide.**
- Ambient entry (ruling 4: the anchor never moves; party members take the nearest reachable cell) stays as it is.
- Keep the seat offset, row steps, radius and the `formation.lines` behaviour.

### T2. Open-PR landing report (read-only)

**Problem.** About 25 PRs besides #583 are open. Many are stacks whose bases have since merged or gone stale:

- #527–#529
- #538/#539 (art)
- #541–#551 (roadmap P1 and chargen randomize)
- #557–#563 (UI rework U1–U3 and the chargen overhaul)
- #565 and #566

Before merging any of them, the owner needs to see where each stands.

**Deliverable.** A new file, `docs/status/2026-11-04-open-pr-report.md`, with one row per open PR:

- **Base chain:** its base, and that base's base, down to `main`.
- **Already in `main`:** whether its commits are already there (`git cherry origin/main <head>`).
- **Merges cleanly:** whether it merges into current `main` without conflicts (`git merge-tree --write-tree origin/main <head>`); if not, list the conflicting files.
- **CI:** the state of the last run.
- **Waiting on:** the owner item it waits on, from `docs/owner-decisions.md`.

End the file with a suggested landing order and an appendix of the exact commands used.

**Acceptance.** Every open PR is listed, and every claim can be reproduced from the appendix.

**Do not decide.** Make no merges, rebases, retargets, closes or PR comments. The landing order is a suggestion for the owner.

### T3. Memory-capped batch runner in the repo (tooling)

**Problem.** The cap in §2 lives only in agents' scratch files.

**Deliverable.** `scripts/test_capped.sh`, built from the §2 recipe:

- `CAP_MB` and `LOG` come from the environment, with defaults.
- Suites are the arguments.
- It exits non-zero when the watchdog killed anything.

Also add a short section to `docs/agent-verification.md` that points to it.

**Acceptance.**
1. A batch of 3 unit suites passes through it.
2. A run with a deliberately tiny `CAP_MB` reports the kill and exits non-zero.
3. `scripts/test.sh` is unchanged.

## 5. Waiting on the owner (do not start)

| Item | What waits |
|---|---|
| 36 | Trial Hall numbers, the length of the opening, placeholder looks (#583) |
| 35 | Which buildings convert to walk-in next; the Blender kit swap (graphics lane) |
| 34 | The hex numbers still marked PROVISIONAL |
| 30 | Combat motion and looks (graphics lane) |
| 5, 7, 8, 11, 12 | Economy numbers, DRAMGID leftovers, companion canon, game-identity questions, Steam |

### Open questions for Claude (record, do not build)

- **Alert sensors hear through walls** on iso maps (§3). A wall-aware sensor would change fights on every map, so it needs a ruling first. Until then, mob placement handles it.
- **Trial-warden encounter flag.** The `trial-warden` encounter has no `defeated_flag`, because it is also the court's set piece. The Trial Hall side rooms keep their clears in hall flags. Any change to that encounter must keep both behaviours.

## 6. Handing back

Put this in each PR body:

1. **Status:** done, partial, or blocked, with the reason.
2. **Changed files.**
3. **Tests:** the exact commands, with pass/fail counts and peak memory from the capped runner.
4. **Risks and open questions:** include anything that touched the graphics lane or an owner item.
5. **Next action for Claude.**

Leave every PR as a draft. Claude reviews it, then the owner merges.
