# Bloodbellow routes on the field — #652 gap 1

Rendered check for the Bloodbellow's two authored routes, fought where it stands on Dorthkor Road.
Captured by `test/manual/muster_routes_capture.gd` under Xvfb at 1920×1080, on branch `claude/652-muster-routes`.

## How it gets there
The harness loads the real `world/dorthkor_road.tscn` with the vanguard beaten (`defeated_breach_hound`) and the muster not.
It then calls `GameFlow.watch_field_hostiles()` and places the party 150 px west of `MusteredDead`.
The muster's own proximity alert opens the session. That is the edge a player crosses, not a direct `Battle.start`.

The party guards until one enemy round has passed. Then:

| Route | Refusal at capture | Why |
|---|---|---|
| Release the Bound Soldier | allowed | One enemy round survived; Balance 0 is inside −20…+20. |
| Speak Its Muster-Name | `balance`, nearest unblock 50…100 | Needs Order +50 and 3 Soul. |

## Frames
1. `01-muster-routes-on-the-bar.jpg`: Release sits on the hotbar (slot 8).
   - A usable RESOLUTION command always surfaces onto the bar (`CombatBar._always_surfaces`).
   - Speak is locked, so it waits behind MORE as a dimmed tile with its reason on the hover card (owner ruling 2026-11-02, item 33). It surfaces the moment Order and Soul allow it.
2. `02-after-release.jpg`: the log reads "Vex the Unbowed chooses Release the Bound Soldier. The held center opens a way out. The soldier's soul leaves the armor."
   - The bar shows ENCOUNTER RESOLVED.
   - The ledger notices name Ironbrand Sentinels and word of you, with the `released` cause.
3. `03-field-after-the-fight.jpg`: back in exploration, the empty armor lies dimmed and slumped where it stood.
   - Before this PR's overlay fix it stood back up in full colour.
   - The harness closes the combat HUD directly rather than pressing CONTINUE. CONTINUE's `battle_end` would drive the live flow chart, which this harness bypasses. Both paths free the same overlay.

## Checked in the log
- `RESULT outcome=released`
- `FLAG dorthkor_muster_outcome=released`
- `MUSTER state=3` (DOWNED), `modulate=(0.55, 0.55, 0.55, 0.7)`

## Not shown
- **The `named` route.** Its gate needs Order +50 and 3 Soul, which this harness does not stage. `test_field_group_resolution.gd` covers the session wiring that both routes share.
- **The overlay presentation** of a release is a fall, the same KO fade a killing blow gets. No new art.
