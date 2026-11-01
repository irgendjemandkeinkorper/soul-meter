# Session Intent — Roadmap revisit 2, vision aligned (2026-10-31)

## Job statement

As a senior game designer, revise `docs/roadmap-2026-10-30.md` (PR #528 @ `58f15e22`) a second time
so the plan serves the vision the owner stated in-session on 2026-10-31, with every new owner
statement recorded as a ruling (never resolved silently) and the packet kept ratifiable.

## Intent answers (carried from the 2026-10-30 contract, reconfirmed)

| Question | Answer |
|---|---|
| Goal | Review/improve existing (the roadmap) |
| Knowledge | Expert |
| Clarity | Clear requirements |
| Success | Clear understanding + Production-ready |
| Constraints | Solo-dev capacity + High stakes |

## Designer questions answered inline (2026-10-31, owner's words paraphrased)

| # | Question | Owner's answer |
|---|---|---|
| 1 | The beat to show a friend after the first hour | **C for sure** (same-map fight, alerted mobs streaming into the CT order), **or D** (a companion turning on you), **maybe combined** |
| 2 | Unavoidable-combat set-pieces | Default accepted: one per main-quest ruling (three), everything else bypassable by talk, stealth or Soul |
| 3 | Soul at zero | **C**: a permanent, playable Hollow state, with negatives strong enough that the player is "very incentivized to try and get UnHollowed" |
| 4 | Weekly owner capacity for prose review and rulings | **~20 hours/week** (lighter pass for barks assumed, not stated) |
| 5 | Polish bar | **Between C and A**: prose density first, readable and consistent presentation; not cinematic |
| later | Chapter 2 promise / Soul cost display / tester recruitment | Defaults assumed: saved end-states only; number in the option + line in the read-back; recruitment starts alongside Phase 1 |

## Success criteria

1. The three new owner statements (Hollow state, three unavoidable set-pieces, prose-first polish
   bar) are recorded as rulings with the owner's wording, in `docs/owner-decisions.md` §5
   (Answered) and, where they bind design, proposed as additions to `docs/game-identity.md`
   for the owner to ratify. Nothing is written into canon on the agent's authority.
2. The roadmap names one **vertical-slice beat** ("the fight where the company turns", or C
   alone if D cannot be grounded) and says which phase proves it, with the field-first order
   either kept and reconciled or re-sequenced with the reason stated.
3. Phase sizing uses 20 owner-hours/week: prose load becomes a calendar, not a bottleneck
   warning; Phase 6 is re-scoped to the prose-first bar.
4. The Hollow state has a design note inside ruling 3 (Soul returns only through Agreement):
   negatives, the un-hollowing route, and what the 0.5× recovery ceiling means under it — all
   PROVISIONAL, sourced from `cosmology/souls.md` and the ratified design, no invented canon.
5. The issue packet is updated (new or changed issues only), nothing filed without the owner.
6. Both debate gates run; the Deliver verdict is "ratifiable".

## Boundaries

- Do not reopen the ten ratified rulings; ruling 5 stays as R10 (`defer`). Gate T-6 and FR-904 untouched.
- Do not resolve owner-list items silently; record new owner statements with their date and wording.
- No GitHub filing/labelling/merging and no commits/pushes without the owner's go.
- Do not invent canon for Hollow, companion betrayal, or set-pieces: read `cosmology/souls.md`,
  `canon/`, and the companion data first; mark everything unsourced PROVISIONAL.

## Context

- Build facts (verified 2026-10-31): `GameState.is_hollowing()` is a boolean state with a
  `hollowing_state_changed` signal, and Soul at zero already produces a **husked** state in
  `globals/game_state.gd` (`is_husked()`, `HUSKED_RECOVERY_CEILING_FLAG`): the recovery ceiling
  becomes the pre-zero value × `HUSKED_CEILING_RATIO` (0.5×) and is permanent. The owner's answer C
  must be reconciled with this: "UnHollowed" means recovery up to the husked ceiling unless the
  owner rules the ceiling lifts. `cosmology/souls.md` (carryover text) says a soul *frays* with use,
  trauma and casting; **Soul at zero is already ratified** (`cosmology/souls.md` "Reaching zero — husking-while-alive", game ruling 2026-08-07; `globals/game_state.gd` M4.3): the run does not end, the character is husked, casting is refused, and recovery uses only the ordinary means (rest, meaning, love, ritual, being witnessed and remembered) under the permanent ceiling. The owner's answer C restates this ruling; the new content is the *strength of the negatives* and the legibility of the un-hollowing route, not the state itself; no companion
  betrayal or loyalty mechanic exists in `globals/` or `dialogue/` (only a desertion-charge quest
  line in `dialogue/dom_side_quests.dialogue:159`).
- The owner's 20 h/week is ~3× the 6 h the previous plan assumed.
