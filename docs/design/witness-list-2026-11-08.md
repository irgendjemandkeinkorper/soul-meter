# Witness list for the way back from Hollow (#601, SR1) — proposal

**Status:** PROPOSAL, 2026-11-08. The owner approves the list and the prose (#601). Nothing
here is canon until approved.

**Ruling.** SR1 (owner, 2026-11-08; `docs/owner-decisions.md` §5): *be witnessed*. One named NPC
per hub hears the player's account and remembers them. It repeats once per hub per WorldClock
day. Where a hub has a River-Mother who keeps a Name-Ledger, she is the canonical witness.

**Lore basis.** `../dramgid-vault/cosmology/souls.md`, "Reaching zero — husking-while-alive":
the Gauge rebuilds through "rest, meaning, love, ritual, and above all being witnessed and
remembered by others". Recovery "is done *to* the husked by people who refuse to stop treating
them as someone". The witness act follows that lore exactly. The player does not cast or buy
the act. Someone hears them and keeps their name.

## The finding that shapes the list

**No Chapter 1 hub has a River-Mother NPC.** River-Mother is a playable class
(`canon/dom/classes/river-mother.json`). The Circle of River-Mothers sits in Deivel Zeit
(`factions/circle-of-river-mothers.md`). None of the 72 named NPCs in Dom, Kesselford or
Ashlaren is one. So the "canonical witness" clause applies nowhere in Chapter 1. This proposal
does not invent a River-Mother. Each pick is an existing NPC whose authored role already keeps
names or listens.

The closest canon is the **Hospice Chain**, Haeren's order beside the River-Mothers ("the
Mothers keep the water, the Chain keeps the deathbed", `factions/hospice-chain.md`). The Vael
hold remembering to be "literal soul-maintenance, every family keeping its Name-Ledger".

## Proposed witnesses

| Hub | Witness (canon id) | Why this NPC | Fallback |
|---|---|---|---|
| Dom | **Irka Stonebreath** (`irka-stonebreath`), Hospice scar keeper, River Shrine Hospice, Hospice Chain | Her authored line is "Irka keeps the trial-broken names". She is Haeren's order and already keeps the names of the diminished. Closest to the River-Mother clause without inventing one | Toma Reedhand (`toma-reedhand`), the River Shrine's keeper |
| Kesselford | **Mender Ivo Threnlow** (`kesselford-mender-pair-elder`), Wayfare-Mender, Mender Stone | He "counts the notes that come back late" and sings in a pair "so someone is there to catch the note that does not come back". Listening for what is missing is his authored trait. The Menders govern the town | Dagny Kettlebrook (`kesselford-wayhouse-keeper`), the wayhouse keeper |
| Ashlaren | **Warden Tamsin Flatbell** (`ashlaren-bell-warden`), Bell warden, Weighing Square | She "writes down which days it sounds flat". She is the town's only authored record-keeper outside the Factors' ledgers, and she rings the shrine-bell | None good. The Factors keep accounts, not people. Name one if Tamsin reads wrong |

## What each witness needs (owner prose)

For each hub, so the act reads as SR1 intends:

1. **One offer line**, shown only while the player is actively Hollow, for example a dialogue
   option on the witness.
2. **One short scene**, 2–4 lines: the player gives an account and the witness repeats a
   detail back. The repetition is the remembering.
3. **One already-done line** for a second visit on the same WorldClock day.
4. **One journal lead** naming the nearest witness. #601 requires it, so the Hollow player is
   never left without a next step.

Irka's existing dialogue in `dialogue/dom_townsfolk.dialogue` is the call site for Dom. Ivo and
Tamsin have warm and hostile lines only, so their scenes are new dialogue.

## Mechanics this list does not decide

- The Soul amount for one witnessing is owner item 5. It is an Agreement-tagged positive write
  through the quest path, and it respects the ceiling.
- The once per hub per WorldClock day cadence is ruled (SR1). The implementation keys a flag on
  hub id plus day.
- The Name-Ledger class resource is unchanged. Recording a name returns Breath to its caster and
  mints no Soul (#601).

## Questions for the owner

1. Approve the three witnesses, or swap in a fallback.
2. Should a witness react when they already know the player, for example from a finished quest,
   or read the same for everyone?
3. Write the scene prose yourself, or have Claude draft it for your edit?
