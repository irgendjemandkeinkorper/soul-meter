# PRD Amendment 3 — World-State Evolution

**Status:** **RATIFIED 2026-08-07** — owner sign-off. FR-507 is binding.
**Date:** 2026-08-07 · **Author:** Claude · **Owner:** Adam
**Adds:** FR-507 to `docs/prd-chapter-one.md` (RATIFIED 2026-08-03).
**Extends:** FR-308 (the Zhavar). **Depends on:** `docs/prd-amendment-living-world.md` (FR-504a).
**Origin:** owner design direction, 2026-08-07.
**Language rule:** ASD-STE100. Game narrative content is excluded.

---

## 0. What this is

The owner asked for a mechanism that changes places the player is not standing in. Regions
decay or are attacked while the player is elsewhere. Quests become unavailable. A demon knight
left unhunted in Act I kills a named townsperson in Act II.

**This amendment does not add a new system. It generalizes one that is already ratified.**

FR-308 already defines a per-zone escalation meter, the Zhavar, with a five-step ladder:

> low → rising → tolling (one Zhem dragon) → ringing (regional delegation) → unprecedented

FR-507 keeps that ladder and adds three things it does not have: a **score** that drives it, an
**evaluation moment** when the score is read, and a **record** that a later chapter can read.

### 0.1 What was corrected on the way in

Three parts of the original direction did not survive contact with the repository. Each is
recorded here rather than quietly dropped.

| Proposed | Correction |
|---|---|
| Tweede tends undead | Tweede's vault-stated external threat is **Wintervast** — political, not undead. Tweede is also not in Chapter One. The region is Dom, Dorthkor Road, Wilds, Wound Lip |
| Fallout 2 evaluated the world at milestones | Fallout 2's town evaluation was mostly the **ending slides**, read once at the end. Fallout **1** had the mid-game clock, and that clock is the most complained-about part of that game. The milestone model here is closer to Witcher 2's act transitions |
| A weighted formula produces a chance | The formula is kept, and its output is a **threshold**, not a roll. §2.2 gives the three reasons |

### 0.2 The input already exists

The threat axis this amendment weights by is **already authored**, in Coiljaw's Act I fork:

- `IRON-COMPANIES` — *"Dom turns its shield toward the Breach."* Demons.
- `IRONBRAND-SENTINELS` — *"Dom turns inward toward the Wound."* Undead.
- `EQUILIBRIUM` — both fronts, gated on a centred Soul Meter.

The evaluator does not need a new player input. It reads a decision the player already makes,
which is why this is cheaper than it appears.

---

## 1. FR-507 (P1) — World-state evolution

1. A **world-state score** is computed per zone from quest progress, karma, elapsed time and
   zone threat affinity. §2.1.
2. The score is **deterministic**. Identical inputs always produce identical world state. §2.2.
3. The score is read at **evaluation moments**, not continuously. §3.
4. Crossing a threshold selects an **authored** world state. Nothing is generated. §2.3.
5. World state can make a quest **unavailable**, and can change first interactions in a hub.
6. An **end-of-act snapshot** is written to the save so a later chapter can read it. §4.
7. Chapter One **records**; Chapter Two **reads**. §4.

---

## 2. The score

### 2.1 Shape

```
zone_score(zone) =
      missed_milestones(zone)  * QUEST_WEIGHT
    + karma_debt()             * KARMA_WEIGHT
    + elapsed_phases()         * TIME_WEIGHT      # capped, see 2.4
    + threat_affinity(zone)    * GEO_WEIGHT
```

This is the owner's formula, unchanged in shape. Each term is defined:

- **`missed_milestones(zone)`** — authored obligations the player passed by. The demon knight
  not hunted. The bell house not repaired. Counted, not judged.
- **`karma_debt()`** — derived from the existing ledgers. **No new ledger.** `Renown` infamy and
  `Reputation` standing already answer this. §5.1.
- **`elapsed_phases()`** — clock phases since the zone was last visited. Capped. §2.4.
- **`threat_affinity(zone)`** — how exposed a zone is to a given threat family. Vault-derived.
  §2.5.

**Every weight is PROVISIONAL until a simulation sweep passes.** The tactical amendment §1.1
records what happens otherwise: ratified numbers failed their own sweep and had to be re-opened.
Do not ratify magnitudes in this document.

### 2.2 Deterministic, not random

The score crosses authored thresholds. It does not feed a dice roll.

```
if score >= zone.threshold.raided:      state = "raided"
elif score >= zone.threshold.strained:  state = "strained"
else:                                   state = "steady"
```

Three reasons, in order of weight:

