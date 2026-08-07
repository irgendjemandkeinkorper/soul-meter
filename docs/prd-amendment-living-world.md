# PRD Amendment 2 — The Living World

**Status:** **DRAFT — proposed, not ratified.** Owner sign-off required before any work starts.
**Date:** 2026-08-07 · **Author:** Claude · **Owner:** Adam
**Amends:** `docs/prd-chapter-one.md` (RATIFIED 2026-08-03) — FR-504, and G9 which cites it.
**Precedent:** `docs/prd-amendment-tactical-layer.md` (RATIFIED 2026-08-05).
**Origin:** session decision D6, `.claude/session-intent.md`.
**Language rule:** ASD-STE100. Game narrative content is excluded.

---

## 0. What this amendment is, and what it admits

FR-504 is ratified. Its text forbids the thing this amendment asks for:

> **FR-504 (P1)** Living-world texture tier 1: **time-of-day-agnostic** NPC state changes keyed
> to quest flags and rep bands (post-quest scene dressing, rumor lines, price shifts). **No full
> NPC schedules in v1.**

G9 repeats the constraint: *"no NPC schedules in v1 — see FR-504"*.

Session decision D6 asks for a world day and night clock, plus hand-authored routines for the
named NPCs in the hubs. **That is a widening of ratified scope.** This document exists so the
widening is recorded, argued and signed, rather than absorbed by silence.

**What this amendment admits.** FR-504 was not an oversight. It was a scope cut, and the cut was
correct at the time. Chapter One has one hub of three and four locations of eight to twelve. A
clock adds a second axis of state to every piece of content authored after it, and content
authored before it does not have that axis. This amendment therefore does **not** argue that
FR-504 was wrong. It argues that the cut can be partly reversed at a bounded, stated cost, and
it fixes the boundary in writing so the reversal cannot creep.

**What this amendment does not do.** It does not restore the full schedule system that FR-504
rejected. See §2.

---

## 1. FR dispositions

Nothing changes by silence. Each affected requirement gets an explicit disposition.

| FR | Ratified text | Disposition |
|---|---|---|
| **FR-504** | Tier 1, time-of-day-agnostic, no full NPC schedules | **AMENDED → FR-504a.** See §2 |
| **G9** | Living-world texture, "no NPC schedules in v1 — see FR-504" | **AMENDED** by reference. The parenthetical now points at FR-504a |
| **FR-308** Zhavar telegraphing | Rumors, ambient VFX, one scripted tolling event | **UNCHANGED.** §4.5 |
| **FR-402** band-gated reactions | Every hub has ≥ 3 band-gated reactions | **UNCHANGED.** §4.5 |
| **FR-506** thinning gradient | Encounter tables and fizzle shift toward the front | **UNCHANGED.** §4.5 |
| **FR-802** stable ID schemas | Actors, quests, skills, items, zones, world facts, dialogue | **EXTENDED.** The clock is world state and needs a stable schema. §3.2 |
| **FR-905** no soft-lock | Failure-forward routes, save policy | **CONSTRAINS this amendment.** §3.4 |
| **FR-906** narrative-coherence QA | Human playtest pass against the world-state matrix | **WIDENED.** The matrix gains a time axis. §5 |

### FR-504a (P1) — Living-world texture tier 1.5

Replaces FR-504. The number is deliberate: this is **not** tier 2.

1. A world clock exists. It advances on defined events, not on wall-clock seconds. See §3.1.
2. The clock serializes into the save and survives a round trip.
3. **10 to 15 named NPCs, in hubs only,** follow hand-authored routines keyed to the clock.
4. **Every other NPC keeps FR-504's original behaviour** — flag-keyed and rep-keyed reactivity,
   time-of-day-agnostic. This is most NPCs. It is not a fallback; it is the design.
5. Dialogue can read the time of day.
6. No NPC pathfinds to a routine. A routine changes where an NPC *is* and what it *says*, on a
   scene load. See §2.2.

---

## 2. The boundary — what "hand-authored routine" means

This section is the load-bearing part of the amendment. FR-504's cut existed because "NPC
schedules" is an unbounded phrase. The amendment is only safe if the phrase is bounded.

### 2.1 In scope

A routine is a **table**: for each named NPC, a position and a state for each clock phase.

```
sella_varn:
  morning   → bell_house      state: working
  afternoon → market          state: buying
  evening   → tavern          state: drinking
  night     → absent          state: home
```

Authoring a routine is filling in that table. Nothing computes it.

### 2.2 Out of scope, and these are the expensive parts FR-504 was right to cut

