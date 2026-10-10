# #281 combat legibility after the presentation fixes: Bog Wight, log hidden (2026-10-10)

Branch: `feat/281-combat-legibility` (based on `main` @ `8b7b2f6b`). The before-pack is
`docs/qa/combat-legibility-281-2026-10-10/` on `qa/281-legibility` (PR #466).

**Acceptance:** *"A Bog Wight encounter is readable end-to-end with the log hidden: you can see
who acted, on whom, from where, and what it cost."*

**Verdict from these frames: met for who / on whom / what it cost, with two remaining
limits on "from where".** The limits are outside this change. The two bodies still start on
adjacent cells and overlap, because session seating and ally movement belong to G6. The lunge
is still capped at 8 px (G3, the owner's call).

## How the frames were made

`SOUL_METER_LEGIBILITY_CAPTURE_DIR=<dir> bash scripts/test.sh -a test/manual/combat_legibility_after_capture.gd`
(Godot 4.7.1, Xvfb, fresh `SOUL_METER_TEST_DATA_DIR`). Result: 2/2 passed. The harness is the
#466 script with one timing change. Frames are now keyed to the beats the overlay has
presented, not to wall-clock offsets. Under Xvfb, frame deltas lag the wall clock, so
wall-clock offsets landed on the wrong beat. The opening, the hover path, the real
`submit_action(&"strike")` calls, the 1-HP KO set-up and the approach fixture are unchanged
from the audit. Full frames are quantised to 256 colours. The `zoom-*` strips are crops of the
lossless captures.

## Per-gap status

| Gap | Status | What changed | Frames |
|---|---|---|---|
| G1 beats not sequenced | **Fixed** | `CombatOverlay` presents events in emitted order and holds each beat before the next: a strike result for 1.2 s, an enemy phase cue for 0.4 s, a move for its path length. The model still resolves the whole enemy phase in one frame. Replay (`animate_events = false`) presents anything queued at once. | `zoom-03-beat-sequence`: Vex → Bog Wight 11, then the wight's turn, then Bog Wight → Vex 1, then Vex's turn |
| G2 overlay ahead of motion | **Fixed** | HP bar, number, chevron and active/target diamonds are drawn at the bound body, so they ride slides and lunges. The target diamond shows on the target for the whole action beat. | `zoom-22-approach` (diamond and bar travel with the wight), `03-strike-0-0` (red diamond on the wight while Vex strikes) |
| G4 card omits attacker | **Fixed** | The card headline reads `attacker → target` from the event's snapshot (`HitPulse.headline`). The next card or turn cue retires the previous one, so cards never stack. | `03-strike-0-0`, `03-strike-0-3` |
| G5 field labels over the fight | **Fixed** | `FieldMap.set_combat_mode(true)` makes every Label under field interactables and travel exits transparent (`self_modulate.a = 0`) and restores them through the existing `_restore_controls` pattern. `visible` is left alone because range changes toggle it mid-fight. | `01-session-open`: no "Loamroot Sprig", "LOCKED — …" or "RETURN TO DOM" |
| G7 chevron on screen axes | **Fixed** | The chevron points along the grid neighbour the facing id names (`IsoGrid` projection, so "e" is screen (32,16)). It is a filled bronze triangle with a dark outline at the cell rim. | bronze triangles at the lower-right rim of both cells (both face e) |
| G8 height strip | **Fixed** | `CursorReadout` uses `HeadingLabel`. The strip prints `(x,y) · HEIGHT n`, then the occupant's name, then charge and note only when the tile has them. | `zoom-02-strip`: `(33,47) · HEIGHT 0`, `(33,45) · HEIGHT 0 · BOG WIGHT` |
| G9 KO snap | **Fixed** | Fades over 0.8 s to `KO_TINT` (dimmed, alpha 0.8) and stays there. | `zoom-11-ko`, `zoom-13-ko-settled`: the downed wight remains visible behind Vex |
| G10 HP redraw | **Fixed** | The bar eases to the presented HP over 0.4 s. A red slice shows the lost HP, then drains. | `zoom-03-beat-sequence` frame 1: bar 14 mid-tick with red slice |
| G3 lunge size | Not changed | Owner's call | — |
| G6 ally movement / seating | Not changed | Handled by another agent | bodies still overlap on adjacent cells |
| G11 camera framing | Not changed | Out of scope | — |

## Remaining readability limits (honest)

- **From where:** the two combatants stand on adjacent cells and their sprites overlap. The
  diamonds, chevrons and the strip's occupant name separate them, but the bodies do not.
  This is G6 seating.
- **HUD outside the field:** the dock FOE/PARTY HP, unit plate, CT strip and "ENCOUNTER
  RESOLVED" read the live model. During a sequenced enemy phase they can show its end state
  before the field presents it. The field cards and bars are now the sequenced source. Making
  the dock follow the beat would mean touching `ui/screens/battle.gd`'s live reads, which this
  change did not do.