1. **A roll dilutes the signal this game is built on.** The core loop is *my choice caused
   that*. If a town falls because a die came up, the player cannot tell that outcome apart from
   one they caused, and the loop stops teaching.
2. **A roll saves no authoring.** "The town was raided" is not a procedural state. Someone
   writes the dialogue, the missing NPCs, the scene dressing. Randomness does not generate
   content; it only makes an authored branch fire unpredictably.
3. **A roll breaks a ratified requirement.** Gate T criterion 7 requires identical results from
   identical inputs. FR-901 requires all of this to round-trip through `SaveGame`. A random
   world drift is unreproducible by construction, so a bug in it cannot be filed.

**The player keeps the surprise.** The player does not see the weights. What is removed is
unpredictability *in the same save*, which nobody experiences as drama and everybody experiences
as a bug report that cannot be reproduced.

### 2.3 A threshold selects authored content, and that is the real budget

Every reachable state is written by a person. The cost of this feature is **not** the evaluator.
It is `zones × states × content`.

**Rule: three states per zone, maximum, in Chapter One.** `steady`, `strained`, `raided`. A
fourth state is an amendment, not a judgement call in a content wave.

**DECIDED 2026-08-07 — the Zhavar IS the zone state. There is no second meter.**

FR-308's ladder and the three zone states are the same thing, seen from two ends. Chapter One
reaches the first three rungs only, which is already what FR-308 says:

| Zhavar rung | Zone state | Chapter |
|---|---|---|
| low | `steady` | One |
| rising | `strained` | One |
| tolling — one Zhem dragon | `raided` | One. This is FR-308's scripted tolling event |
| ringing — regional delegation | — | Two and later |
| unprecedented | — | Two and later |

**Why this and not two meters.** Two meters over one zone's condition is two authorities over
one question, which the tactical amendment §8.1 names as a stop condition. It would also make a
fifth world-state axis on top of the four the tactical amendment §3 already flagged as near the
complexity ceiling.

**Consequences of the decision, which are all simplifications:**

- There is **no mapping table** to write, maintain or test. The rung *is* the state.
- FR-308's telegraphing requirement (§3.1) is satisfied by construction, because `strained`
  **is** the `rising` rung that FR-308 already requires rumors for.
- `zone_score` writes the Zhavar. Nothing else does.
- The Chapter Two rungs need no Chapter One code. They are values the ladder can hold later.

The score therefore selects a rung, and the rung names the authored content.

Chapter One has four zones. Three states each is up to 12 authored zone states, of which
`steady` is what already exists. So the real new authoring is **8 zone states**, and fewer if a
zone cannot reach `raided`.

### 2.4 The time term is capped, and here is why it is small

The owner chose milestones plus a soft time term. The cap is what keeps it soft.

```
elapsed_phases() = min(phases_since_last_visit, TIME_CAP)
```

`TIME_CAP` is set so the time term can never, alone, move a zone between states. Time nudges a
score already close to a threshold. It cannot cross one by itself.

**Why the cap is mandatory.** Without it, a thorough player who clears side content is punished
for the exact behaviour a 15 to 25 hour CRPG is built to reward, and optional content becomes a
trap. That is the Fallout 1 failure, and it is the single most-criticised part of that game.

**This term creates a dependency that did not exist yet.** `elapsed_phases()` needs the world
clock from FR-504a. **FR-507 cannot ship before FR-504a is ratified and built.** If FR-504a is
rejected, `TIME_WEIGHT` is zero and FR-507 still works on milestones alone. That is the intended
fallback and it is not a degraded mode.

### 2.5 Threat affinity is vault lore, and it does not exist yet

`threat_affinity(zone)` needs a table: for each zone, its exposure to each threat family. The
combat archetypes already name the families — demon, undead, mixed.

**The vault does not contain this table.** No city entity carries a threat-family axis today.
Tweede's stated external threat is Wintervast, a political rival.

**Therefore this is new lore, and it is authored in the vault first.** Edit the entities, rerun
`build_index.py` and `validate.py`. It is not invented in a `.gd` file. `CLAUDE.md` is explicit:
the vault wins, and canon questions are not resolved silently.

**This is a blocking prerequisite.** FR-507 cannot be implemented before the table exists.

#### 2.5.1 Measured 2026-08-07 — the prerequisite is larger than stated above

The section above assumed the Chapter One zones exist in the vault and merely lack a threat
axis. They do not. Measured against `world/locations/*.tres`:

| Zone | Vault entity |
|---|---|
| `dom` | `cities/dom.md` |
| `dorthkor_road` | **none** |
| `wilds` | **none** |
| `wound_lip` | **none** |

