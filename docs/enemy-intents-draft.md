# Enemy intents: Sacred Clarity and Read Aloud (#285 slice 5)

The last two Lensbearer perks. Both were deferred on 2026-10-26 to "an enemy-intents slice", because no
telegraph or intent preview existed to build them on. Owner rulings 2026-10-29, all as recommended.

## Rulings (2026-10-29)

| # | Question | Ruling |
|---|---|---|
| 1 | Sacred Clarity's "Fading cost" | **1 Clarity, 1 AP / 1 CT**, the same price as Spend Clarity. The vault names Stuid's resource "Fading / Clarity" (`systems/magic-system.md` §Per-class resources), so Fading is Clarity. |
| 2 | Is a telegraphed enemy bound to it? | **Locked.** The enemy acts on what was shown, and re-plans only if that becomes impossible. |
| 3 | What a telegraph shows | **Action, target, aim, odds.** Hit chance, damage on hit, injury chance on hit, from the same forecast the player's own attacks use. |
| 4 | Read Aloud's reading | **Shared reveal, this round.** While Stuid's Clarity reveal is armed, every ally's spell forecast also shows its true terms until the round ends. Stuid's own cast still consumes it. |

## What an intent is

Chapter 1 enemies have one plan: `enemy-strike` the first living ally, choose a called-shot aim from
forecast data (`choose_enemy_aim`), or move toward that ally when it is out of reach. An intent
is that plan written down before the turn: `{action_id, target_id, aim_location}`.

- **Locked part:** the target and the aim. On its next turn the enemy goes after the shown target even
  if another ally is now first in line, and uses the shown aim if it is still legal and payable.
- **Board part:** whether it strikes or closes the distance follows the board at turn time, the same
  as an unread enemy. "Strike Kero, head" with Kero out of reach becomes a move toward Kero.
- **Re-plan:** if the shown target has fallen or left the battle, the enemy plans afresh. If the
  shown aim is no longer legal (the part is now injured, cover, cost), it picks its aim afresh.
- **One turn:** the lock is spent by the enemy's next turn, whatever it does.
- **Odds are live:** the locked choice is fixed, but its numbers are recomputed whenever the HUD
  refreshes, so guarding or moving after a read shows its effect.

There are **no baseline intents**: unread enemies show nothing. Shown intents for every enemy would make
Sacred Clarity worthless, and the ratified identity makes information Stuid's resource.

## Sacred Clarity (Lensbearer level 4 signature)

A command (`sacred-clarity`, `ranged` profile: Stuid needs line of sight to read a target). It spends
one Clarity and locks the target enemy's intent. Refused without the perk, with no Clarity left, or
when that enemy is already read. It does not arm or use the cast reveal, so the two Clarity uses
compete for the same three points.

**Shown:** the enemy's turn-order marker gains a line, e.g. `→ Kero · head · 70% · 9 dmg · 25% injury`.
The marker exists in every battle mode (CT strip and AP round view); the on-grid stage arrow does not
(same-map battles draw through the field overlay), so the strip is the one surface.

## Read Aloud (Lensbearer level 6 capstone, Fame ≥ Known)

While Stuid's reveal is armed, an ally's spell forecast also carries `reveal`, through the slice 4
`on_ally_cast_forecast` channel, during the round the reveal was armed. Only Stuid's own committed
cast disarms it; allies read from it without spending it. This needs no intents; it shares the slice
because the 2026-10-26 ruling deferred the two together.

## Agent readings, flagged under owner item 9

- Both blurbs are agent wording of these rulings.
- Sacred Clarity's `ranged` (line-of-sight) profile. `encounter` would let Stuid read through walls.
- Round = the controller's `round_number` (an AP round, or a CT measure).

## Not in this slice

- Enemies still only strike. Smarter AI (casts, focus fire) makes the lock matter more, and will let
  The Unspoken Term's cast contract trigger. Nothing here assumes the AI stays simple.
- Trap revelation and permanent Fading (`docs/class-completion.md`) stay open.
