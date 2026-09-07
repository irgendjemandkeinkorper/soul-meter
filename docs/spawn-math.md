# Spawn math — weights, packs, cadence and caps

**Status:** design note for #327 (E1.6). The *shape* below is proposed and implemented in
`globals/world/spawn_math.gd`; **every number is PROVISIONAL** and belongs to balance, not to this
note. Nothing is wired to the runtime — `SpawnDirector` is E4.1 (#345), the panel and the
validator are E4.2 (#346). Frozen before E4 starts, per #311.

Spawn tables are how Weftlumin replicates random encounters on a persistent map: a slot at a
marker, a weighted table with an `empty` sentinel, a pack size, and a respawn cadence in days.
The schema and the runtime loop are `docs/architecture-in-game-editor.md` §4.10. This note owns
the numbers inside it.

---

## 1. RNG discipline comes first

§4.10 reproduces a slot roll by seeding one generator from
`hash([world_seed, table_id, slot_id, day_index])`. That only reproduces if the helpers consume a
**fixed, documented** number of draws, so:

| Call | Draws |
|---|---|
| `pick(entries, rng)` | exactly 1, or **0** when the table holds nothing pickable |
| `pack_size(range, rng)` | exactly 1, or **0** when `min == max` |

Both are asserted by tests rather than left as a convention. A helper that quietly took two draws
would still be deterministic on its own and would still pass every distribution test, while
silently desynchronising every slot rolled after it in the same scene.

The same property is why an unusable table returns `{empty: true, index: -1}` instead of raising.
A table that slipped past validation must not be able to stop a scene loading, and must not shift
the stream the rest of the scene depends on.

---

## 2. Weights and the `empty` sentinel

Weights are relative positive integers; `normalized()` drops anything non-positive and attaches
each entry's `share` of the total. `empty_share()` is the chance a slot rolls "nothing here
today" — the single most legible number in a table, and the one the panel should show largest.

§4.10's example table, `40 / 40 / 20`:

| Entry | Weight | Share |
|---|---|---|
| `bog-wight` | 40 | 40.0% |
| `loam-boar` | 40 | 40.0% |
| `empty` | 20 | 20.0% |

## 3. Thinning: a share of the table, not a flat step

`scaled_weights(entries, thinning_tier)` pushes weight toward the dangerous end using the danger
ranks `EncounterDirector` already keeps — the same table, read rather than copied, because
`SpawnDirector` and `EncounterDirector` stay separate systems that read the same archetype ids
and a second ranking would be a second thing to drift.

The **step is a share of the table's own authored total** (`0.10` per rank per tier), not the flat
`+1` the travel director adds. That is a deliberate departure, and the reason is measurable:

| Tier | Flat `+1` step (travel director's) | Share step (this note's) |
|---|---|---|
| 0 | bog-wight 40.0%, empty 20.0% | bog-wight 40.0%, empty 20.0% |
| 1 | 40.6% / 19.8% | 45.5% / 18.2% |
| 2 | 41.2% / 19.6% | 50.0% / 16.7% |
| 3 | **41.7% / 19.4%** | **53.8% / 15.4%** |

Travel tables are authored with weights in the single digits, where `+1` is a real shift. Spawn
tables — §4.10's own example included — use weights around 40, where the same `+1` moves the mix
by **1.7 points across the entire thinning range**. That is invisible in play. One absolute
constant cannot serve both scales; a share serves both, and the tests pin that a `4/4/2` table and
a `40/40/20` table land on identical shares at the same tier.

Two properties are kept from the travel director and asserted:

- **Additive only.** Thinning can raise an entry, never suppress one the author placed.
- **Tier 0 returns the authored weights exactly.** This is what makes the coupling owner-tunable
  rather than baked in: set the constant to zero and thinning stops existing.

**A consequence worth naming:** the `empty` sentinel carries no archetype, so it has no rank and
never gains weight. A thinned map is therefore not only more dangerous but also *less often
quiet* — 20.0% empty at tier 0 down to 15.4% at tier 3. That falls out of the shape rather than
being tuned in, and it is the right reading of ground nearer the Wound, so it stays.

## 4. Pack size leans small

`pack_size()` weights size `k` by `max - k + 1`, so the smallest size is the most likely and the
largest the rarest, with the gap widening as the authored range widens.

| Range | Mean under this curve | Mean if uniform |
|---|---|---|
| 1–2 | 1.33 | 1.50 |
| 1–3 | 1.67 | 2.00 |
| 2–5 | 3.00 | 3.50 |

Uniform was the obvious first choice and is wrong for a persistent map. A uniform `1..3` slot
rolls a three-pack a third of the time; a map of eight such slots then reads as a swarm on every
visit, which is a travel-encounter feeling, not a wildlife one. Leaning small keeps the authored
maximum as the thing you occasionally walk into rather than the thing you expect.

## 5. Cadence saturates — so the Zhavar ladder lands on the cap

`respawn_days(authored, rung)` shaves one day per Zhavar rung above the calmest, floored at one.
With the `limited` minimum of three days:

| Rung | `low` | `rising` | `tolling` | `ringing` | `unprecedented` |
|---|---|---|---|---|---|
| Days | 3 | 2 | **1** | **1** | **1** |

**The top three rungs of a five-rung ladder are the same instruction.** This is a limitation, not
a bug, and no arrangement of this function fixes it: cadence is counted in whole days, authored
cadences are small by policy, and days simply cannot express five rungs at that scale.

So the ladder's visible outlet is the **cap**, not the clock. `max_alive_for()` adds
`+2 living members per rung` on `wilderness` maps:

| Rung | `low` | `rising` | `tolling` | `ringing` | `unprecedented` |
|---|---|---|---|---|---|
| `max_alive` | 12 | 14 | 16 | 18 | 20 |

The front shows up as **more things at once**, which the player can see, rather than as **things
sooner**, which they cannot — they were not there to watch the map refill. `respawn_days()` stays
as the secondary term. The saturation is pinned by a test so it stays a known limitation rather
than becoming a surprise.

Only `wilderness` grows. `limited` is settled ground by definition and letting the front raise its
ceiling would quietly turn it into wilderness, at which point the policy stops meaning anything.
`none` stays at zero at every rung: nothing about the front opens a town to spawns. An unknown
policy string gets `none`'s answer, so a typo in a location document fails closed.

## 6. `max_alive` defaults and what they imply

| Policy | Default | Meaning |
|---|---|---|
| `none` | 0 | Towns and important quest areas. The `spawn_tables` kind refuses any table targeting the scene. |
| `limited` | 4 | Minor respawns in otherwise settled areas. The default for a new location until authored. |
| `wilderness` | 12 | Full tables. Dom is `none`; `test_room` / the Wilds is `wilderness`. |

At §4.10's example density (1.33 living members per slot per eligible visit), the wilderness cap
needs **nine slots** before it starts binding. That is the intent: `max_alive` is a backstop
against a dense map and against the #282 mob budget, not a limit an ordinarily-authored map runs
into. A slot blocked by the cap keeps `cleared_day == null` and stays eligible next visit, so the
cap defers spawns rather than cancelling them.

## 7. The `limited` bounds §4.10 left to this issue

Kept at the spec's provisional values, because the sweep says they land where "minor respawns in
otherwise settled areas" should land:

| Bound | Value |
|---|---|
| Slots per table | ≤ 2 |
| `respawn_days` | ≥ 3 |
| `pack_size.max` | ≤ 2 |
| `empty` share | ≥ 50% |

Together those give **≈1.33 living members per eligible visit across the whole location**,
refreshing at most every third day. That is close to `none`, which is the point — a `limited`
location should read as a settled place where something occasionally wanders in, not as a quiet
wilderness. If it ever reads as *nothing at all*, the bound to move first is the empty share.

`policy_violations()` returns messages rather than a bool, naming which bound was crossed and by
how much, so the author is told what to change instead of that something is wrong.

---

## 8. What this note deliberately does not decide

- **Runtime integration** — E4.1 (#345): slot state, rehydrate-then-roll, `Hostile` instantiation,
  the `spawn_state` save surface.
- **Save layout** — the additive `spawn_state` key and any schema bump ride with #283.
- **Panel and validator** — E4.2 (#346), which calls `policy_violations()`.
- **Per-location authored values** — Wave C.
- **Every number above.** They are provisional and marked so in code.