**Three of the four Chapter One zones have no lore entity at all.** They exist only as game
resources. A threat-affinity table cannot describe places the vault has never described.

**A second gap, found in the same check.** `docs/godot-architecture.md` requires entities to
carry a `Vault Id` property bridging game data to lore prose. **No location resource carries
one.** Even `dom`, which does exist in the vault, is not linked to it from the game side.

**Revised prerequisite, in order:**

1. Author vault entities for `dorthkor_road`, `wilds` and `wound_lip`. This is **new canon about
   the owner's world** and must not be invented by an agent or by this document.
2. Add the threat-family axis to those three plus `dom`.
3. Add the `Vault Id` bridge to all four location resources.
4. Only then author the affinity values as game data.

**Note the split this reveals.** The *lore* — what threatens a place, and why — belongs in the
vault. The *numbers* belong in game data, under the same "Pandora is canonical, nothing writes
back" rule as everything else. §2.5 above was imprecise in calling the whole table vault lore.

---

## 3. Evaluation moments

The score is read at named moments. It is never read on a timer and never read per frame.

1. **Chapter stage boundaries.** `globals/chapter_one_progress.gd` already has a `STAGE_MAP`
   with requirement-gated stages. Those boundaries are the evaluation moments. This is the
   milestone model the owner asked for, and the spine already exists.
2. **A small number of named side-quest beats.** Declared in the quest resource, never implicit.
3. **The end-of-act snapshot.** §4.

**On entering a zone, the zone's state is read, not recomputed.** Evaluation and application are
separate. A zone the player has never left cannot change under them.

### 3.1 The player must be able to see it coming

A consequence the player could not have anticipated reads as arbitrary, not as tragic.

FR-308 already requires telegraphing — rumors, ambient VFX, one scripted tolling event. **FR-507
inherits that requirement.** A zone that moves to `strained` must produce a rumor before it
reaches `raided`. The escalation is legible or it is not shipped.

---

## 4. Chapter One records, Chapter Two reads

Act II consequences are Chapter Two content. The roadmap horizon is Chapter One (D7). This
amendment therefore splits cleanly:

**Chapter One builds:**
- the evaluator, the score, the thresholds;
- the authored zone states for the four Chapter One zones;
- consequences that land **inside** Chapter One, including at least one quest made unavailable;
- the **end-of-act snapshot**, written to the save.

**Chapter Two reads** the snapshot. The demon knight who kills a named townsperson in Act II is
Chapter Two content, authored against a contract that Chapter One proved.

**The precedent is `ng_plus.gd`.** It is data-only, with `default_block()`, `normalize()` and
`apply_to_new_game()`, and the Mirror Shop that consumes it deliberately does not exist yet. The
snapshot follows exactly that shape: written and tested now, consumed later.

**Save impact.** The snapshot is world state under FR-802 and needs a stable schema. It is a
save-schema bump and a migration, not a new field. If FR-504a lands first, both changes should
ride one bump rather than two.

---

## 5. What this does NOT add

### 5.1 No fourth ledger

The project already carries three: `Reputation` (per-faction, append-only), `Renown` (global
reputation and infamy), and `GameState.flags`. The architecture document §3.4 states which
question each answers.

**`karma_debt()` is derived from the existing two ledgers. It is not stored.** A fourth ledger
would create a fourth authority over the same question, and the tactical amendment §8.1 already
names duplicate authority as a stop condition.

### 5.2 No continuous simulation

This amendment does not simulate anything. Between evaluation moments, no zone changes. See
§6 for how that reconciles with FR-504a.

### 5.3 No procedural content

No state is generated. Every state is written.

---

## 6. Reconciling with FR-504a

`docs/prd-amendment-living-world.md` §2.2 currently reads:

> **No simulation while the player is elsewhere.** The routine is a lookup, not a running agent.

**That clause was aimed at live agent simulation** — NPCs that path, have needs, and react to
each other while the player is away. FR-507 is not that. It is a **discrete evaluation at named
moments**, and between those moments nothing runs.

The two are compatible once stated precisely. FR-504a §2.2 is amended by this document to read
"no *continuous* simulation", with FR-507 named as the explicit exception. That change is made
in the same pull request as this document, so the two never disagree in `main`.

**The dependency runs one way and it is worth restating:** FR-507's time term needs FR-504a's
clock. FR-504a does not need FR-507.

---

## 7. Gate

Every criterion is binary and externally observable. None needs outside humans.

1. The same save, the same choices and the same evaluation moment produce identical world state
   across 3 consecutive runs. Headless.
