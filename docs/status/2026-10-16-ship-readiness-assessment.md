# Ship-readiness assessment — Chapter 1 gold

Date: 2026-10-16. Baseline: `main` @ `730d6152` (CI green, Godot 4.7.1). Author: Claude.
Scope: what stands between today's `main` and the ratified gold cut line in
`docs/ship-plan-2026-10.md` (3 hubs, 8 macro locations, main quest, 4+ full side quests,
same-map combat, DRAMGID, progression, Windows export, 5 achievements, cloud saves).
The gold date in that plan (2026-10-02) has passed without a re-baseline.

Evidence was gathered from the issue tracker, `tools/quest_audit.gd` (run today after a
project re-import; the first run failed only because the local `.godot` class cache was
stale on `AccordZone`), `data/generated/encounters.json`, the test tree, and the vault.

## 0. Same-day update (afternoon)

- PR queue merged to `main` (`089d0b86`): #498 perf, #492 accord overlay, #493 CLI (+ an
  order-dependence fix in `test_weftlumin_cli.gd`), #497 new_scene. #495/#496 had been opened
  against `feat/351-weftlumin`; #499 carries them to `main` with a real CI run. #457 (art) holds
  for the owner's icon review.
- Owner rulings, recorded in `docs/ship-plan-2026-10.md` §Owner decisions 5–8: all four location
  proposals approved; #285 cap 6 / perks at 2, 4, 6; FR-904 gate is frame time with the 2 ms
  decision line advisory; **no Steam for gold** (direct Windows build, #299 post-launch).
- `LocationRegistry.ALL` is already index-driven (PR #488), so the "branch-held until #93" rule
  in #238–#241 is moot: a baked location is in the game when its canon document lands. Still
  hand-wired per hub: `FastTravelRegistry._HUBS`, `WorldMapRegistry`, `BuildingTransitionRegistry`
  (the open remainder of #342).
- Dialogue for the new locations is #262 (C25), currently outside every milestone; a hub without
  dialogue does not count toward the cut line, so #262 joins the gold scope.

## 1. Scorecard against the PRD §3 metrics and the gold cut line

| Requirement | Target | Today | Status |
|---|---|---|---|
| Critical path completable | 100%, e2e + manual | `test/e2e/test_first_chapter_journey.gd`: 18 cases, CI green. Manual no-debug run never recorded. | Machine PASS / human OPEN |
| Main quest | act-complete, Act II hook | 3 main quests × 3 outcomes, 9/9 read back | PASS |
| Side quests | ≥ 10 with ≥ 2 outcomes | 12 (10 `dom_*`, `field_debt`, `loamroot_sprigs`); 6 stubs signposted per cut line | PASS |
| Side read-back | ≥ 60% | 21/28 = 75% (`field_debt`, `loamroot_sprigs` resolutions never read back) | PASS |
| Encounters with ≥ 3 verbs | ≥ 80% | 12 encounters; 2/12 carry a speech or context verb. No audit tool exists for this row. | UNMEASURED |
| Hubs | 3 | 1 (Dom) | **FAIL** |
| Macro locations | 8 | 4 (Dom, Wilds, Dorthkor Road, Wound Lip) | **FAIL** |
| Playtime floor | 8–12 dense hours | Unmeasured. 1,693 dialogue lines / 134 titles across one hub is an estimated 2–4 h. | **FAIL (est.)** |
| Gate T-6 comprehension | 3–5 outside testers | 0 sessions. `test/manual/gate-t/T1–T3.md` are blank templates from 2026-08-27. Tester kit is stamped `4e4fe43` (pre same-map combat). | **NOT RUN** |
| FR-904 performance | field p95 ≤ 16.67 ms on reference hardware, 3 rendered runs | Headless: frame p95 0.29 ms (holds); AI decision mean 11.2 ms vs the D9 2 ms line (5× over). Zero rendered reference runs. | **OPEN** |
| Progression | XP + skill points + perks | XP, levels, skill points live. Perks blocked since 2026-09-08 on two owner answers. | PARTIAL |
| 4 archetype playthroughs | martial / caster / talker / balanced | None recorded | NOT RUN |
| Save integrity | 0 corruption paths | Schema 9, 3 manual slots, migration sweep (#300) merged | PASS |
| Windows export | CI job | `test.yml` exports Windows x64 on every run | PASS |
| Steamworks | achievements ×5, cloud saves, depot | No GodotSteam addon; `tools/steam/*.vdf.template` + `steam_upload.sh` only (#299). Partner account status unknown. | NOT STARTED |
| Art | custom chrome, icons, 6 portraits, capsule | Chrome pass (#297) merged; 29 icons in PR #457; Gemini quota is 0 so no generated batch exists | PARTIAL |

Audit debt worth one short pass (not ship-blocking):
- 4 `checked_response_may_be_only_acquisition_route` warnings: `dialogue/council_elder.dialogue:7`
  (Dorthkor Road, main quest) and `dialogue/lower_trial_hall.dialogue:4/20/38`. The e2e suite
  shows an alternative elder route; verify the three Lower Trial Hall checks against FR-905.
- The 6 companion personal quests report 0 outcomes and 0 flag writes in the audit. Either
  they resolve outside `QuestRegistry` outcomes (audit blind spot) or they are not resolvable.
  Verify before claiming FR-505.
- 7 orphaned flags written and never read (`chapter_council_charge_understood`,
  `dom_shrine_asked`, `dorthkor_muster_cause`, `quest_1_resolution`, `quest_3_resolution`,
  `tutorial_keeper_fight_requested`, and the `quest_%d_resolution` template).

## 2. Where the last four weeks went

Commits since 2026-09-20 by area: docs 513, test 285, assets 116, ui 91, weftlumin 72,
globals 66, addons 44, world 32. Five of the seven open PRs are Weftlumin (in-game editor)
waves; no new location has yet been authored with the editor. The editor's purpose
(E3.4 `new_scene` field/interior templates, PR #497) is exactly the missing content, so the
investment is recoverable, but only if the next wave is content, not more tooling.

Open PRs, all mergeable: #498 perf (#282), #497 E3.4, #496 E7.1 follow-up, #495 E7.3 runbook,
#493 E7.1 CLI, #492 E6.2 overlay, #457 art pipeline (partial, quota-blocked).

## 3. Critical areas, ranked

1. **World content is half the cut line.** Hub 2 (#238), Hub 3 (#239), macro locations 7–8
   (#240, #241) are open, Size L each, no branch started. Lore comes from the eight vault
   proposals in `../dramgid-vault/proposals/locations/` (ashlaren, hollowmere, kesselford,
   sorrowsrest-stead, the-hushfeld, the-long-verge, threshold-of-the-advance, veldmark-dig);
   none carries an approval. The issues also hold their registry merge until #93 passes,
   which deadlocks against item 2. Estimate: 4–5 weeks for four locations with the editor
   templates, serial on review capacity.
2. **The only human gate has never run.** Gate T-6 (#93 / #301) needs a fresh Windows build
   (the kit predates same-map combat by seven weeks), 6–8 recruits, two rounds. Every later
   human obligation (FR-906 coherence, 4 archetypes, store-page playtime claims) sits behind
   it. Lead time: 1 week to recruit, 2 weeks across two rounds.
3. **Owner rulings stalled for five weeks.** Perk cadence and Chapter 1 level cap (#285,
   computed recommendations posted 2026-09-08: cap 6, perk every other level from 2);
   the D9 2 ms per-decision line vs. the frame-time floor that already holds (#282/#175);
   approval of the location proposals. Each is minutes; together they unblock #285, #282 and
   all four content issues.
4. **FR-904 on reference hardware.** Three rendered runs per `docs/fr-904-runbook.md` on a
   declared machine, after the D9 ruling. Half a day once PR #498 is merged.
5. **Steam and art chores on the critical path by calendar.** Steamworks partner account
   (30-day first-release wait after the fee), GodotSteam addon install (#299), Gemini
   billing for the portrait batch (#457), DS binaries and spec exports (#112, #115).

## 4. Recommended sequencing

Week 1 (owner decisions + merge the queue)
- Owner: rule on #285 (two answers), rule on the D9 line, approve or cut the eight proposals
  to the four needed, confirm Steamworks account state, enable Gemini quota or cut generated
  portraits from gold.
- Claude: merge #497, #493, #496, #495, #492, #498; author `docs/playtest-kit` refresh and a
  new Windows kit from `main`; run the audit-debt pass above.
- Decouple the content issues from #93: hubs merge into the registry when their own tests
  and audit pass. Comprehension testing measures systems legibility, not location count.

Weeks 2–5 (content, one location per week)
- Hub 2 → macro 7 → Hub 3 → macro 8, each through the Weftlumin templates, `quest_audit` 0
  errors, phase-reachability rows, encounter entry, travel exits, read-back wired.
- Playtest round 1 in week 2 on the Hub-1 build; round 2 in week 5 with Hub 2.

Week 6 (bug fix only, gold)
- FR-904 reference runs, 4 archetype playthroughs, Steam depot, tag `v1.0.0-ch1`.

Realistic gold if week-1 decisions land this week: **early December 2026**. The Steamworks
30-day wait is the hard floor if the account does not exist yet.

## 5. Stop doing

- No new Weftlumin waves beyond the open PRs until Hub 2 ships through the editor.
- No further perf PRs on #282 until the D9 line is ruled; frame time already holds.
- No playtime claims anywhere until Gate T-6 produces a measured session length.
