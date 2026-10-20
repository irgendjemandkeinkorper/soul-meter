# Karma and Fame in the world — owner review packet

**Status:** owner ruling required. Answers RFC-0007 OQ-0033 ("should Fame convert into a
tangible in-fiction benefit?") and `docs/architecture-dramgid.md` §5.8 (Fame raw vs
Decorum-scaled). Author: Claude, 2026-10-19. **Nothing here changes play until ruled** — the
tier gates described in §4 exist in code but no reaction rule or dialogue line uses them.

Owner list entry: `docs/owner-decisions.md` item 1.

---

## 1. What shipped (measured 2026-10-19, `globals/renown.gd`)

| Piece | State |
|---|---|
| Fame | `reputation + infamy`, 0..1000, less Legendary decay. Tiers Unknown 0 / Whispered 50 / Known 200 / Renowned 450 / Legendary 750 (RFC-0007 §3). |
| Karma | signed −1000..1000, seven tiers Damned … Exalted, Uncertain at −50..50. `gain_karma` applies × Doctrine / 10 at write time. |
| Readers of the tier | **None in the world.** `fame_tier()` feeds one Steam achievement (Whispered). `karma_tier_offset()` feeds `SkillCheck.karma_bonus` for Sway (good Karma) and Bellow (bad Karma). The Standing screen shows the meters. Recruit gates read raw reputation/infamy, not tiers. |
| Writers of Karma | **None.** `gain_karma` has no call site in dialogue, quests, battle, or any scene. Every save is "Uncertain", so the Sway bonus is always 0 and Bellow is never checked anywhere in Chapter 1 content anyway. |

## 2. How far the meters move in Chapter 1 (measured)

- **Authored Fame:** dialogue and quest grants sum to about 78 reputation and 9 infamy; the
  three main-quest rulings add 4–14 each. A thorough playthrough lands near **110 → Whispered**.
- **Fights:** every won encounter group records **+3 reputation** (`globals/battle.gd`, both
  the set-piece and the ambient path) unless its defeated-flag already fired. Wild respawns have
  no defeated flag, so a fighter adds +3 per clear: **Known (200) after ~30 wild wins**,
  Renowned after ~115. Legendary is out of reach in Chapter 1.
- **Karma:** 0 for every player, see §1.

So: whatever Fame does in the world will be visible at **Whispered** for everyone and at
**Known** for players who fight a lot. Anything keyed on Renowned or above is Chapter 2+ content.

## 3. Options for Fame (OQ-0033)

### A. Narrative only (status quo)

Fame stays a number on the Standing screen and an achievement trigger. Cost 0. Risk: a shipped,
append-only ledger that changes nothing, which FR-403's consequence mandate argues against.

### B. Tier gates on surfaces that already exist, no new numbers — **recommended**

1. **NPC reactions** (`globals/npc_reactions.gd`) accept `minimum_fame_tier`, and
   `minimum_karma_tier` / `maximum_karma_tier`, beside the existing flag / band / hollowing /
   Zhavar gates. A Whispered player gets "I've heard of you" routes; a Known one gets
   approached. Karma gates give "I've heard what kind" routes once Karma has writers.
2. **Dialogue conditions** can gate an offer on `Renown.fame_tier_at_least("Known")` — a
   commission a stranger is not given.
3. **Prices: no.** Reputation bands already own prices and trade gates; a second discount axis
   muddles the ledgers.
4. **Encounters: later, optional.** Fame could shift human-faction encounter weights (companies
   recognise you). That is a number, so it waits for §5.8 and playtest data.

Cost: gates and tests, half a day (done, see §4). Authoring 3–5 Dom reactions and 1–2 offers,
half a day plus your prose review. Nothing new to tune.

### C. Full numeric effects

Discounts per Fame tier, encounter weights per tier, Karma-tier door and temple gates. Needs §5.8
ruled first and a tuning pass; about two days. Risk: Fame grows with fight count (§2), so a
discount becomes a grind reward.

## 4. Sub-rulings folded in

1. **§5.8 — Fame raw or Decorum-scaled?** Shipped = raw sum, which the recruit gates survive. The
   scaled `fame_shift` is recorded on every event but not summed. Recommend **raw until the §6
   playtest data exists**; switching later is a read change, not a migration.
2. **Floors.** Keep the RFC floors. Option B only keys on Whispered and Known, both reachable.
3. **The +3 per won group.** It is shipped behaviour and the main Fame source. Confirm it is
   intended (`3: keep`) or name a cap per day / per zone.
4. **Karma writers.** This is the larger gap. RFC-0007 §4 has a sample act table (its OQ-0032
   admits the values are placeholders). Recommend I draft a Karma act table from the existing
   quest outcomes and ledger causes (every `Reputation.record` / `Renown.gain_*` call with a
   moral reading), with a proposed base per act, for your review before anything is wired.

## 5. What is already built (unused until ruled)

- `Renown.fame_tier_at_least(tier)`, `Renown.karma_tier_at_least(tier)`,
  `Renown.karma_tier_at_most(tier)` — tier-name floors and ceilings on the RFC ladders.
- `NpcReactions` rule keys `minimum_fame_tier`, `minimum_karma_tier`, `maximum_karma_tier`,
  validated against the RFC names, matched like the band gate (a floor, not an exact tier).
- Tests: `test/unit/test_renown_yothmeru.gd`, `test/unit/test_npc_reactions.gd`.

## 6. Answer format

```
1: B                      (or A / C)
1 scaling: raw            (§4.1)
1 floors: keep            (§4.2)
1 fight fame: keep        (§4.3, or a cap)
karma acts: yes           (§4.4 — I draft the table)
```
