# Progression bound — owner review packet (2026-10-09)

**Ruling being implemented (owner, 2026-10-09):** wild respawns stay farmable, but the
bonuses from leveling must be bounded so grinding cannot overrun the campaign's presumed
difficulty. The owner picked **a hard Chapter 1 level cap fitted from content, plus kill XP
scaled by level gap**. Quest and milestone XP are never scaled. This answers the
"Chapter 1 level cap" open question in `docs/game-identity.md`.

Every number below is reproduced by:

```
godot --headless --path . --script res://tools/progression_sweep.gd
```

The constants live in `globals/stats/xp_curve.gd` (`XpCurve`, re-exported by `Advancement`).
All are **PROVISIONAL until the owner signs off on this packet.**

## 1. Chapter 1 XP budget

| Source | Count | XP each | Total |
|---|---|---|---|
| Quests (`QuestRegistry.ALL_QUESTS`) | 22 | 40 | 880 |
| Suspended stubs (pay today, see §5) | 6 | 40 | 240 |
| Set pieces (bog-wight 18, loam-boar 18, vanguard 48, muster 30, jawbrace 34) | 5 | — | 148 |
| Broken Muster milestone | 1 | one level at current level | ~400 |

Curve (unchanged): level N → N+1 costs `100 × N` (L2 at 100, L5 at 1000, L6 at 1500, L7 at 2100 total).

## 2. The cap

A thorough run with no wild fighting (quests spread evenly across the five set pieces,
milestone after the third):

| Stubs pay XP | Kill scaling | Level reached |
|---|---|---|
| no | off | 5 (+328) |
| no | on | 5 (+355) |
| yes (today) | off | 6 (+168) |
| yes (today) | on | 6 (+176) |

**Recommendation: `CHAPTER_LEVEL_CAP = 7`.** That leaves one level of headroom over a thorough
run, so a player who fights the wilds earns a real reward, but no amount of farming goes
further. At the cap the XP bar stops filling. Overflow is dropped, not banked, or lifting the
cap in Chapter 2 would pay the whole grind out at once.

## 3. Kill-XP scaling

- **Foe level** = `grit + muster − 2` (min 1). Wight, boar and scavenger are L2; hound and
  bloodbellow L5; jawbrace guard L6.
- **Above the foe:** −30% per level, floor 10%, never below 1 XP.
- **Below the foe (catch-up):** +25% per level, ceiling 150%.
- **Per member:** each party member and bench recruit earns by their own level. A recruit
  behind the party catches up faster, and a veteran gets a trickle from easy foes.
- The battle summary shows what the party lead earned.

## 4. What grinding costs now

Wild kills needed to gain one level (glade table: bog-wight and loam boar, both L2):

| From level | Unscaled | Scaled |
|---|---|---|
| 1 | 6 | 5 |
| 2 | 12 | 12 |
| 3 | 17 | 24 |
| 4 | 23 | 58 |
| 5 | 28 | 250 |
| 6 | 34 | 300 |

Before this change, five days of farming the glade bought a level at L5. Now it takes ~250
kills. Early levels are untouched, so a new player is not punished for fighting.

## 5. Owner questions (recommendations, not decisions)

1. **Cap 7?** Recommended (see §2).
2. **Should suspended stubs pay quest XP?** Today `suspend_stub()` runs through `turn_in()`,
   which pays 40 XP for a "to be continued" ending. That looks unintended. If stubs stop
   paying, a thorough run reaches L5 and the same rule gives a cap of **6**. Not changed here.
3. **Scaling numbers** (−30%/level, 10% floor, +25%/level, 150% ceiling): fine as a first cut?