- **No pathfinding to routine targets.** An NPC does not walk from the bell house to the market.
  It is in one place before the phase change and in the other after it. The player never watches
  a commute.
- **No simulation while the player is elsewhere.** The routine is a lookup, not a running agent.
- **No needs, no schedules that react to each other, no emergent behaviour.**
- **No routines outside hubs.** Wilds and road NPCs are unaffected.
- **No routine for an unnamed NPC.** The cap is 10 to 15, and it is a cap, not a target.

**Why the cap is a number and not a principle.** A principle bends under content pressure. If
routine 16 is worth authoring, that is an amendment, not a judgement call in a wave prompt.

### 2.3 The failure mode this boundary prevents

An NPC that pathfinds a routine must be somewhere real at every moment, which makes it a live
agent, which makes quest triggers, dialogue availability and encounter placement depend on where
that agent happens to be. That is the system FR-504 cut, and cutting it was correct. The lookup
table has none of those consequences, because between phase changes nothing moves.

---

## 3. What the clock costs

### 3.1 The clock advances on events, not on seconds

A real-time clock makes every quest a race the player did not agree to enter, and it makes a
bug reproducible only at the minute it occurred.

**Phases:** morning, afternoon, evening, night. Four, not twenty-four. The routine table has one
column per phase, so the phase count is the authoring cost multiplier.

**Advance triggers,** all explicit:
- Travel between locations through `GameFlow.travel()`.
- Resting, if resting exists.
- A quest step that declares an advance in its resource.

**Never on a timer.** A player who stands still does not lose the day.

### 3.2 The clock is save state, so it is a migration

Save schema is **5** today, with a migration path and a fixture at
`test/fixtures/save_game_schema_5.json`.

Adding the clock takes the schema to **6**. That means a migration and a new fixture, not a new
field. FR-802 requires a stable ID schema for world facts; the clock phase is a world fact.

**A save written before this amendment must load.** A schema 5 save gets the default phase. That
requirement is testable and belongs in the gate. See §5.

### 3.3 The real cost is on content, not on code

The clock itself is small. The cost is that **every hub NPC authored after the clock exists has
four states instead of one**, and every hub NPC authored *before* it has one state that must be
back-filled or explicitly declared phase-agnostic.

There are 11 NPC placements in `world/starting_town.tscn` today. Dom is 1 hub of 3.

Rough authoring cost, at the roadmap's 28 hours per week:

| Item | Effort (h) |
|---|---|
| Clock, save migration, fixture, dialogue accessor | 12 to 18 |
| Routine table format, loader, tests | 10 to 14 |
| Authoring 10 to 15 routines across 3 hubs | 14 to 22 |
| Back-fill or declare existing Dom NPCs | 4 to 8 |
| **Total** | **40 to 62** |

That is **1.4 to 2.2 weeks**, and it matches the M8 estimate in `docs/roadmap-chapter-one.md`
§5.1. This amendment does not change the schedule.

### 3.4 FR-905 constrains the clock

FR-905 forbids a soft-lock. A clock creates a new way to build one: **an NPC who is only
available in one phase, holding a quest step the player needs.**

**Rule.** A quest-critical interaction must be reachable in **at least two phases**, or the NPC
must be reachable at any phase through a stated alternative. The quest audit is the natural
place to check this. That check is **not** in scope for this amendment; it is named here so the
gap is on record.

---

## 4. Why tier 1.5 and not tier 2

The honest argument for the widening, stated so the owner can reject it.

**For.** Witcher 3's living world is a stated reference for this project. A hub that is
identical at every visit reads as a set, not a place. The cheapest large gain in that direction
is that a few named people are somewhere different at night. Four phases and a lookup table buy
most of that effect.

**Against, and this is real.** FR-504's cut bought a simplification that this amendment spends.
Chapter One is 4 locations of 8 to 12 and 1 hub of 3. The content that does not exist yet is the
majority, and it will now be authored against two axes instead of one. The project already
carries four meter systems, and the tactical amendment §3 flagged that count as near a
complexity ceiling. A clock is a fifth axis of world state, even though it is not a meter.

**The resolution.** The boundary in §2 is what makes the trade acceptable. Tier 2 — pathing,
simulation, emergent routines — costs several times tier 1.5 and would not be finishable inside
Chapter One. Tier 1.5 is bounded by a table with a fixed row count and a fixed column count.

**If the owner rejects this amendment, nothing breaks.** FR-504 stands, M8 leaves the roadmap,
and the schedule shortens by 1.4 to 2.2 weeks. That is the whole cost of saying no.

---

## 4.5 Boundaries — what this amendment does not touch

