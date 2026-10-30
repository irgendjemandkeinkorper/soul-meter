# Places re-Agreed — design packet for #520

**Status: ruled 2026-10-29 (R1–R4 as recommended) and built on `design/520-places-reagreed`.** Identity rule 3 (`docs/game-identity.md`) names
three sources of Soul: promises kept, companion quests resolved well, and **places re-Agreed**.
The first two shipped in PR #522 (+8 per act, owner ruling 2026-10-29). Today nothing in the
game can model the third. This packet proposes the smallest mechanic that fits the surfaces
already built and lists the rulings it needs. Every number here is PROVISIONAL.

## 1. What already exists

| Surface | What it does today | Source |
|---|---|---|
| `LocationDefinition.harmonic_accord` | Authored base accord for each location (Dom 95, Wilds 85, Dorthkor Road 70, Hollowmere 55). | `world/locations/*.tres` |
| `thinning_tier` | Subtracts 5 accord per tier, applied once. | `SkillCheck.location_fizzle_integrity()` |
| `AccordZone` | A placeable data volume with `accord_delta`. The owner ruled on 2026-09-08 and 2026-10-11 that Hush/Waning zones *are* AccordZones. | `actors/accord_zone/`, `docs/harmonic-accord.md` |
| `FieldMap.zone_delta(cell)` | Sums the deltas of every zone that covers a cell. This value feeds fizzle and `loom_penalty`. | `world/field_map.gd:239` |
| `act_of_agreement` outcome tag | Pays `soul_delta` through `GameState.set_soul_meter`, which respects the husk ceiling. | `globals/quest_registry.gd:694` |

No shipped scene places an `AccordZone` yet; only tests and the Weftlumin fixture do. Canon
already speaks of a place's Agreement as something you can measure. Hollowmere's reading
"sits lower than any instrument near Dom", and Mender Corrin Vell is posted there to file it
(vault `characters/hollowmere-mender.md`). Canon does **not** yet say how a reading is raised
again. That gap is ruling R4.

## 2. Proposal

**A place's Agreement state is an AccordZone's thinning, and re-Agreeing it lifts that thinning
for good.**

1. `AccordZone` gains one optional export, `agreement_id: StringName`. A zone that has one can
   be re-Agreed. A zone without one stays plain authored data, unchanged.
2. Re-Agreement is one saved flag, `agreement.<id>`, held in `GameState` flags. Flags already
   serialize, so the save format does not change.
3. `FieldMap.zone_delta()` skips the negative delta of any zone whose flag is set, so a restored
   zone contributes 0. Fizzle odds, Loom penalties and the Weftlumin accord overlay all read
   that one function, so all of them follow without further changes.
4. The act is a **quest outcome**: a new outcome field, `restores_agreement: PackedStringArray`,
   lists the ids that outcome restores. The existing `act_of_agreement` tag pays the Soul.
   Quests already carry the reward summary, autosave and tests, so this reuses that plumbing.
5. Weftlumin: the placeable kind exposes `agreement_id`, and the bake lint warns when an id is
   duplicated or when no quest outcome restores it (a dead re-Agreement).

What the player sees: the quest resolves and the reward summary shows "Act of Agreement +8
Soul". After that, casting in that corner of the map fizzles less, and Loom-sensitive skills
stop paying the Hush penalty. The world is visibly less hostile where they mended it.

### Why not the alternatives

- **Raise the whole location's `harmonic_accord`.** Too coarse. Hollowmere is a single location, so
  mending one shrine would heal the entire mere, and the thinning gradient toward the front
  would stop reading.
- **A new field verb ("mend" an anchor with a skill check).** This is a new interactable kind
  with its own UI and tuning, and it is in scope for #284. It can be layered on later: the verb
  would just set the same flag.
- **A narrative flag with no accord effect.** That makes the act something the player only
  reads about, never something they feel. Rule 3 treats the place as the thing restored.

## 3. Soul budget

Chapter 1 pays +8 for each of 10 acts today: 4 Dom side-quest outcomes and 6 companion quests.
Rule 3 also says *the meter trends down across a chapter*. Each re-Agreeable place adds one more
+8. With one or two places, the most Soul a player can recover stays below 100, and every act
still requires a choice the player could have refused. Balance owns the final number.

## 4. Rulings needed

| # | Question | Recommended |
|---|---|---|
| R1 | Is a place's Agreement state an `AccordZone` with an `agreement_id`? | Yes (§2) |
| R2 | What act re-Agrees it? | A quest outcome (`restores_agreement`), with a field verb possible later |
| R3 | How much is restored, and how much Soul? | The full negative delta lifts, permanently; +8 Soul, the same as the other acts |
| R4 | Which Chapter 1 place, if any? | Ship the mechanic plus a test fixture now. You name the place and quest later (canon) |

**Owner rulings, 2026-10-29:** R1 AccordZone + `agreement_id`; R2 a quest outcome; R3 the full
negative delta lifts permanently, +8 Soul; R4 mechanic only, with the place and act to be named later.

R4 is the owner's alone. Choosing which place in Hollowmere or on the Dorthkor Road is re-Agreeable,
and what the act is in-world, is new canon that this packet does not invent.

## 5. Build estimate once ruled

About half a day: the export and flag, the `zone_delta` skip, the outcome field and its
resolution, the lint rule, and tests. The tests cover the restored delta, fizzle before and after,
the husk ceiling, save round-trip and the dead-id lint.
