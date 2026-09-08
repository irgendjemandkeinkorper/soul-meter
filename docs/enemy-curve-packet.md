# Enemy curves and per-instance variation — owner review packet

**Issue:** #412. **Status:** analysis DONE, four rulings OPEN, implementation BLOCKED on #345.
**Sweep:** `tools/enemy_curve_sweep.gd` — every number below is printed by it; re-run it rather
than trusting this file.

Owner ruling of record, 2026-09-07: enemy DRAMGID attributes must drive `max_hp` / `attack` /
`defense`, so that two instances of the same archetype met in the wild differ. Verbatim:
*"I don't want it to be a 'solved' kinda question."*

This packet does the half of #412 that #345 does not block: it fits the curves, prices the
variation bands, and answers the four open questions with recommendations instead of asking
them cold. **No constant is changed by this PR.**

---

## 1. Why the party's curve cannot be reused

`DramgidDerived` spans the party's point-buy range (grit 2–5) and gives `12 + 6×grit`. Enemies
run wider and lower — the loam-maddened boar sits at **grit 1**, below `ATTRIBUTE_FLOOR`, where
no party member can be. Applying the party curve there gives 18 HP against an authored 14
(**+28.6%**), and every encounter in the game gets rebalanced as a side effect.

Enemies need their own curve. Fitting one is what §2 does.

## 2. The proposed curves

Fitted against the six shipped archetypes by minimising **worst-case percent drift**, not
absolute drift. That choice matters: an absolute-error fit picks the curve that is kindest to
the biggest enemy, and a 3 HP miss on the 14 HP boar is a different kind of wrong than the same
miss on the 36 HP guard.

```
max_hp  = round(2 + 6.0 × grit + 2.0 × muster)
attack  = round(1 + 1.5 × muster)
defense = max(round(-2.5 + 1.25 × grit), 0)
```

| archetype | grit | mus | hp → derived | drift | atk → derived | def → derived |
|---|---|---|---|---|---|---|
| bog-wight | 2 | 2 | 20 → **18** | −10.0% | 4 → 4 | 1 → **0** |
| cleaned-jawbrace-guard | 5 | 3 | 36 → **38** | +5.6% | 7 → 6 | 4 → 4 |
| gnaal-breach-hound | 3 | 4 | 28 → 28 | 0.0% | 7 → 7 | 1 → 1 |
| gnaal-rift-scavenger | 2 | 2 | 16 → **18** | +12.5% | 5 → 4 | 0 → 0 |
| loam-maddened-boar | 1 | 3 | 14 → 14 | 0.0% | 6 → 6 | 0 → 0 |
| mustered-bloodbellow | 4 | 3 | 32 → 32 | 0.0% | 6 → 6 | 3 → 3 |

**Worst-case HP drift 12.5%; 3 of 6 exact.** Attack is 4 of 6 exact, both misses 1 point.
Defense is 5 of 6 exact, the one miss 1 point.

### Two things in that table worth a ruling rather than a nod

**`max_hp` needs a second term.** No single-driver curve fits. The bog-wight and the
rift-scavenger share grit 2 and are authored 4 HP apart, so grit alone cannot tell them apart at
any base or slope; the best grit-only fit leaves someone 14.3% out. Adding muster separates them
and brings worst-case to 12.5%. Reading: HP is toughness *plus* mass, which is also how the two
enemies differ in the fiction — one is grave-rotted and slow, the other is fast and thin.

**Enemy `defense` rides GRIT; the party's rides ALACRITY.** That is not a fitting artifact — the
authored data says so clearly (5 of 6 exact on grit, best alacrity fit is 1 of 6). It is a real
divergence between how a player character avoids damage and how a monster absorbs it, and it is
defensible, but it is a design claim and should be ruled on rather than absorbed.

## 3. What the variation bands actually feel like

The band is applied to the derived value, rolled once at spawn, frozen. From the sweep — band
bounds, with the range actually observed over 512 seeds beside them (they converge exactly, so
the bounds below are reachable, not theoretical):

| archetype | derived | ±10% | ±15% |
|---|---|---|---|
| bog-wight | 18 | 16–20 | 15–21 |
| cleaned-jawbrace-guard | 38 | 34–42 | 32–44 |
| gnaal-breach-hound | 28 | 25–31 | 24–32 |
| gnaal-rift-scavenger | 18 | 16–20 | 15–21 |
| loam-maddened-boar | 14 | 13–15 | 12–16 |
| mustered-bloodbellow | 32 | 29–35 | 27–37 |

The honest observation is narrower than it first looks. **Only the boar barely moves at ±10%** —
its 14 HP rounds a 10% band down to ±1, so it rolls 13–15 and a player will not notice. Every
other archetype already spans ±2 or more at ±10%. The case for the wider band is specifically
about the smallest enemies, not about the table as a whole.

