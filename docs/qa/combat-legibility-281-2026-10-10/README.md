# #281 combat legibility evidence: Bog Wight with the log hidden (2026-10-10)

Branch: `qa/281-legibility` (based on `main` @ `8b7b2f6b`; the legacy battle screen is gone and
`ui/screens/battle.tscn` is the only battle HUD). Tracker: #281, comment "Inherited from #211:
combat must be *legible*".

**Acceptance under test:** *"A Bog Wight encounter is readable end-to-end with the log hidden:
you can see who acted, on whom, from where, and what it cost."*

**Overall verdict: NOT MET.** Every presentation piece #211 asked for now exists in code, and
most of it renders. A stranger looking at these frames still cannot reliably tell who acted on
whom. The two bodies stand on adjacent cells and overlap. The enemy's reply plays in the same
frame as the player's strike, and its result card covers the player's damage number. The
highlights show the state after the enemy phase has already resolved, not the beat that is
playing. "What it cost" is the most readable part: the damage cards, the HP bars and the dock's
FOE/PARTY HP all show it.

No game code, mechanics or art changed in this pack. The only additions are the capture suite,
these PNGs and this README.

## How the frames were made

| Run | Command (repo root, Godot 4.7.1, Xvfb via `scripts/test.sh`, fresh `SOUL_METER_TEST_DATA_DIR` per run) | Result |
|---|---|---|
| Production-flow hook | `SOUL_METER_BOG_WIGHT_CAPTURE_DIR=<dir> bash scripts/test.sh -a test/integration/test_game_flow_battle_transitions.gd` | 7/7 passed. Wrote `bog-wight-hud.png`, saved here as `00-ambient-start-no-deployment.png` |
| Legibility capture (new) | `SOUL_METER_LEGIBILITY_CAPTURE_DIR=<dir> bash scripts/test.sh -a test/manual/combat_legibility_capture.gd` | 2/2 passed, exit 0 |
| Presentation regressions | `bash scripts/test.sh -a test/unit/test_combat_overlay.gd -a test/integration/test_combat_presentation.gd -a test/test_battle_stage_region.gd` | 25/25 passed, exit 0 |

`test/manual/combat_legibility_capture.gd` copies the production-flow fixture from
`test_game_flow_battle_transitions.gd`. It loads `test_room`, arms `GameFlow.watch_field_hostiles()`
and walks the player next to the authored `BogWight`. The real alert then opens the session, the
chart enters `Playing/Battle` and `UIManager` mounts `battle.tscn`. The script hides the dock's
log label (`_log_lbl`) and captures 1920x1080 frames. Strikes are real `submit_action(&"strike")`
calls. Hovers and clicks are `Viewport.push_input` mouse events, so they take the real GUI path.

The harness changes these things, and only these:

- **Slow motion.** Beats last 0.14–0.22 s. `Engine.time_scale` is lowered to 0.08 while a beat
  plays, so a frame can land mid-beat. Files named `*-slowmo*` were captured this way. The
  overlay renders them normally.
- **KO HP.** The wight's HP is set to 1 before the KO strike.
- **Move-slide fixture (frames 21–23).** No real path exists to watch: seating puts the wight
  beside the party, and the ally has no movement budget (gap G6). The wight is displaced 4 cells
  back on the battlefield model and one snapshot is pushed to the HUD. Then the controller's own
  enemy turn walks it back along its path.
- **File sizes.** Full frames are quantized to 256 colours to keep the pack small, which bands
  the meter gradients slightly. The `zoom-*.png` crops are 2x enlargements of the original
  lossless captures.

## Per-requirement verdict

