# Open-PR landing report (2026-11-07)

Task T2 of `docs/handoff-codex-2026-11-04.md`. Snapshot of every open PR against `origin/main` at `d639c3e2`, taken 2026-11-07. The handoff named this file `2026-11-04-open-pr-report.md`; it carries the date the data was taken instead.

The owner chose on 2026-11-07 to land the backlog before new roadmap content. So most stacks now also have a **landing PR**: the top of the stack merged with `main` (plus the stacks below it), with the conflicts resolved and the tests run. The original PRs are untouched. Close them as "landed" once their landing PR merges.

## How to read the table

- **Base chain:** the PR's base, that base's base, and so on down to `main`.
- **Not in main:** commits `git cherry origin/main <head>` reports as missing from `main` (`+` lines). No open PR is already fully in `main`.
- **Into main:** the result of a trial merge of the PR head into `origin/main`. The local git is 2.34, which has no `merge-tree --write-tree`, so each merge was tried in a scratch worktree and aborted (appendix A).
- **CI:** the last `test` job on 2026-11-07. PRs whose base is not `main` run only `label_pr`, so they have no test result.
- **Waiting on:** the item in `docs/owner-decisions.md`. Item 19 is the owner's merge click (agent `gh` merges are blocked).

## Landing PRs (new, 2026-11-07)

| PR | Branch | Base chain | Carries | Into main | CI | Waiting on |
|---|---|---|---|---|---|---|
| #588 | `claude/fix-weftlumin-scratch-leak` | main | test-only fix for the red CI below | clean | green | 19 |
| #586 | `claude/land-chargen` | main | #550, #557, #561, #563 | clean | green after `c6d043f7` (same patch as #588) | 19 |
| #587 | `claude/land-ui` | #586 → main | #558, #559, #560, #562 | clean (with #586) | no test job (stacked) | 19, after #586 |
| #589 | `claude/land-phase1` | #587 → #586 → main | #529, #541–#549, and #583 (whose Pandora item collided with P1.2f) | clean (with #587) | no test job (stacked) | 19, after #587 |
| #591 | `claude/land-rest` | #589 → … → main | #527, #528, #551, #566 | clean (with #589) | no test job (stacked) | 19, after #589 |
| #590 | `claude/set-piece-seat-reach` (draft) | main | T1: set-piece seats stay on the party's side of a wall | clean, also after the whole chain | pending | 19, last |

Each landing PR's body lists its conflict resolutions and the tests run. The full test tree was run locally on `claude/land-rest`, the top of the chain; the result is in #591's body.

## Every other open PR

| PR | Branch | Base chain | Not in main | Into main | CI | Waiting on | Landed by |
|---|---|---|---|---|---|---|---|
| #527 | `docs/item9-rest` | main | 1 | conflict: `docs/owner-decisions.md` | green | 19 (closes item 9) | #591 |
| #528 | `docs/roadmap-2026-10-30` | main | 24 | conflict: `docs/owner-decisions.md` | green | 19; open rows 26 (R11) and 28 | #591 |
| #529 | `feat/phase0-quick-wins` | main | 1 | conflict: `world/field_map.gd` | green | 19 | #589 |
| #538 | `codex/unit-art-u0` | #528 → main | 11 | conflict: `docs/owner-decisions.md`, `world/combat_overlay.gd` | label only | owner's graphics lane (item 28) | — left alone |
| #539 | `codex/unit-art-u1` | #528 → main | 13 | conflict: `docs/owner-decisions.md` | label only | owner's graphics lane (item 28) | — left alone |
| #541 | `codex/roadmap-p1-1-soul-trace` | #529 → main | 3 | conflict: `combat_controller.gd`, `field_map.gd` | label only | 19 | #589 |
| #542 | `codex/roadmap-p1-2-field-audit` | #541 → #529 → main | 8 | conflict: `combat_controller.gd`, `field_map.gd` | label only | 19 | #589 |
| #543 | `codex/roadmap-p1-3-barter-ratio` | #541 → #529 → main | 7 | conflict: `combat_controller.gd`, `field_map.gd` | label only | 19 | #589 |
| #544 | `codex/roadmap-p1-2b-dom-density` | #542 → #541 → #529 → main | 13 | conflict: `combat_controller.gd`, `field_map.gd`, `hollowmere.tscn`, `long_verge.tscn` | label only | 19 | #589 |
| #545 | `codex/roadmap-p1-2c-ashlaren-kesselford` | #544 → … → main | 18 | conflict: as #544, plus the two retired Kesselford interiors | label only | 19 | #589 |
| #546 | `codex/roadmap-p1-2d-item-packet` (draft) | #545 → … → main | 19 | conflict: as #545 | label only | none: its packet was answered 2026-11-01 and built in #549 | #589 |
| #547 | `codex/roadmap-p1-2e-hubs-skills` | #546 → … → main | 26 | conflict: as #545 | label only | 19 | #589 |
| #548 | `codex/roadmap-p1-4-weapon-stat-packet` | #541 → #529 → main | 9 | conflict: `combat_controller.gd`, `field_map.gd` | label only | 19 | #589 |
| #549 | `codex/roadmap-p1-2f-items-tables` | #547 → … → main | 32 | conflict: as #545, plus `ashlaren.tscn` | label only | 19 | #589 |
| #550 | `codex/chargen-randomize` | main | 2 | clean | green | 19 | #586 |
| #551 | `codex/dev-room` | main | 2 | conflict: `save_game.gd`, `game_flow.gd`, `main_menu.gd` | red (2026-11-01) | 19 | #591 |
| #557 | `claude/chargen-quick-start` (draft) | #550 → main | 3 | clean | label only | 19 | #586 |
| #558 | `claude/ui-audit` | main | 1 | clean | cancelled (2026-11-02) | 19 | #587 |
| #559 | `claude/conversation-u1` | #558 → main | 2 | conflict: `field_map.gd` | label only | 19 | #587 |
| #560 | `claude/field-hud-u2` (draft) | #559 → #558 → main | 4 | conflict: `field_hud.gd`, `settings.gd`, `field_map.gd` | label only | 19 | #587 |
| #561 | `claude/chargen-summary-fix` (draft) | #557 → #550 → main | 4 | clean | label only | 19 | #586 |
| #562 | `claude/panels-u3` (draft) | #560 → … → main | 7 | conflict: as #560 | label only | 19 | #587 |
| #563 | `claude/chargen-overhaul` (draft) | #561 → … → main | 10 | conflict: `owner-decisions.md`, `kit_preview.gd`, `kit_gate.gd` | label only | 19 | #586 |
| #565 | `claude/map-lived-in` (draft) | main | 6 | conflict: `docs/owner-decisions.md`, `world/kesselford.tscn` | green | owner's map lane (item 35) | — left alone |
| #566 | `claude/keeper-fight-after-conversation` (draft) | main | 1 | conflict: `game_flow.gd` | green | 19 | #591 |
| #583 | `claude/trial-hall-rooms` (draft) | main | 3 | clean | green after `0216fa5c` | 19; item 36 approved 2026-11-07 | itself, or #589 |
| #585 | `claude/test-capped` | main | 1 | clean | green after `4848aedc` | 19 | itself |

