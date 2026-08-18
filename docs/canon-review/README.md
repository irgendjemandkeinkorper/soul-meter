# Companion quest canon-review cover

Status: **Pending human canon decision**

These packets isolate companion-quest canon questions from the resolver-contract work. They do
not authorize edits to dialogue, quest prose, save data, or the lore vault.

## Review set

- [Packet A: Wyneth and the Hospice Chain in Dom](packet-a-wyneth.md)
- [Packet B: Grumbrand and Pozor's reading institutions](packet-b-grumbrand.md)
- [Packet C: naming collisions](packet-c-naming-collisions.md)
- [Provisional trust-language redlines](trust-language-redlines.md)

## Decision item: Serai-Lun branch reward asymmetry

Status: **Pending human canon decision**

Evidence:

- `dialogue/companions/serai_lun.dialogue:14-16` awards `+6` Renown for saying the line
  matters without a witness.
- `dialogue/companions/serai_lun.dialogue:18-20` awards `+3` Renown for saying Serai-Lun's
  scrutiny keeps the player honest.
- The other ten companion outcomes, including both outcomes for each of the other five
  companions, award `+6`.

Recommendation: change the second Serai-Lun outcome from `+3` to `+6`, but only after owner
sign-off. Equal rewards keep role-play branches mechanically neutral, make all twelve outcomes
consistent, simplify expected reward communication, and avoid presenting the second response as
a hidden wrong answer.

Tradeoff: the change adds three Renown for players choosing that branch and removes a possible
intentional expression of Serai-Lun's judgment. If the lower reward is deliberate characterization
or balance, retain `+6/+3` and document that intent instead. No values are changed by this packet.

Reviewer: _Unassigned_

Review date: _YYYY-MM-DD_

Decision: _Pending_

## Recorded non-bleed evidence

At baseline commit `6cf72ae2232f95453b095826fcc028828ff5c0a3`, the disputed institutional
prose in the Wyneth and Grumbrand dialogues was byte-identical to `HEAD`. The exact selected-line
hashes and selection rules are recorded in packets A and B. This check deliberately excludes
resolver call lines so contract-only edits cannot be mistaken for canon-prose changes.

## Review boundary

Human approval is required before applying a ruling. The conservative fallbacks are safe editing
directions, not automatic decisions. Do not copy provisional prose into the vault without a
separate vault review.