| # | Requirement (from #281 / #211) | Verdict | Where in code | Frames |
|---|---|---|---|---|
| 1a | Units drawn with `globals/unit_art.gd` art at their grid cells | **MET** | Hostile art: `actors/hostile/hostile.gd:74-76`. Player: `actors/player/player.gd:74`. Followers: `actors/party_followers/party_follower.gd:30`. Overlay snaps nodes to the snapshot cell: `world/combat_overlay.gd:358-383` | 01, 20, zoom-01 |
| 1b | Active-unit highlight | **PARTIAL** | Bronze diamond on `_active_id`: `world/combat_overlay.gd:202-213, 624-631` | 01/02b show it under Vex. During the wight's turn (22-x, 06) it still sits on Vex, because the enemy phase resolves in one frame and the next `turn_started` has already moved `_active_id` back (G2) |
| 1c | Current-target highlight | **PARTIAL** | Cinder diamond on preview/target: `world/combat_overlay.gd:70-72, 624-631`. Preview armed by hover: `ui/hud/battle_interface.gd:199-213` | 02b / zoom-02b show it (red diamond plus "ORDINARY · HIT 66%" card). It never appears after a committed action (03, 06, 11), because the turn start that follows clears `_target_id` |
| 1d | Facing shown | **PARTIAL** | Sprite flip on `facing` containing `w`: `world/combat_overlay.gd:384-387`. Chevron: `world/combat_overlay.gd:612-623`. Unit plate text "FACING E": `ui/hud/regions/unit_plate/*` | Chevrons are visible in zoom-01/zoom-22 but tiny (6 px arms, 2 px stroke). They point along screen axes, not the iso grid (G7) |
| 2 | Cell hover/selection reads out through the (x,y)/height strip | **MET** (readability weak) | `ui/hud/regions/stage/battle_stage_region.gd:356-376` (input), `458-472` (`tile_hovered`), `497-503` (field cell pick via `CombatOverlay.cell_at_viewport`). Readout: `ui/hud/battle_interface.gd:37-39, 195-196`. Hover rim: `world/combat_overlay.gd:595-597` | 02: lavender rim on (33,47) and `(33,47) · HEIGHT 0 ·  0 ·` in the strip. 02b: `(33,45) …`. The strip is small grey text at the far left, and its element field prints empty (G8) |
| 3a | Driven from the event replay stream, not wall-clock | **MET** | `CombatOverlay.consume_event` (`world/combat_overlay.gd:174-221`) reads only `CombatEvent` snapshots. HUD replay mounts with beats suppressed: `ui/screens/battle.gd:62-65`, `ui/hud/regions/stage/battle_stage_region.gd:179-187`. History and replay: `globals/battle.gd:833-840, 1567-1568` | Regressions above (`test_combat_presentation`, `test_battle_stage_region` replay cases) |
| 3b | Attacker lunge / flash toward target | **PARTIAL** | Lunge: `world/combat_overlay.gd:411-423`, capped at `DS.SPACE_4` (8 world px), 0.14 s each way. Target flash and hit pulse: `world/combat_overlay.gd:434-448` | The pulse rings are visible on both bodies in 03/06/11 (zoom-03, zoom-06, zoom-11). The lunge cannot be seen even in slow motion: 8 px against ~60 px figures that already overlap (G3) |
| 3c | Damage number over the target | **PARTIAL** | `world/combat_overlay.gd:449-462`, `ui/hud/combat_result.gd` (1.8 s card) | 03: the player's "Bog Wight / 11" card is covered by the wight's reply card "Vex the Unbowed / 1 DAMAGE" in the same frame (G1). 06 and 11 read clearly. Cards name the target only, never the attacker (G4) |
| 3d | HP tick | **PARTIAL** | Overlay HP bar and number: `world/combat_overlay.gd:598-611`. Dock FOE/PARTY HP: `ui/screens/battle.gd:380-419` | 05: wight bar drops 18→7 and the dock reads `FOE BOG WIGHT · HP 7 / 18`. The change is an instant redraw, not a tick. The wight's HP number is hidden under the "Loamroot Sprig" pickup label (G5) |
| 3e | KO fade-out | **PARTIAL** | `world/combat_overlay.gd:388-391`: when HP is 0 the alpha is set to 0.35 with no tween. The HP bar disappears (`:600`) | 11/zoom-11: the wight is translucent behind the "11 DAMAGE" card, so the fall reads. It is a snap, not a fade. 13: after settlement the downed body is barely distinguishable |
| 3f | Move animated as a slide along the path | **PARTIAL** | `world/combat_overlay.gd:369-381` with `ui/hud/combat_motion.gd:5-22` (0.14 s per cell along `path_cells`) | zoom-22-approach-sequence: the body slides cell by cell (fixture start). The HP bar, number, facing chevron and highlights jump to the destination at the first frame and wait there (G2). No player-side slide could be captured (G6) |
| A1 | Ambient fight starts on the field scene with no deployment | **MET** | Field watch to `enter_battle`: `ui/flow/game_flow.gd`. Asserted in `test_game_flow_battle_transitions.gd:124-130` and in the new suite | 00 (production flow, log visible) and 01 (log hidden). The field stays loaded, no slate appears and `DeploymentSlate` is asserted inactive |
| A2 | Set-piece keeps deployment | **MET** (headless assertion, not captured) | `ui/flow/game_flow.tscn` `enter_set_piece` → DeploymentSlate → Attune → Loadout → Place. `world/interiors/lower_trial_hall.gd:73-88` | `test_enter_set_piece_traverses_the_existing_deployment_chain` passed in this run. Rendered set-piece evidence is in `docs/qa/same-map-2026-10-03/` |
| A3 | Event replay contract unchanged | **MET** for this branch | This pack touches no runtime code (`git diff main --stat` lists only `test/manual/` and `docs/qa/`) | 25 presentation regressions passed |

## Can a stranger read it? Judged from the frames, log hidden

| Question | Readable? | Why |
|---|---|---|
| Who acted? | **Mostly no** | Only the unit plate and the CT strip name the active unit. On the field the bronze diamond shows the next actor, not the one acting (06, 22-x). The lunge is invisible. |
| On whom? | **Partly** | Damage cards name the target. In the player's strike frame (03) the counter-card covers the player's own result. The red target diamond only appears on a hover preview (02b). |
| From where? | **Weak** | Units are on real cells, but the two combatants overlap on adjacent cells (01, 20, zoom-01). The field "Loamroot Sprig" pickup label and the "LOCKED — That is not available yet." prompt sit on top of the fight. |
| What it cost? | **Yes** | "11 DAMAGE" / "1 DAMAGE" cards (06, 11), the HP bar drop (05), and the dock FOE/PARTY HP readouts, which are HUD text rather than log text. |