A first pass at this section quoted an 8-draw sample and reported the bog-wight as *narrower* at
±15% than at ±10%. That was sampling noise presented as a finding, which is the most expensive
kind of mistake a review packet can carry, and it is why the sweep now draws 512 and prints the
band bounds beside the observed range.

## 4. The four open questions, with recommendations

### Q1 — Band width: ±10%, ±15%, or asymmetric?

**Recommendation: ±15%, symmetric.**

At ±10% the boar — the enemy met most often and killed fastest — rolls 13–15, which is under one
exchange of difference and will read as identical. ±15% takes it to 12–16, one to two exchanges:
felt, not fatal. The larger archetypes are legible at either band, so the choice is decided by
the small ones. Asymmetry (tougher more often than weaker) is tempting and should be declined: it makes the *average* enemy
stronger than the authored table, which silently rebalances every encounter, which is the
outcome #412 §1 exists to prevent. Keep the mean on the authored number and let the spread do
the work.

### Q2 — Does variation touch HP only, or attack and defense too?

**Recommendation: HP only, for Chapter One.**

Attack and defense are small integers (0–7). A ±15% band on `defense = 1` rounds to 1 every
time; on `attack = 6` it is ±1, and because `battle.gd`'s damage rule is `max(1, attack −
defense)`, a single point of attack variation is a **17% swing in damage per hit**, compounded
across every hit of the fight. HP variation is felt as "that one took longer"; attack variation
is felt as "the numbers are random". The ruling asks for the former.

This is reversible: the seam in §5 rolls per-stat, so enabling attack variation later is a
config change, not a redesign.

### Q3 — Visible or silently felt?

**Recommendation: silently felt in Chapter One; leave the adornment hook unbuilt.**

A name adornment ("gaunt", "swollen") turns variation into a **stat the player reads and
optimises around** — they will learn to disengage from "swollen" ones. That is a different
feature with its own balance surface, and it contradicts the ruling's own words: a solved
question is exactly what a legible label creates. Silent variation is what makes the answer stay
unsolved.

Worth noting so it is not lost: the inspect line is where this would go if the owner wants it
later, and it costs nothing now to leave that decision open.

### Q4 — Do named and story enemies vary?

**Recommendation: no. Set-piece encounters stay pinned.**

#412 §4 already argues this and the sweep agrees with it: the five authored `EncounterCatalog`
encounters are tuned against Gate T-1 evidence, and varying them invalidates that tuning for no
narrative gain. The Mustered Bloodbellow is a **named story antagonist** with three authored
outcomes — a player who reloads the Broken Muster should meet the same Bloodbellow.

Variation belongs to the wild spawn path only, which is precisely why the roll lives in the
`SpawnDirector` (#345) and not in `EncounterCatalog`.

## 5. The seam, so the implementation has nothing left to invent

```gdscript
static func varied(base_value: int, band: float, rng_seed: int, salt: int) -> int:
    var rng := RandomNumberGenerator.new()
    rng.seed = rng_seed ^ salt
    return maxi(int(roundf(base_value * (1.0 + rng.randf_range(-band, band)))), 1)
```

Three properties it has to keep, each pinned by an existing gate:

1. **Rolled once at spawn, frozen into the `BattleActor`.** Never re-rolled inside
   `Resolution.resolve()`, never a bare `randi()`. Forecast then reads the same frozen instance
   live resolution does, so *forecast == resolution* stays true by construction — Gate T-7
   (#173).
2. **Salted per spawn slot,** so two wights from the same table on the same world seed differ
   from each other rather than being one wight printed twice.
3. **Persisted in `spawn_state`** (#345's save surface). Either the seed or the frozen numbers
   ride the save, or a reloaded wight is quietly a different wight.

The sweep prints a determinism check for all three.

## 6. Sequencing, and what is still blocked

`(a)` archetype derivation must not land alone — deriving the numbers with no variation on top
re-solves the question the owner wants left open, at the cost of a full rebalance. `(b)` needs
`SpawnDirector` (#345), which is unbuilt.

So the remaining work on #412, in order:

1. **Owner answers Q1–Q4** (this packet). Not blocked by anything.
2. #345 lands.
3. `(a)` + `(b)` land together, with the pin test matching the doc rows to the live constants.
4. **Gate T-1 re-run.** #168's evidence — five archetype encounters cleared by four build
   archetypes — expires the moment enemy hp/attack/defense change. Re-running it is part of
   #412, not a follow-up.

One consequence of §2 worth surfacing before step 3: adopting these curves changes four of the
six shipped archetypes by 1–2 points even before any variation is applied. That is a small
rebalance and it is unavoidable — a derived number that reproduced every authored number exactly
would be a lookup table wearing a formula's clothes.