- **FR-308 Zhavar telegraphing.** Rumors and the scripted tolling event stay flag-keyed. The
  clock does not gate them.
- **FR-402 band-gated reactions.** Faction bands stay the gate. Time is not a band.
- **FR-506 thinning gradient.** Encounter tables shift by geography, not by hour.
- **Combat.** The tactical layer has its own 16-tick measure for weather. The world clock and
  the combat measure are **separate systems and must not be unified.** One is authoring
  convenience across a whole hub; the other is a per-battle resolution axis. Merging them would
  make a battle's weather depend on when the player travelled, which no one asked for.
- **Companions (FR-505).** Companions follow the party. They get no routine.
- **The Soul Meter.** Canon makes recovery slow, partial and social. Whether the clock feeds
  recovery is an **open question**, not a decision this amendment makes. See §6.

---

## 5. Gate — how this is judged

This amendment adds no new blocking gate. It widens **FR-906**, which already requires a human
playtest pass against a world-state matrix.

**The matrix gains a time axis.** Each criterion below is binary and externally observable.

1. A schema 5 save loads and receives the default phase. Round-trip test, headless.
2. The clock survives save and load at every phase. Round-trip test, headless.
3. The clock advances only on the declared triggers. A player who stands still for 10 minutes
   sees no phase change. Headless.
4. Every routine NPC is findable in every phase, or is explicitly declared absent in that phase.
   No NPC is accidentally nowhere.
5. **No quest-critical interaction is reachable in fewer than two phases.** This is the FR-905
   rule from §3.4.
6. Dialogue that reads the phase produces the correct line in all four phases.
7. The routine count is **within 10 to 15**. A count above 15 fails the gate; it does not earn
   an exception.

**Needs outside humans: no.** Every criterion above is headless or a checklist. The subjective
question — does the hub feel alive — folds into the FR-906 pass that already exists. It does not
justify a second recruitment round, and Gate T's criterion 6 remains the project's only
outside-playtester requirement.

---

## 6. Still open — decisions this amendment does NOT make

1. **Does the world clock feed Soul Gauge recovery?** Canon makes recovery slow, partial and
   social. A clock makes "slow" expressible for the first time. This is a canon question. Do not
   resolve it in code.
2. **Does resting exist?** §3.1 lists it as an advance trigger, conditionally. If there is no
   rest mechanic, the trigger list is travel and quest steps only.
3. **Which 10 to 15 NPCs?** Hubs 2 and 3 do not exist yet, so the list cannot be filled. Fix the
   *count* now and the *names* during M7.
4. **Does the phase show in the HUD?** A clock the player cannot read is a clock that produces
   confusion instead of texture. FR-607's accessibility baseline applies to any indicator added.

---

## 7. Reversibility

The abort path, stated before the work starts.

- The routine table is **data**. Deleting the table returns every NPC to FR-504 behaviour.
- The clock accessor must have a **defined return value when the clock is disabled**, so
  dialogue written against it does not break on removal.
- The save migration is **one-way in practice**: schema 6 saves do not load in a schema 5 build.
  That is normal and is why the migration and its fixture are mandatory.

**Stop-loss.** Stop if authoring a single hub's routines exceeds the §3.3 estimate by more than
half, or if criterion 5 of §5 cannot be satisfied without redesigning a quest. Either signal
means the phase count or the NPC cap is wrong, and the correct response is to cut the count, not
to widen the schedule.

---

## 8. Ratification

This amendment is **NOT ratified**. It takes effect only when the owner signs the block below.

Work on GitHub issue **#104** must not start before that signature. Issue #104 is currently
written against the ratified FR-504 text and will need its scope updated to FR-504a.

```
RATIFIED BY: ______________________   DATE: ____________

DECISION (circle one):
  ACCEPT FR-504a as written
  ACCEPT with the changes noted below
  REJECT — FR-504 stands, M8 leaves the roadmap, schedule shortens by 1.4 to 2.2 weeks

NOTES:
```

---

## Appendix — provenance

- **Origin:** session decision D6, recorded in `.claude/session-intent.md` on 2026-08-07.
- **Trigger:** `docs/roadmap-chapter-one.md` M8 states that this amendment must exist before the
  work starts, and §6 lists FR-504 as an open divergence.
- **Precedent for the form:** `docs/prd-amendment-tactical-layer.md`, which retired two ratified
  P0 requirements in writing with reasons, boundaries, a gate and abort criteria recorded.
- **Measured inputs:** 11 NPC placements in `world/starting_town.tscn`; save schema 5 with
  migrations; no clock or time-of-day code exists anywhere in the repository (0 matches for
  `time_of_day`, `world_clock`, `day_night`).
