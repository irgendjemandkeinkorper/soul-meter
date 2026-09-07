# The thinning gradient — Harmonic Accord per location (C21, #258)

**Status: PROPOSAL. No `.tres` was edited by this document.** #258 puts the
`world/locations/*.tres` edit behind owner review, so the authored values are recorded
here as a table plus the exact one-line changes. Everything numeric below is measured
output from `tools/casting_economy_sweep.gd`, not a transcription.

Source: PRD FR-506 and the design doc's thinning zones — fizzle rises toward the front, and
*"in the Hush only Notes are honest."*

## 1. How a location's accord is actually computed today

`Battle._agreement_integrity()` (`globals/battle.gd:389`) stacks **two** authored channels:

```
effective_accord = EncounterCatalog.agreement_integrity(
    encounter_id,
    location.harmonic_accord - 5.0 * location.thinning_tier
)
```

- `LocationDefinition.harmonic_accord` — the location's own accord. Currently **100.0
  everywhere**, the un-authored default.
- `LocationDefinition.thinning_tier` — 0–3, **already authored** (Dom 0, Wilds 1, Dorthkor
  Road 2, Wound Lip 3), converted at `SkillCheck.THINNING_INTEGRITY_PENALTY_PER_TIER = 5.0`.
- An encounter may override the result locally (`EncounterCatalog.agreement_integrity`).

So the gradient in the build today runs **100 → 95 → 90 → 85**, a 15-point spread across the
whole map. Section 3 shows that spread is far too shallow to produce the behaviour FR-506
describes.

`globals/battle.gd:398` already anticipates this document: *"FR-506's already-authored
thinning tiers remain the location value source until C21 replaces the neutral accord
defaults with direct authored values."*

## 2. Measured behaviour — what accord actually buys

`godot --headless --path . --quit-after 200 --script res://tools/casting_economy_sweep.gd`,
which calls the ratified `SkillCheck.fizzle_percent()` rather than re-implementing it. Fizzle
percent, so **lower is better**; 95 is the table's cap.

| accord | tone·note | tone·phrase | tone·song | tone·refrain | chord·song | triad·song | triad·refrain |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 95 | 3 | 5 | 9 | 14 | 17 | 30 | **47** |
| 80 | 10 | 20 | 35 | 55 | 44 | 56 | **88** |
| 60 | 20 | 40 | 70 | 95 | 79 | 91 | **95** |
| 40 | 30 | 60 | 95 | 95 | 95 | 95 | **95** |

Three readings drive the proposal:

1. **Tone·Note stays castable everywhere.** Worst case in the whole sweep is 30% fizzle at
   accord 40 — a 70% land rate. The Note never stops being honest, which is the FR-506 line.
2. **Triad·Refrain is already a wager at accord 95** (47%) and is unusable at 80 (88%).
   The Refrain does not need the front to become a gamble; it is one from Dom onward.
3. **The Song tier is where the axis actually bites.** Tone·Song goes 9 → 35 → 70 → 95 across
   the four rows. That is the curve the gradient should be shaped around, because it is the
   one a player feels changing as they walk toward the Wound.

## 3. Proposed values

Chosen so that **effective accord lands exactly on a swept row** — every number a player
meets is measured, none is interpolated. `thinning_tier` is left exactly as authored; only
`harmonic_accord` is added.

| Location | tier (authored) | `harmonic_accord` (proposed) | effective | what it means at the table |
|---|---:|---:|---:|---|
| Dom | 0 | **95** | 95 | Hub. Song is reliable, Refrain is a real wager (47%). |
| Wilds / Loamroot | 1 | **85** | 80 | First field zone. Song is a coin-flip at Triad; Refrain is gone (88%). |
| Dorthkor Road | 2 | **70** | 60 | Past the midpoint. Only Note and Phrase are honest; every Song ≥ 70%. |
| Wound Lip | 3 | **55** | 40 | The Hush. Every Song and Refrain sits at the 95 cap. **Only Notes are honest.** |

