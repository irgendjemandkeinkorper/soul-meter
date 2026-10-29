# Karma act table — draft for review (owner item 1, `karma acts: yes`)

**Status: review only. Nothing here is wired.** The owner ruled option B on 2026-10-22 (tier gates on
existing surfaces) and asked for this table. `Renown.gain_karma(actor, base, cause, scene)` exists and
applies `base × Doctrine / 10` (`Renown.ATTRIBUTE_SCALE_DIVISOR`), but **no game code calls it**: Karma
is a shipped ledger with no writers, so every Karma gate authored today is unreachable content. This
table proposes a base per act for every ledger write Chapter 1 already makes with a moral reading, so
the writers can be added in one pass after approval.

Sources: RFC-0007 §4 (`dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0007-yothmeru-reputation.md`,
whose OQ-0032 calls its own values placeholders), `docs/yothmeru-world-effects-packet.md` §4.4, and the
call sites listed per row. Tiers and floors are the shipped ones (`docs/dramgid-numbers.md` §9).

## 1. Scale

RFC-0007's sample rows run from −150 (murder an innocent) to +40 (save a stranger at personal risk). No
Chapter 1 choice is a murder or a betrayal; nearly every authored choice is between two defensible goods,
so the Chapter 1 table lives inside ±20:

| base | reading |
|---|---|
| 0 | a political or factional judgment with no moral asymmetry — Fame and Reputation already carry it |
| ±5 | a small tilt toward or away from a person's dignity, consent, or the truth |
| ±10 | a clear act for or against someone, usually with a cost already paid in another ledger |
| ±15 / ±20 | the rare act that is virtuous *and* unwitnessed (RFC-0007's "banking" note), or a cruelty with a victim |

At Doctrine 10 the table reads literally. A thorough virtuous run through everything below sums to
roughly +110 (Upright, floor 50); a mercenary run that takes every negative row sums to roughly −60
(Troubled, floor −50). Neither reaches Virtuous or Cruel, which matches the packet's reading that
Chapter 1 telegraphs the ladder and Chapter 2+ systematizes it. Doctrine moves those sums by ±10 % per
point, so a Doctrine-14 saint lands at ~+155 and a Doctrine-6 one at ~+65; both still Upright.

## 2. The acts

"Ledger today" is what the call site already writes. "Base" is the proposed Karma base. Every reading is
the drafter's; edit the number or the reading in place.

### Main quest rulings (`globals/quest_registry.gd`)

| act | ledger today | base | reading |
|---|---|---|---|
| Broken Muster: `demons-first` | companies +12, sentinels −2, renown 10 | 0 | strategy, not morality |
| Broken Muster: `dead-first` | sentinels +12, companies −2, renown 10 | 0 | strategy |
| Broken Muster: `hold-both` | +7 / +7, renown 14, needs a centered soul | +10 | refuses to call either line expendable, at a cost the Gauge already charged |
| Act I hook: `sound-the-shortfall` | kord-rite +12, trial-council −6, renown 12 | +10 | took the truth into the open at the Council's expense |
| Act I hook: `seal-the-measure` | trial-council +12, kord-rite −4, renown 4 | −5 | an honest count given privately, and the shrines left guessing |
| Act I hook: `carry-it-yourself` | nothing, by design | +15 | bears the shortfall alone and unwitnessed — RFC-0007's banking case; Karma is the only ledger that can see it |
| Field debt reward: `companies` / `seeders` / `registry` | faction ±, renown 6 | 0 | allegiance |
| Field debt reward: `balance` | +5 / +5 / +5, renown 6 | +5 | split the credit honestly |
| Deep Trial: `sentinel-descent` / `seal-the-ledge` | ±10 / ±2, renown 8 | 0 | doctrine against doctrine |
| Deep Trial: `witnessed-descent` | +6 / +6, renown 12 | +5 | neither line gets to call the other expendable |

### Side quests (`quests/*.tres`, `dialogue/iris_illepah.dialogue`)

| act | ledger today | base | reading |
|---|---|---|---|
| Loamroot `returned` | ssae +10, renown 5 | +5 | brought back what was taken |
| Loamroot `communion` | ssae +5, renown 8, soul −8 | +10 | paid of yourself to anchor another's grove |
| Loamroot `registry` | ssae −8, registry +8, infamy 4 | −10 | seized living specimens under a claim |
| Iris: threatened the grove with the writ | ssae −6, registry +4, infamy 5 | −10 | intimidation of a tender |
| Iris: opened a vein to the Loam | ssae +3, soul −6 | +5 | a cost taken without flinching, for nothing |
| Iris: spoke of the Bloom as unfinished | ssae +8 | 0 | opinion |
| Ash in the Rain `hospice-first` / `market-first` | hospice +6 / factors +6 | +5 / 0 | both feed people; one feeds the trial-broken first |
| The Cold Bowl `bring-them-home` / `release-the-roll` | companies +6 / hospice +5 | 0 / +5 | the second keeps a wounded veteran's consent |
| Dishonest Water `halt-the-water` / `keep-the-roar` | council +6 / concord +6 | +5 / 0 | safety ahead of an uninterrupted Roar |
| The Fifth Echo `damp-the-echo` / `keep-the-warning` | council +6 / kord-rite +5 | 0 / +5 | kept a true warning audible |
| The Last Safe Course `publish` / `guard` | menders +6 / sentinels +6 | +5 / 0 | made the safe course common knowledge |
| The Living Tag `quarantine-the-plate` / `restore-the-name` | sentinels +6 / council +5, soul −8 | 0 / +10 | cleared a living person from the casualty record, at a soul cost |
| Marching Knots `give-it-to-the-watch` / `hang-it-at-the-shrine` | sentinels +6 / menders +6 | 0 / +5 | public warning over sealed report |
| Rain in the Register `restore-the-entry` / `close-the-road-name` | rennen +6 / council +5 | +5 / 0 | restored a witness's entry |
| The Smoothed Weights `void-the-trials` / `repeat-with-ranks-held` | council +6 / council −4 | +10 / 0 | honesty at a cost to sitting ranks |
| The Unclaimed Bed `return-the-name` / `keep-the-confidence` | companies +5 / hospice +6 | 0 / +5 | protected a chosen silence |
| Companion quests (12 resolutions, `dialogue/companions/*.dialogue`) | renown 3–6 each | 0 | each sets a rule for the companion, not a deed by the player |
| Sella Varn, Toma Reedhand small courtesies | dom +3, renown +2 / renown +1 | 0 | manners |

### Field acts (`globals/battle.gd`, `actors/npc/npc.gd`, `actors/pickup/pickup.gd`, `ui/screens/loot_panel`)

| act | ledger today | base | reading |
|---|---|---|---|
| Won a fight | faction delta, renown +3 "Cleared X" | 0 | Fame is the witness; victory is not virtue |
| Fled / was defeated | nothing (D7) / faction delta | 0 | — |
| Caught with a hand in a pocket | infamy 4, faction −3 | −10 | theft with a victim who saw it |
| Took goods from a place (`THEFT_REPUTATION_DELTA` −5) | faction −5 | −5 per act, capped at −25 per scene | petty theft; the cap keeps a looting pass from outweighing a quest |

### RFC-0007 rows with no Chapter 1 writer

Betray an ally (−40), save a stranger at personal risk (+40), casual public cruelty (−20), murder an
innocent (−150), generous public act (+30), masterwork performance (0 / Fame +30), careless Discord in a
populated area (−10), bank Harmony (+25) / harvest Aftertones (−10). None of these has an authored act
in Chapter 1. They stay in the RFC as the scale's anchors; the first content that authors one takes the
RFC base unless this table says otherwise.

## 3. How it would be wired (after approval; Codex, one PR)

1. **Data, not code, where the act already lives in data.** `quests/*.tres` gain
   `outcome_karma_deltas: PackedFloat32Array` beside `outcome_reputation_deltas`; the rulings dictionaries
   (`BROKEN_MUSTER_RULINGS`, `ACT_ONE_HOOK_RULINGS`, `FIELD_DEBT_REWARDS`) gain a `"karma": base` key;
   `QuestRegistry` calls `Renown.gain_karma("player", base, cause, scene)` in the same place it records
   reputation, with the outcome's existing cause string. Dialogue-only acts (Iris, theft) call it inline.
2. **Zero stays silent.** A 0 base writes no event; the ledger stays append-only and small.
3. **Read-back.** `ui/screens/standing.gd` already shows the Karma tier; `Renown.why(&"karma")` gives the
   journal its "what kind" lines for free.
4. **Then the Karma gates become reachable.** Two or three Dom routes keyed `maximum_karma_tier: "Troubled"`
   ("I've heard what kind") and one `minimum_karma_tier: "Upright"`, in `dialogue/dom_fame_reactions.dialogue`
   beside the Fame routes shipped 2026-10-22. Not before: a gate nobody can reach is dead content
   (`test_no_band_gate_is_unreachable_content` is the precedent for refusing it).
5. **Save compatibility.** Karma events are ordinary `RenownEvent`s (`kind == &"karma"`); old saves load
   with an empty Karma log and the Uncertain tier. No schema bump.

## 4. What this draft does not decide

- The Doctrine divisor (10.0, `ATTRIBUTE_SCALE_DIVISOR`) and the decay rule — shipped, DRAMGID §6 freeze.
- Whether Fame should scale by Decorum (packet §4.1, owner item 20).
- Any base above ±20 — nothing in Chapter 1 earns one, and the RFC owns the anchors.

## 5. Answer format

```
karma acts: approved            (or: edit rows in place and say "karma acts: as edited")
karma theft cap: 25             (§2 field acts; or another number, or "none")
```
