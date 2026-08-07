# The 3 × 10 Discipline × Patron Compatibility Sheet

**Status:** COMPLETE — run 2026-08-07. **Result: 0 hard failures, 1 blocking rule gap.**
**Discharges:** the ratified abort criterion for GitHub **#132**
(`docs/prd-amendment-tactical-layer.md` §9.1, and `systems/ten-patron-classes.md` in the vault).
**Language rule:** ASD-STE100. Game narrative content is excluded.

---

## 0. Why this sheet exists

The Combat Disciplines layer was adopted on 2026-08-05. Its ratified abort criterion says:

> Before authoring abilities, complete a 3 × 10 compatibility sheet. If any patron cannot use
> every discipline without a bespoke exception, or if a discipline displaces a patron's
> signature loop, stop and use direct mappings instead.

The vault states the same constraint and is honest that it was unproven:

> That claim has **not** been verified ... Until the sheet is run and read, this section asserts
> the requirement, **not** that the requirement is met.

This document runs it. **Reversal is cheap now and expensive later** — the vault records that
the dual layer becomes costly to unwind once companion dialogue, animations and save IDs encode
it.

### 0.1 The two tests, applied per cell

1. **Bespoke exception?** Does this pairing need a rule that exists only for this pairing?
2. **Displacement?** Does the Discipline overwrite or nullify the Patron's signature loop?

A cell fails only on 1 or 2. **A cell does not fail for being thematically odd.** The vault is
explicit that where a signature loop reads as assuming a footing, the Discipline "still supports
the Resource; it only colours the fiction of how the thing is done."

### 0.2 What the layers may touch

- A Discipline governs movement, reach, elevation and baseline tactical verbs.
- A Discipline **never** touches Gauge, fizzle, or a signature Resource.
- A Patron **never** sets movement cost or elevation.

That separation is what makes most cells pass by construction. The interesting cells are the
ones where a Resource *rides casting*, because one Discipline taxes casting.

---

## 1. Result

**30 cells. 0 hard failures. 21 clean passes. 9 passes with a recorded watch item.**

**The layering is NOT aborted.** The abort criterion is discharged, with one condition below.

### 1.1 ⚠ One blocking rule gap, and it decides 4 cells

**Does a Hushwarden's field tax the Hushwarden's own casting?**

The 2026-08-05 ruling says a Hushwarden field "does not forbid casting — it *taxes* it, raising
fizzle and Soul cost inside the field." It does not say **who** is inside the field.

This is not a small omission. Four Patron Resources ride casting frequency, and all four sit
inside their own Hushwarden field by definition:

| Cell | If the field is self-affecting |
|---|---|
| River-Mother × Hushwarden | The Name-Ledger is the game's **primary Gauge-recovery lever**. Taxing it is the most consequential single interaction on this sheet |
| Husk-bearer × Hushwarden | DoT application is throttled, so Hunger never stacks |
| Stormbearer × Hushwarden | Fewer casts means fewer high-roll triggers, and Attribution is already high variance |
| Flamebinder × Hushwarden | **Inverted** — see §1.2 |

**This is a one-line ruling, and it is the owner's to make.** §4 gives the options. Until it is
made, treat those four cells as provisional.

### 1.2 A second finding: one cell may be too strong, not too weak

**Flamebinder × Hushwarden farms its own resource.**

Instructive Failure banks a token **on a fizzle**. A Hushwarden field **raises fizzle**. A
Flamebinder standing in their own field therefore converts a penalty into currency, and the more
the Waning bites, the better the pairing gets.

That is not an incompatibility, so it does not fail either test. It is a balance watch item, and
it is the only cell on the sheet where the pairing is *stronger* than the sum of its parts by a
margin worth measuring.

---

## 2. The sheet

**Legend.** ✅ clean pass · ⚠ pass, watch item recorded · ❓ provisional, blocked on §1.1 ·
❌ fail

| Patron | Resource rides | Chordblade | Terrashaper | Hushwarden |
|---|---|---|---|---|
| **Mirrorblade** (Maiiam) | action alternation | ✅ | ⚠ W1 | ✅ |
| **River-Mother** (Haeren) | casting, allies | ✅ | ✅ | ❓ G1 |
| **Ironbrand** (Kero) | taking damage | ✅ | ✅ | ✅ |
| **Lensbearer** (Stuid) | a personal stat | ✅ | ✅ | ✅ |
| **Husk-bearer** (Vhorr) | casting, DoT uptime | ✅ | ✅ | ❓ G1 |
| **Flamebinder** (Vicoar) | casting, fizzles | ⚠ W2 | ✅ | ⚠ B1 |
| **Stormbearer** (Ofshütje) | casting, variance | ✅ | ⚠ W3 | ❓ G1 |
| **Oathclock** (Pazzah) | a queue | ✅ | ✅ | ⚠ W4 |
| **Locksmirk** (Fickah) | fizzle floor, traps | ✅ | ✅ | ⚠ W5 |
| **Threadwalker** (Izhakel) | contact binding | ✅ | ⚠ W6 | ⚠ W7 |

---

## 3. The cells that needed an argument

The 21 clean cells pass by the §0.2 separation and are not restated. These are the rest.

### 3.1 The three cells the vault named as likely trouble — all three survive

**Threadwalker × Chordblade — the concern is RETIRED, not merely passed.**