The remaining eight macro locations do not exist yet (`world/locations/` holds four plus
interiors), so this table cannot cover twelve. The **rule** covers them:
**derivation**: `harmonic_accord = swept_effective[tier] + 5 × tier`, where `swept_effective`
is `tools/casting_economy_sweep.gd`'s `INTEGRITIES` — `[95, 80, 60, 40]` — and `5` is
`SkillCheck.THINNING_INTEGRITY_PENALTY_PER_TIER`.

> **Correction, 2026-09-07.** An earlier revision of this section stated the rule as
> `harmonic_accord = 95 − 15 × thinning_tier`. That is wrong: it yields 95/80/65/50 and does
> not reproduce this table's own 95/85/70/55. There is no clean linear rule, and that is the
> point — the swept rows `[95, 80, 60, 40]` are sample points the tool measured, not a series.
> The authored value is whatever puts a location's *effective* accord on one of them.
A new location authors its tier from where it sits on the wilds→front axis and takes its
accord from the rule; a location that deviates from the rule should say why in its own note.

Interiors inherit their hub's accord — none of them is on the axis.

### The exact edits, for when this is approved

```
# world/locations/dom.tres           harmonic_accord = 95.0
# world/locations/wilds.tres         harmonic_accord = 85.0
# world/locations/dorthkor_road.tres harmonic_accord = 70.0
# world/locations/wound_lip.tres     harmonic_accord = 55.0
```

### RATIFIED 2026-09-07 — applied, option (B)

The owner ratified the table above and chose **(B)**: `harmonic_accord` is a base and the
`thinning_tier` penalty still stacks on top. The values are authored in
`world/locations/*.tres`, and Dom's twenty-one interiors carry Dom's 95.0 so an interior can
never cast more reliably than the street outside it. `test/unit/test_location_registry.gd`
pins all three properties: the literal values, the derivation above, and that every effective
accord still lands on a row `tools/casting_economy_sweep.gd` measured.

No code changed. §4 below records the decision that was open until this ratification.

## 4. The decision this proposal did not make (RESOLVED: B)

Once accord is authored, **`harmonic_accord` and `thinning_tier` both apply**, and the tier
penalty was written as a stand-in for the accord that did not exist yet. Two readings:

- **(B), what this table assumes:** accord is a *base* and the tier penalty still applies.
  No code change; both channels stay meaningful — the tier is the map's shape, accord is the
  location's own character, and an encounter can still override locally. The authored numbers
  above are chosen to land on swept rows *after* the penalty.
- **(A), the alternative:** accord becomes the *final* value and `Battle._agreement_integrity()`
  stops applying the tier penalty for any location carrying a non-default accord. Easier to
  read off the resource, but it is a behaviour change to a live formula and outside C21's
  allowed scope.

If (A) is chosen the authored values become 95 / 80 / 60 / 40 directly, and
`globals/battle.gd:398`'s comment plus `SkillCheck.location_fizzle_integrity()` need
revisiting together. Not doing that here.

`THINNING_INTEGRITY_PENALTY_PER_TIER = 5.0` remains PROVISIONAL either way.

## 5. Reproducing the evidence

```
godot --headless --path . --quit-after 200 --script res://tools/casting_economy_sweep.gd
```

The tool prints a CSV grid of `integrity,breadth,magnitude,fizzle_percent` followed by the
PROVISIONAL Breath simulation. Judge the printed report, never the exit code — this
project's headless scripts abort at teardown a fair fraction of the time.

Note for anyone running it on an older checkout: the sweep would not compile at all until
`globals/skill_check.gd` stopped naming the `Renown` autoload directly. Autoload identifiers
do not exist in a `--script` run, and because the tool preloads `skill_check.gd`, one bare
reference took the whole file — and therefore the whole tool — out of service.