### The red CI on 2026-11-07

#583, #585 and #586 failed on one test, `test_weftlumin_inert.gd > test_bootstrap_is_inert` (line 75). None of them touch weftlumin. `test_weftlumin_new_scene` left an empty `user://weftlumin` behind, and the inert test fails whenever the new_scene suite runs first. The suite order changed on 2026-11-07. #588 fixes the test, and the same commit was cherry-picked onto all three PRs.

#551's red run (2026-11-01) predates this. Its own conflicts and two merge fallouts are resolved in #591.

## Suggested landing order

This is a suggestion for the owner; nothing here was merged.

1. **#588** (test fix), **#583** (Trial Hall) and **#585** (capped runner), in any order. #583 also rides in #589, because its Blasting Charge took Pandora id 613, which P1.2f also uses (it is 633 there). Merging #583 first or letting #589 bring it both merge cleanly; checked by trial merges in sequence (appendix A).
2. **#586**, then **#587**, #589 and #591, in that order. Each stacked PR retargets to `main` when the branch below it is merged and deleted; if GitHub does not do it, set the base to `main` by hand.
3. Close the originals each landing PR names, as "landed by #…": #550, #557, #561, #563 (#586); #558, #559, #560, #562 (#587); #529, #541–#549 (#589); #527, #528, #551, #566 (#591).
4. **Before deleting `docs/roadmap-2026-10-30`** (#528's branch), retarget #538 and #539 to `main`, or they lose their base. Both are the owner's art lane.
5. **#590** (T1) last; it merges cleanly on top of the whole chain.
6. Still the owner's to rule on: #565 (lived-in Kesselford; it conflicts with the walk-in Kesselford now on `main`), #538 and #539.

## Appendix A: commands

Run from a clone of the repo with `gh` signed in. The open-PR list, with heads, bases, drafts and checks:

```sh
gh pr list --state open --limit 100 \
  --json number,title,headRefName,baseRefName,isDraft,headRefOid,statusCheckRollup,createdAt > prs.json
```

Commits not in `main`, and the trial merge, for every PR (writes `number|head|not-in-main|result`):

```sh
git fetch origin
git worktree add --detach /tmp/pr-report origin/main
cd /tmp/pr-report
for row in $(python3 -c "import json; [print(f\"{p['number']}:{p['headRefName']}\") for p in sorted(json.load(open('prs.json')), key=lambda p: p['number'])]"); do
  n=${row%%:*}; head=${row#*:}
  git checkout -q --detach origin/main
  ahead=$(git cherry origin/main "origin/$head" | grep -c '^+')
  if git merge -q --no-commit --no-ff "origin/$head" >/dev/null 2>&1; then res=clean
  else res="conflict: $(git diff --name-only --diff-filter=U | tr '\n' ' ')"; fi
  git merge --abort 2>/dev/null || git reset -q --hard
  echo "$n|$head|$ahead|$res"
done
```

The landing order was checked the same way, merging in sequence into one detached worktree without aborting between steps: `#588, #583, #585, #586, #587, #589, #591, #590`: clean at every step.

With git 2.38 or later, `git merge-tree --write-tree origin/main origin/<head>` gives the same answer without a worktree.

Base chains: follow `baseRefName` in `prs.json` until it is `main`.

CI: the `statusCheckRollup` in `prs.json`, and for a failed `test` job:

```sh
gh run view <run-id> --log-failed | grep -aE 'FAILED|Overall Summary'
```

The test-leak finding, reproduced locally:

```sh
bash scripts/test_capped.sh res://test/integration/test_weftlumin_new_scene.gd \
  res://test/integration/test_weftlumin_inert.gd   # 4 failures before #588, 0 after
```

Waiting on: `grep -n '#<number>' docs/owner-decisions.md`, plus the item numbers in each PR's own body.