2. The time term alone cannot move a zone between states, at any value up to `TIME_CAP`. Headless.
3. Every reachable zone state has authored content. No state renders a placeholder.
4. A zone that reaches `raided` produced a telegraph at `strained` first. §3.1.
5. At least one quest is made unavailable by world state, and the player is told why. FR-606's
   refusal taxonomy applies: a quest that vanishes without explanation fails this criterion.
6. **No world state can soft-lock the main quest.** FR-905. This is the criterion most likely to
   fail, because it is the one that quest authoring can break silently.
7. The end-of-act snapshot round-trips through save and load, and a pre-FR-507 save loads with a
   default snapshot.
8. Zone-state count is within the §2.3 cap of three per zone.

---

## 8. Reversibility

- **Thresholds are data.** Setting every threshold beyond reach returns every zone to `steady`,
  which is the pre-FR-507 world.
- **`TIME_WEIGHT = 0`** removes the FR-504a dependency without removing the feature.
- **The snapshot is written even when the evaluator is disabled**, with all zones `steady`, so
  Chapter Two's contract does not depend on the feature staying on.

**Stop-loss.** Stop if authoring the zone states for a single zone exceeds the §2.3 budget by
more than half, or if criterion 6 cannot be satisfied without redesigning a main-quest step.
Either signal means the state count is too high, and the correct response is to cut states, not
to widen the schedule.

---

## 9. Still open — decisions this amendment does NOT make

1. **The threat-affinity table.** New vault lore. §2.5. Blocking.
2. **All weights and thresholds.** Provisional until a sweep passes. §2.1.
3. ~~**Does the Zhavar ladder map onto the three zone states?**~~ **DECIDED 2026-08-07 — the
   Zhavar IS the zone state. One meter, no mapping table.** See §2.3.
4. **Which Chapter One quest becomes unavailable?** Gate criterion 5 requires at least one. The
   choice is content design, made during M7.
5. **Does world state feed NG+ carry-over?** `ng_plus.gd` is the natural place. Not decided here.

---

## 10. Cost

At the roadmap's 28 hours per week.

| Item | Effort (h) |
|---|---|
| Vault threat-affinity lore, plus `build_index.py` and `validate.py` | 6 to 10 |
| Evaluator, score, thresholds, tests | 16 to 24 |
| Evaluation-moment wiring into `ChapterOneProgress` | 6 to 10 |
| End-of-act snapshot, save migration, fixture | 10 to 14 |
| Authoring 8 zone states across 4 zones | 24 to 40 |
| Telegraph content and the unavailable-quest path | 10 to 16 |
| **Total** | **72 to 114** |

**2.6 to 4.1 weeks.** This is **new scope** and it is **not** in the roadmap's 630 to 960 hour
total. Accepting it moves Chapter One to roughly **700 to 1075 hours**, or **25 to 38 weeks**.

The authoring row dominates, and it is the row that grows fastest if the three-state cap slips.

---

## 11. Ratification

**RATIFIED 2026-08-07.** Owner decision: **ACCEPT FR-507 as written**, with the §9.3 open
question resolved in the same sitting: **the Zhavar IS the zone state.** See §2.3.

FR-504a was ratified on the same date, so `TIME_WEIGHT` is live rather than zero.

**Two prerequisites still gate implementation, and ratification does not clear them:**

1. **The threat-affinity table does not exist in the vault.** §2.5. It is authored there first,
   with `build_index.py` and `validate.py` rerun. Until it exists, `threat_affinity()` has no
   data and FR-507 cannot be built.
2. **Every weight and threshold is PROVISIONAL** until a simulation sweep passes. §2.1. The
   tactical amendment §1.1 records what happens when magnitudes are ratified without a sweep.

**Accepted cost.** 72 to 114 hours of new scope. Chapter One moves to approximately 700 to 1075
hours, or 25 to 38 weeks at 28 hours per week. `docs/roadmap-chapter-one.md` is updated to carry
this figure.

---

## Appendix — provenance

- **Origin:** owner design direction, 2026-08-07, and four recorded decisions: deterministic
  threshold; milestones plus a soft capped time term; Chapter One records and Chapter Two reads;
  sharpen FR-504a rather than fold the two amendments together.
- **Measured inputs:** `globals/chapter_one_progress.gd` has a `STAGE_MAP` with requirement-gated
  stages; 4 location resources exist in `world/locations/`; the demon and undead axis is already
  authored in `dialogue/marshal_coiljaw.dialogue` as the Iron Companies, Ironbrand Sentinels and
  Equilibrium fork; `globals/ng_plus.gd` is the data-only precedent for a written-now,
  consumed-later contract; the vault contains 24 city and location entities and **no**
  threat-family axis on any of them.