## Concrete gaps

- **G1. Beats are not sequenced.** The controller resolves the enemy phase in the same frame as
  the player's action. The overlay starts every beat at once, so the reply's card stacks on top
  of the player's result (frame 03). Nothing queues one beat behind the other.
- **G2. Overlay state runs ahead of the motion.** The highlights, HP bar/number and facing
  chevron are drawn from the latest snapshot cell and `_active_id`/`_target_id`. The bodies
  tween to catch up. During an enemy move or strike, the bar and chevron already sit at the
  destination and the bronze diamond already marks the next ally (zoom-22). After any committed
  action the target diamond is cleared before it is ever drawn.
- **G3. Lunge too small to read.** The lunge is capped at 8 world px
  (`world/combat_overlay.gd:420`) on ~60 px figures and is invisible at field zoom.
  Hit-feedback 2026-09-21 shrank it on purpose, so the size is a design call for the owner.
- **G4. Result cards omit the attacker.** `combat_result.tscn` shows the target name and the
  outcome. "Who acted" has to come from elsewhere, and with G1/G2 nothing else supplies it.
- **G5. Field clutter over the fight.** On `test_room` the `FieldDebtProof` pickup sits at the
  wight's authored position (`world/test_room.tscn`, both at (650,750)). Its "Loamroot Sprig"
  label covers the wight's HP number. The locked-prompt "LOCKED — That is not available yet."
  (later "E — Take") renders under the combatants all fight long. Interact prompts and labels
  are not suppressed during combat.
- **G6. No player move during this session.** On the ally turn Vex has `action_points = 0`, so
  `_movement_snapshot()` (`globals/combat/combat_controller.gd:956-987`) returns no reachable
  cells. The move cards are locked with "Unknown battlefield position: front/back/flank/." and
  the MOVE buttons render disabled. The capture log shows this for both cases. Session seating
  also puts the wight on the cell next to the party even when the party stopped four cells away
  (frame 20), so the fight opens with overlapping bodies. The root cause (CT-mode AP budget vs.
  grid move) was not investigated here. It is a mechanics/flow question, not presentation.
- **G7. Facing chevron uses screen axes.** `world/combat_overlay.gd:613-616` maps `e` to screen
  (1,0). On the iso grid, cell +x is screen (32,16), so every chevron points about 27° off the
  neighbour it names. The chevrons are also 6 px, which is hard to see.
- **G8. Height strip is faint and partly empty.** `(x,y) · HEIGHT n` works, but the charge
  element prints as empty (`ui/hud/battle_interface.gd:196` reads `charge_element_id`, which the
  tile has blank). The strip is small grey text at the far bottom-left, nowhere near the cursor.
- **G9. KO is a snap, not a fade.** `node.modulate.a = 0.35` with no tween
  (`world/combat_overlay.gd:391`). After the session settles, the downed wight is nearly
  invisible (frame 13).
- **G10. HP tick is a redraw, not an animation.** The bar jumps to the new value on the
  snapshot.
- **G11. Camera framing settles late.** Frame 01, taken 1.5 s after the session opens, shows the
  framing still short of the position the later frames settle on (compare 01 with 02). Cosmetic.

## Frame index

| File | Shows |
|---|---|
| `00-ambient-start-no-deployment.png` | Production flow (existing hook): ambient Bog Wight session on `test_room`, chart in Battle, no deployment step, log visible |
| `01-session-open.png`, `zoom-01-open.png` | Log hidden. Vex (34,45) beside the wight (33,45); bronze active diamond under Vex; chevrons; HP 18 / 43 |
| `02-hover-height-strip.png` | Hover on (33,47): lavender rim, strip `(33,47) · HEIGHT 0 ·  0 ·` |
| `02b-hover-foe-target-preview.png`, `zoom-02b-target-preview.png` | Hover on the wight: red target diamond plus forecast card |
| `03-strike-mid-beat-slowmo-0.png`, `zoom-03-strike-mid-beat.png` | Vex's strike mid-beat: pulse rings on both bodies; "Bog Wight 11" covered by the reply card "Vex the Unbowed 1 DAMAGE" |
| `05-hp-after-strike-0.png`, `zoom-05-hp-after.png` | After the strike: wight bar 7/18, dock `FOE BOG WIGHT · HP 7 / 18` |
| `06-enemy-acts-slowmo.png`, `zoom-06-enemy-acts.png` | Wight's strike on Vex: pulse on Vex, "1 DAMAGE" card |
| `11-ko-mid-beat-slowmo.png`, `zoom-11-ko.png` | KO: wight snapped to 35% alpha, "11 DAMAGE" card |
| `13-ko-settled.png` | Encounter resolved, camera released, CONTINUE in the dock |
| `20-separated-open.png` | Party stopped 4 cells off; seating still put the wight next to Vex |
| `21-…`, `22-enemy-approach-slowmo-{1,3}.png`, `23-…`, `zoom-22-approach-sequence.png` | Fixture-start enemy approach: the body slides along its path while bar/chevron wait at the destination |
