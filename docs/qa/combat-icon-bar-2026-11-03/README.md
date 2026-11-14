# Combat icon bar: icon tiles, a hover card, out-of-reach commands arm (owner 2026-11-02)

Branch: `claude/combat-icon-bar`, stacked on `claude/demo-ai-vs-ai` (PR #568). Frames 01–05:
the Lower Trial Hall warden fight at 1920x1080, as the player sees it, with the party started
a few cells from the warden. Frame 06: the 5v5 demo from the title button, playing itself.

**Owner note under test** (2026-11-02, item 33): "I couldn't move most of the units and
couldn't use any range[d] attacks or anything - and the screen is very busy. We could have
abilities behind like icons with a hover tooltip with the info to utilize space better."
Presentation and input only. Class kits, costs, rules and the AI are unchanged.

## What changed

- **Each command is an icon tile.** The tile shows the glyph, the caption, the slot key in
  the top-left corner and the AP cost in the top-right corner. A spell uses its element's
  glyph; other commands use the command glyphs in `assets/icons/png/64/commands`. Those
  icons are still `pending_owner_review` in the icon manifest.
- **Hovering a tile shows a card** above the bar. It lists the name, the costs (AP; for a
  spell, its Breath, Soul and fizzle forecast), the target, reach, tone and key, the effect
  text, and, for a locked command, why it is locked. Tiles no longer have tooltip text.
- **A foe out of reach no longer locks the command.** At the start of a fight the two lines
  stand apart, so the bar used to lock Strike and every spell. That is why ranged attacks
  looked unusable. Now a refusal that only concerns where the target stands (range, an
  obstacle, an occupied cell, elevation, adjacency) arms the tile instead. The next click on
  a foe uses it. If the foe is out of reach, the unit walks in first and the field quote
  names the cost (`WALK IN · MOVE 1 + STRIKE 2 = 3 AP`). Refusals for other reasons (costs,
  no target present, not in the kit) still lock.
- **Locked commands in MORE** are dimmed tiles in their own row. Their reasons are on the
  hover card instead of a text column.
- **The party column is one line per member**, so five members fit the bar's height.
- **The key hints move below the turn strip** when ten units fill it. While the demo plays
  itself, the hints list only the keys that still do something.

## Frames

| Frame | What it shows |
|---|---|
| `01-icon-bar-player-turn.png` | Vex's first turn, the warden two cells away. `1 STRIKE` is armed (gold) instead of locked. `3 SPEND SCARS` is dimmed (no Scars banked). |
| `02-hover-card.png` | The card over `7 KINDLE`: `2 AP · Breath 3`, `Enemy target · reach 4 cells · tone Khash · key 7`, then the effect text. |
| `03-more-open.png` | MORE open. The spare commands are tiles under the hotbar and scroll inside the command column. |
| `04-armed-walk-in.png` | Strike armed with the pointer on the warden. The path cell is lit, and the quote reads `WALK IN · MOVE 1 + STRIKE 2 = 3 AP`. |
| `05-1366x768.png` | The owner's minimum resolution: the same layout at 0.71 scale, nothing clipped. |
| `06-demo-watching.png` | The 5v5 demo (AI vs AI). Ten units fill the turn strip and the hints sit below it. The party column has five one-line rows. No tile is armed or pressable. |

## How the frames were made

`SOUL_METER_TEST_DATA_DIR=<fresh dir> bash scripts/test.sh -a test/manual/combat_icon_bar_capture.gd`
under Xvfb (Godot 4.7.1). Result: 2/2 passed. The warden harness starts the session with
`GameFlow._on_battle_entered()`, the path production uses. The demo frame comes from the title
button flow (`GameFlow.start_class_demo()`).

## Not in this change

- The hex grid. Its plan goes to the owner separately (item 33, "plan first").
- The art for the icon set. The glyphs are the set awaiting owner review.
- The tan band across the Trial Hall in frames 01–05. It is already in
  `docs/qa/combat-hotbar-2026-11-01/01-hotbar-player-turn.png`, before this change. That
  frame is also the "before" for Strike: dimmed and locked with the warden two cells away.
