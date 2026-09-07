# Harmonic Accord — background variation and the saturation lint

**Status:** design note for #328 (E1.7). The *shape* below is proposed and implemented in
`globals/combat/accord_math.gd`; **every number is PROVISIONAL** and belongs to balance, not to
this note. Nothing here is wired into combat — that is E6.1 (#349).

Harmonic Accord is Agreement Integrity renamed (#329, owner ruling 1). It is the world's
willingness to let a casting hold. High accord means magic behaves; low accord means it fizzles.

---

## 1. Where variation sits

The architecture note (§4.11) composes effective accord at a cell as:

```
accord_at(cell) = clamp(
      location_fizzle_integrity(base, scene)   # authored accord, thinning applied ONCE
    + zone_delta(cell)                         # AccordZone sum, v2 (#349)
    + variation(day, phase, zhavar, weather)   # this note
  , 0, 100)
```

This note owns only the third term. Two boundaries matter:

- **Thinning is subtracted once**, inside `SkillCheck.location_fizzle_integrity()`. `variation`
  never re-applies `thinning_tier`. The Zhavar rung it *does* read is a different quantity — a
  zone's current alarm state, not its distance from the Wound.
- **`fizzle_percent()` keeps its parameter name.** #329 renamed the quantity and the context key,
  not the ratified formula's surface.

## 2. The function

`AccordMath.variation(world_seed, day_index, phase_index, zhavar_rung_index, wheel_distance)`
returns a float in **[−10, +10]**, from three named terms that stay separately inspectable. A
single opaque number cannot be argued with: when a location plays badly the owner needs to see
whether it was the day, the front, or the weather. `variation_breakdown()` returns all three.

| Term | Range | Depends on | Reading |
|---|---|---|---|
| `drift` | ±4.0 | `world_seed`, `day_index`, `phase` | The day's own condition. Neither good nor bad on average. |
| `zhavar` | −4.0 … 0 | zone's Zhavar rung (5 rungs) | The front's pull. **Never positive.** |
| `sympathy` | ±2.0 | wheel distance, weather vs patron element | Weather that agrees with a place helps; weather across the wheel hurts. |

Natural range is **[−10, +6]** — the world can hurt you more than it can help you, which is the
point. The ±10 clamp is a safety net, not a routine occurrence; `variation_breakdown()` reports
`clamped` when it binds.

### Determinism

`drift` is a small integer hash of `(world_seed, day_index, phase)`, **not** a seeded
`RandomNumberGenerator`. A generator carries position between calls, and this must depend on
nothing but its arguments.

That matters because of the sampling instant. `Battle.forecast_context()` freezes
`(day_index, phase, weather, cell)` when a forecast is built, and resolution reuses that exact
context — so **forecast == resolution holds by construction** even if a phase or weather tick
lands between the two. Freezing a context is only worth doing if the function reading it cannot
drift.

### Canon is not duplicated

The wheel order lives in `data/generated/element_matrix.json`, the phases in `WorldClock`, the
rungs in `SaveGame`. `variation()` takes indices; `variation_for()` takes those lists as
parameters. An unknown id resolves to neutral rather than throwing — a missing weather element
must not be able to stop a battle.

---

## 3. Sanity sweep against the ratified fizzle formula

Measured against the real `SkillCheckService`, not quoted from the doc. Each cell is the change
in **fizzle %** produced by a 10-point accord difference (Tone breadth, no strain, Pitch 2, no
mastery). These are pinned by `test/unit/test_accord_math.gd`.

| Accord band | Note | Phrase | Song | Refrain |
|---|---|---|---|---|
| 100 → 90 | 5 | 10 | 17 | **27** |
| 70 → 60 | 5 | 10 | 18 | 13 |
| 40 → 30 | 5 | 10 | **0** | **0** |
| 10 → 0 | 5 | 5 | **0** | **0** |

Two findings come out of this, and both are the reason ±10 is provisional rather than settled.

### 3.1 ±10 is a big number at high magnitude

`magnitude_mult` multiplies the whole base, so the same background weather is a rounding error on
a Note (5 points) and a swing on a Refrain (**27 points**) — more than a quarter of the entire
fizzle range, from weather the player did nothing to cause. Either ±10 is too wide, or `drift`
should be scaled down relative to the deliberate terms. **Balance's call, not this note's.**

### 3.2 The fizzle cap makes accord inert exactly where it should matter most

`fizzle_percent` clamps at 95. In a thinned zone a Song or Refrain is *already* pinned there, so
±10 of variation changes **nothing at all** — see the `40 → 30` and `10 → 0` rows. The effect is
easy to miss in play because small castings still respond normally.

So the background world stops mattering for big castings precisely in the broken places near the
Wound, which is where "the world is hostile to magic here" ought to read loudest. This is
recorded rather than fixed: fixing it means moving the ratified 95 cap, which is not #328's to
move. **E6.1 (#349) should decide whether it is acceptable.** The behaviour is pinned by a test,
so it cannot change silently while the question is open.

---

## 4. Saturation lint

`AccordMath.saturation_warnings(base_adjusted, min_zone_delta, max_zone_delta, location_id)`
warns when:

```
base_adjusted + max_zone_delta + 10 > 100     ->  saturates high
base_adjusted + min_zone_delta - 10 <  0      ->  saturates low
```

A clamp here is not a safety net, it is a silencer. Once a location sits where +10 of good
weather cannot move it, the authored accord and its zone deltas stop meaning anything and the
place plays identically every day of the year. The author hears about it at bake time instead of
wondering why their zone does nothing.

Both warnings can fire at once, which only happens when the authored band is impossible.

---

## 5. What this note deliberately does not decide

- **Where accord is sampled in combat** — E6.1 (#349). Today `CombatController` holds one float
  per battle; per-cell sampling is a combat change that follows #281.
- **`AccordZone` shape** — a placeable volume versus Terrain custom data is architecture ruling 8,
  still open.
- **Authored per-location values** — C21 / #258.
- **Every number above.** They are provisional and marked so in code.
