# Game identity addendum — 2026-10-31

**Status: PROPOSAL for owner ratification — not ratified.**

This proposal does not edit, supersede, or silently extend `docs/game-identity.md`. If the owner
ratifies it with the literal reply at the end, only the three design statements in §1 become
binding. The implementation notes and boundaries in §2 remain PROVISIONAL or governed by their
named open ruling.

## 1. Proposed design extensions

### 1.1 The chapter's first proven combat moment

> “C for sure or D or maybe those two are combined”

**Extends existing ruling 4, Combat is the tactical centerpiece.** The first combat moment the
chapter must prove after its field-first first hour is C: a same-map fight in which alerted mobs
stream into the CT order. A grounded companion reaction may share that beat. D, a companion
turning hostile, is not part of this proposal because no current companion has an owner-approved
cause to attack Vex.

This extension names the proof, not its final prose or party composition. The current Phase 3
party and reaction remain PROVISIONAL under R15. The proof exercises existing ruling 6's same-map
alert-and-admission model; it does not turn an ambient fight into a deployed set-piece.

### 1.2 Three unavoidable set-pieces, and no other mandatory combat

> “yeah that sounds good for now”

The reply was to the proposal: **three unavoidable combat set-pieces, one per main-quest ruling;
everything else is bypassable by talk, stealth, or paying Soul.**

**Extends existing rulings 5 and 6, Fallout 2 lineage and same-map combat.** Exactly three Chapter
1 combats may be unavoidable, each carrying the consequence of one main-quest ruling. Every
other authored combat must have a qualifying talk, Tread, or Soul-payment resolution. Physical
skirting and fleeing do not count as the stealth route: Tread needs an explicit pre-alert check,
a legible telegraph, and a quest-resolution result. This extension adds no separate Stealth stat.
The encounter mapping remains PROVISIONAL under R14.

### 1.3 Playable Hollow with forceful, legible reasons to recover

> “definitely C but the negatives should make them very incentivized to try and get UnHollowed”

**Extends existing ruling 2 (empty Soul is hollowing, not death; zero is a state with lost
dialogue options, companion reactions and NPC read-back, recoverable only at a price) and ruling 3
(Soul returns only through acts of Agreement).** A run remains playable
at Soul 0 for as long as the player chooses, but the active Hollow state must impose strong,
legible negatives and point to an Agreement-based route back above zero. “UnHollowed” means the
first positive Soul write has ended the active state; it does not erase the permanent scar.

This extension does not reopen the already-ratified rule that zero is not death, and it creates no
passive recovery. Rest and consumables do not restore Soul. The recovery route must be an act of
Agreement under ruling 3.

## 2. Boundaries not ratified by this proposal

- **Phase 3 proof candidate:** the ambient `dorthkor-vanguard` fight on Dorthkor Road is the
  proposed proof location. The PROVISIONAL R15 party is Vex, Serai-Lun, and Old Grumbrand:
  Sacred Clarity can reveal intent, and Serai-Lun can react to killing or mercy. She does not turn
  hostile.
- **Set-piece mapping (PROVISIONAL R14):** Broken Muster maps to Dorthkor Dead Muster
  (`dorthkor-muster`); Deep Trial maps to Empty Post (`jawbrace-empty-post`), both of which exist
  today as quest-required field encounters; The Unanswered Roar
  maps to **a Hollowmere set-piece tied to The Unanswered Roar (PROVISIONAL working name; bridge
  needs owner approval)**. “Hollowmere Drowned Watch” and `hollowmere-roar-consequence` are not
  established in the vault or the build. They are not canon, are not ratified here, and must not
  be used as if they were existing content.
- **Hollow state and scar:** `globals/game_state.gd` makes active Hollow exactly Soul 0 and clears
  it on the first positive write. The lasting consequence is the recovery ceiling, based on the
  Soul value immediately before the first zero rather than peak Soul. Its `0.5` ratio is
  **PROVISIONAL (R13)** and is not ratified here.
- **Hollow negatives:** no dialogue option is currently blocked by Hollow, so the lost options
  that ruling 2 already names are unimplemented. The proposed package implements that part of
  ruling 2 and adds recruit gating, loss of the favorable Sway bargaining benefit,
  refusal of elective solo travel without creating a soft-lock, a displayed ceiling, and a
  journal recovery lead. These implementations remain PROVISIONAL; the strength principle in
  §1.3 is the proposed identity rule.
- **Name-Ledger:** `globals/combat/class_resources/haeren_name_ledger.gd` is the River-Mother
  (Haeren) **class resource**. It records fallen or saved allies during combat and returns Breath;
  it is not a world ritual and cannot itself mint Agreement Soul. A repeatable route that does
  not require recruiting Wyneth therefore needs a **PROVISIONAL** NPC-side act—a River-Mother
  NPC recording the player's name—or another owner-approved Agreement act. No such mechanism
  is claimed as implemented or ratified here.
- **Companion hostility and connective canon:** Serai-Lun's killing/mercy reaction is not a
  hostile turn. Any future D beat needs an owner-approved cause. The Hollowmere set-piece bridge
  likewise needs owner approval before it becomes canon.

The underlying rulings remain in `docs/game-identity.md`; the Hollow implementation evidence is
in `globals/game_state.gd`.

**Vault source coverage — `../dramgid-vault/cosmology/souls.md`, “Reaching zero —
husking-while-alive”:** the ruling establishes continued life after husking, recovery that is
slow, social, and never complete, and naming or remembering the diminished as a genuine mercy.
That setting text also names rest among the ordinary means by which the Gauge can rebuild; this
proposal does not turn that lore into passive gameplay regeneration. Existing ruling 3 still
governs playable Soul gains: recovery must come through acts of Agreement.

## Owner ratification

To ratify only the three proposed design extensions in §1, reply exactly:

`Ratify docs/game-identity-addendum-2026-10-31.md §1 as proposed.`