The vault feared that "bind Threads across the field" assumes a reach the Discipline does not
grant. **The 2026-08-05 ruling already dissolved this**: binding a Thread requires physical
contact, always, for every Discipline, and *The Unspoken Term* cashes in Threads already bound,
one at a time. Reach is therefore not Discipline-dependent, so no Discipline can grant or deny
it. This cell is a clean ✅ and the vault's note on it is now stale.

**Oathclock × Hushwarden — ⚠ W4, thematic not mechanical.**

Both are control identities, so the fear was overlap. But they occupy different *mechanisms*:
the Ledger is a **queue** that resolves on a fixed future turn regardless of what happens
between, and the Hushwarden field is a **tax** on casting inside an area. A queue and a tax
stack; they do not collide. Neither displaces the other, and neither needs a bespoke rule.

The real risk is that the pairing reads as one identity twice over, which is a **content**
problem for ability authoring, not a rules problem. Watch it in M6.

**Locksmirk × Hushwarden — ⚠ W5, and the compounding is the watch item.**

Fickah casters never reach 0% fizzle. A Hushwarden field raises fizzle. The two compound on the
same axis, which is the sharpest stacking on the sheet.

It still passes both tests: the floor is a Patron rule, the tax is a Discipline rule, and
neither rewrites the other. It is also **not** obviously bad — *Jam the Gears* is the party's
dedicated anti-caster tool, and the field taxes enemy casters too, so the pairing is coherent as
a caster-denial build. Measure the compounded fizzle before judging it.

### 3.2 The watch items the sheet found on its own

**W1 — Mirrorblade × Terrashaper.** Balance requires alternating paired opposites including
advance and withdraw. Terrashaper is deliberately weighted and slow. The Resource still
functions, because alternation is about *action pairing*, not about distance covered. The vault's
"colours the fiction" clause covers this exactly. Watch whether the withdraw half feels inert.

**W2 — Flamebinder × Chordblade.** Constructs are deployed and stationary; Chordblade wants to
move. A high-mobility Flamebinder can outrun their own kinetic sculptures. No rule breaks — the
constructs work where they were placed. This is a build-quality question, not a legality one.

**W3 — Stormbearer × Terrashaper.** Skirmisher role against a stance Discipline. This is the
sharpest **role** tension on the sheet and the weakest pairing in play terms. It is still legal:
Attribution's semi-random triggers do not depend on movement. Expect players to avoid it.

**W6 — Threadwalker × Terrashaper.** Contact binding needs the Threadwalker to reach targets,
and Terrashaper is the least mobile Discipline. Legal, and slower. The Contract mechanic itself
is untouched.

**W7 — Threadwalker × Hushwarden.** The same reach pressure as W6, plus stillness as an
identity. Legal for the same reason.

**B1 — Flamebinder × Hushwarden.** See §1.2. Flagged as a **balance** item, not a compatibility
one.

---

## 4. The ruling this sheet needs

**Does a Hushwarden field tax its own caster?** The owner decides. The options and their
consequences:

| Option | Consequence |
|---|---|
| **Self-exempt** — the field taxes everyone except the Hushwarden | G1 resolves to ✅ for all three cells. B1 disappears, because Flamebinder no longer farms its own field. Simplest, and it makes Hushwarden a clean team-support Discipline |
| **Fully symmetric** — the field taxes everyone inside it, including its owner | G1 resolves to ⚠ for all three. Thematically the strongest reading: silence is weight, and weight does not choose sides. B1 stays and needs a balance pass |
| **Ally-exempt** — the field taxes only enemies | Removes the tension entirely, and makes Hushwarden strictly better than the other two Disciplines for any casting party. Not recommended |

**Recommendation: fully symmetric.** It matches the ruling's own words — silence is weight, not
a wall — and a Discipline that costs its owner nothing is not a stance, it is a buff. The four
affected cells stay legal under it, and B1 becomes a number to tune rather than a rule to write.

**Whichever is chosen, it is a vault edit**, because it is a canon rule about what a Discipline
does. Rerun `build_index.py` and `validate.py`.

---

## 5. What this sheet does NOT prove

- It does not prove the pairings are **balanced**. It proves they are **legal**. B1 is the one
  place where the distinction is already visible.
- It does not cover **abilities that do not exist yet**. Every ability authored in M6 must be
  re-checked against §0.2: an ability that sets movement cost is a Patron reaching into a
  Discipline's field, and it fails on sight.
- It does not resolve the four **open design threads** at the end of the vault's class entry
  (Fickah's fizzle floor scope, Ofshütje's random-trigger floor, counterplay against Sequenced
  Verdict, Vhorr's Hunger decay). Two of those touch cells on this sheet, so answering them may
  reopen W5 and G1.

---

## 6. Recommendation

**Do not abort the layering.** Both abort conditions are unmet: no cell needs a bespoke
exception, and no Discipline displaces a Patron's signature loop.

Two follow-ups, in order:

1. **Make the §4 ruling and write it into the vault.** It gates four cells and it is one
   sentence.
2. **Retire the vault's stale note** naming Threadwalker × Chordblade as likely trouble. The
   2026-08-05 contact-binding ruling already resolved it, and the note now misdirects.

M6 companion and ability authoring is unblocked once step 1 lands.

---

## Appendix — method

Every cell was evaluated against the two tests in §0.2, using
`~/projects/dramgid-vault/systems/ten-patron-classes.md` as the source for all ten Kits,
Resources and Signatures, and for the three Disciplines and the two bounding rulings of
2026-08-05. No cell was judged on theme alone. Cells that pass by the layer separation in §0.2
are recorded as clean and are not argued individually.
