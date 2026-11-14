# Combat hotbar: eight slots, auto-filled (owner ruling 2026-11-01)

Branch: `claude/combat-hotbar`, stacked on `claude/combat-one-bar` (PR #552). Lower Trial
Hall warden fight, 1920x1080 logical canvas, as the player sees it.

**Ruling under test** (`docs/owner-decisions.md` §5, 2026-11-01): a level-1 character had
about 25 usable commands on the bar at once. The owner chose an eight-slot hotbar,
auto-filled. Keys 1–8 fire the slots, and every other command waits behind MORE.
Presentation only: class kits, costs and rules are unchanged.

## How the bar fills

- **Default fill, one command per role:** Strike, Guard, the class signature, Defining
  Strike, then the two cheapest usable weapon arts and the two cheapest usable spells. Any
  slot still open takes the cheapest usable command left.
- **Locked slots keep their place.** Strike and the signature hold their slot while locked
  (out of reach, nothing banked yet). Every other role needs a command the member can use
  now.
- **Slots stick for the battle.** A key always fires the same command. A slotted command that
  is momentarily locked stays in its slot, dimmed with its reason, and its key does nothing.
- **Another class's action or an unowned perk never takes a slot.** Those stay in MORE.
- **A command chosen from MORE joins the bar** in the slot its member used least this battle
  (ties: the later slot). Slot 1 is never given up.
- **Late openers join on their own:** a resolution, Defining Strike or parley that becomes
  usable mid-fight is added to the bar automatically.

## Frames

| Frame | What it shows |
|---|---|
| `01-hotbar-player-turn.png` | Vex's first turn: `1 STRIKE` (dimmed, out of reach) · `2 GUARD` · `3 SPEND SCARS` (dimmed, no Scars banked) · `4 THRUST` · `5 BLINDING THROW` · `6 KINDLE` · `7 DOUSE` · `8 FOCUS`; `MORE · 50` in the footer. Two rows, no scrolling. |
| `02-more-open.png` | MORE open: the hotbar, then the usable spare commands in catalog order, then the locked ones beside their reasons. |
| `03-promoted-from-more.png` | STABILIZE chosen from MORE took slot 8 (all slots unused, so the tie went to the later slot). Slots 1–7 unchanged. |
| `04-1366x768.png` | The owner's minimum resolution: same layout at 0.71, nothing clipped. |

## How the frames were made

`SOUL_METER_TEST_DATA_DIR=<fresh dir> bash scripts/test.sh -a test/manual/combat_hotbar_capture.gd`
under Xvfb (Godot 4.7.1). Result: 1/1 passed. The harness starts the warden session with
`GameFlow._on_battle_entered()`, the same path production uses.

## Playtest declutter (owner playtest, 2026-11-02)

The owner's note: "the UI/hotbar needs a lot of work, still way too busy without telling you
much". Owner ruling the same day: every element must name something you act on, and the rest
goes behind a toggle (BREAKDOWN, B). Same harness, same commit before and after; each image
shows before on top (or left) and after below (or right).

| Frame | What changed |
|---|---|
| `05-playtest-declutter-bar.jpg` | The bar at the player's first turn. The plate keeps what a turn spends: HP, AP, Breath and Scars. Tempo, CT and facing, Aftertones and attunement now open with BREAKDOWN. The idle `CURSOR —` heading is gone; the line fills only while the pointer is over a cell. The party column is gone in a solo fight (it repeated the plate). The hotbar commands are 15 px instead of 12, on 30 px slots. MORE counts what it adds that can be used now (`MORE · 13`), not every locked command (`MORE · 50`). |
| `06-playtest-declutter-more-open.jpg` | MORE open. The usable commands, then the locked ones with their reasons, scrolling inside the command column as before. |
| `07-playtest-declutter-full-frame.jpg` | The whole frame, for scale. |

